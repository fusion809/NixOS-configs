{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  R,
  # Runtime libraries RStudio bundles itself but still needs patched on NixOS
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  udev,
  xorg,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "rstudio-binary";
  version = "2026.06.0+242";

  # Official installer-less tarball from Posit (Ubuntu 22/24 amd64)
  # SHA256 from https://dailies.rstudio.com/rstudio/latest/index.json (jammy-amd64-xcopy)
  src = fetchurl {
    url = "https://s3.amazonaws.com/rstudio-ide-build/electron/jammy/amd64/rstudio-2026.06.0-242-amd64-debian.tar.gz";
    sha256 = "sha256-Ejhn8nE1qZ5cNUlHMS4F5TrNc8T6QR+/sNkoZ0/bZ0U=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libXtst
    zlib
  ];

  # autoPatchelfHook will skip files it can't patch (chrome sandbox etc)
  autoPatchelfIgnoreMissingDeps = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/rstudio $out/bin $out/share/applications $out/share/icons

    cp -r ./* $out/opt/rstudio/

    # Make the RStudio binary aware of R
    makeWrapper $out/opt/rstudio/rstudio $out/bin/rstudio \
      --set RSTUDIO_WHICH_R "${R}/bin/R" \
      --prefix PATH : "${R}/bin" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    # Desktop entry
    if [ -f "./rstudio.desktop" ]; then
      install -Dm644 "./rstudio.desktop" $out/share/applications/rstudio.desktop
      sed -i "s|Exec=.*|Exec=$out/bin/rstudio %F|" $out/share/applications/rstudio.desktop
    else
      cat > $out/share/applications/rstudio.desktop <<EOF
[Desktop Entry]
Name=RStudio
Comment=RStudio integrated development environment
Exec=$out/bin/rstudio %F
Icon=rstudio
Terminal=false
Type=Application
Categories=Development;
MimeType=text/x-r-source;text/x-r;application/x-r-project;
EOF
    fi

    # Icons
    for size in 16 32 48 64 128 256 512; do
      icon="./resources/app/resources/icons/rstudio-$size.png"
      if [ -f "$icon" ]; then
        install -Dm644 "$icon" $out/share/icons/hicolor/''${size}x''${size}/apps/rstudio.png
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "RStudio IDE (pre-built binary from Posit)";
    homepage = "https://www.rstudio.com/";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "rstudio";
  };
}
