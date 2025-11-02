{ lib, buildDotnetModule, dotnetCorePackages
, fetchFromGitHub
, SDL2, freetype, openal, lua51Packages
}:
engine:

buildDotnetModule rec {
  pname = "openra-${engine.build}";
  inherit (engine) version;

  src = if engine ? src then engine.src else fetchFromGitHub {
    owner = "OpenRA";
    repo = "OpenRA";
    rev = if engine.build != "git" then "${engine.build}-${engine.version}" else "${engine.version}";

    sha256 = engine.sha256;
  };
  nugetDeps = engine.deps;

  # Newer OpenRA commits target .NET 8 — use the matching SDK/runtime so
  # NuGet can find Microsoft.NETCore.App.* / Microsoft.AspNetCore.App.* 8.x packages.
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  useAppHost = false;

  dotnetFlags = [ "-p:Version=0.0.0.0" ]; # otherwise dotnet build complains, version is saved in VERSION file anyway

  dotnetBuildFlags = [ "-p:TargetPlaform=unix-generic" ];
  dotnetInstallFlags = [
    "-p:TargetPlaform=unix-generic"
    "-p:CopyGenericLauncher=True"
    "-p:CopyCncDll=True"
    "-p:CopyD2kDll=True"
    "-p:UseAppHost=False"
  ];

  dontDotnetFixup = true;

  # Microsoft.NET.Publish.targets(248,5): error MSB3021: Unable to copy file "[...]/Newtonsoft.Json.dll" to "[...]/Newtonsoft.Json.dll". Access to the path '[...]Newtonsoft.Json.dll' is denied. [/build/source/OpenRA.Mods.Cnc/OpenRA.Mods.Cnc.csproj]
  enableParallelBuilding = false;

  # Override configureNuget to use a local fallback folder and avoid symlink races
  configureNuget = ''
    runHook preConfigureNuget
    
    # Use build-local directories for both the package cache and fallback folder
    export NUGET_PACKAGES="$PWD/.nuget/packages"
    export DOTNET_NUGET_FALLBACK_FOLDER="$PWD/.nuget/fallback"
    
    mkdir -p "$NUGET_PACKAGES" "$DOTNET_NUGET_FALLBACK_FOLDER"
    
    # Generate the NuGet.Config with our custom folders
    cat <<EOF > "$TMPDIR/NuGet.Config"
    <?xml version="1.0" encoding="utf-8"?>
    <configuration>
      <config>
        <add key="globalPackagesFolder" value="$NUGET_PACKAGES" />
        <add key="fallbackPackagesFolder" value="$DOTNET_NUGET_FALLBACK_FOLDER" />
      </config>
      <packageSources>
        <clear />
        <add key="_nix" value="$NUGET_PACKAGES" />
      </packageSources>
      <fallbackPackageFolders>
        <clear />
        <add key="dotnet-fallback" value="$DOTNET_NUGET_FALLBACK_FOLDER" />
      </fallbackPackageFolders>
      <packageSourceMapping>
        <packageSource key="_nix">
          <package pattern="*" />
        </packageSource>
      </packageSourceMapping>
    </configuration>
    EOF
    
    # Copy packages to our local package directory
    echo "Copying packages to $NUGET_PACKAGES..."
    for dep in $nugetDeps; do
      pkgdir="$(dirname $dep)"
      pkg="$(basename $dep)"
      for f in "$pkgdir/source/$pkg"/*; do
        pkgid="$(basename "$f" .nupkg)"
        pkgpath="$(echo "$pkgid" | tr '[:upper:]' '[:lower:]')"
        if [ ! -e "$NUGET_PACKAGES/$pkgid" ]; then
          echo "Installing package: $pkgid"
          mkdir -p "$NUGET_PACKAGES/$pkgid"
          unzip -o -d "$NUGET_PACKAGES/$pkgid" "$f"
          # Create a lowercase symlink for compatibility
          if [ "$pkgid" != "$pkgpath" ]; then
            ln -sf "$NUGET_PACKAGES/$pkgid" "$NUGET_PACKAGES/$pkgpath"
          fi
        fi
      done
    done
    
    # Debug: List all extracted packages
    echo "Available packages in $NUGET_PACKAGES:"
    ls -la "$NUGET_PACKAGES"
    
    runHook postConfigureNuget
  '';

  preBuild = ''
    make VERSION=${engine.build}-${version} version
  '';

  postInstall = ''
    # Create the file so that the install_data script will not attempt to download it.
    # TODO: fetch the file and include it
    touch './IP2LOCATION-LITE-DB1.IPV6.BIN.ZIP'

    # Install all the asset data
    (
      . ./packaging/functions.sh
      install_data . "$out/lib/${pname}" cnc d2k ra
    )

    # Replace precompiled libraries with links to native one.
    # This is similar to configure-system-libraries.sh in the source repository
    ln -s -f ${lua51Packages.lua}/lib/liblua.so $out/lib/${pname}/lua51.so
    ln -s -f ${SDL2}/lib/libSDL2.so             $out/lib/${pname}/SDL2.so
    ln -s -f ${openal}/lib/libopenal.so         $out/lib/${pname}/soft_oal.so
    ln -s -f ${freetype}/lib/libfreetype.so     $out/lib/${pname}/freetype6.so
  '';

  postFixup = ''
    (
      . ./packaging/functions.sh
      install_linux_shortcuts . "" "$out/lib/${pname}" "$out/.bin-unwrapped" "$out/share" "${version}" cnc d2k ra
    )

    # Create Nix wrappers to the application scripts which setup the needed environment
    for bin in $(find $out/.bin-unwrapped -type f); do
      makeWrapper "$bin" "$out/bin/$(basename "$bin")" \
        --prefix "PATH" : "${lib.makeBinPath [ dotnet-runtime ]}"
    done
  '';

  meta = with lib; {
    description = "Open Source real-time strategy game engine for early Westwood games such as Command & Conquer: Red Alert. ${engine.build} version";
    homepage = "https://www.openra.net/";
    license = licenses.gpl3;
    maintainers = with maintainers; [ mdarocha ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "openra-ra";
  };
}
