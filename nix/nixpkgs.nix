{
  config,
  inputs,
  username,
  ...
}:

{
  config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    permittedInsecurePackages = [
      "openssl-1.1.1w"
      "qtwebengine-5.15.19"
      "electron-40.10.5"
      #"electron-37.10.3" "electron-38.8.4"
    ];
    packageOverrides = pkgs: {
      unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [
          (final: prev:
            let
              buildAwsLcFromSource = package: package.overrideAttrs (old: {
                preBuild = (old.preBuild or "") + ''
                  export AWS_LC_SYS_USE_SYSTEM=0
                '';
              });
            in
            {
              # aws-lc-sys's Nixpkgs crate override forces system AWS-LC for
              # Tectonic and Codex. Tectonic also sets OPENSSL_DIR, which makes
              # aws-lc-sys mistake OpenSSL for AWS-LC and reject its headers.
              # Nixpkgs' cargo post-patch hook resets this variable, so override
              # it in preBuild after that hook has run.
              tectonic-unwrapped = buildAwsLcFromSource prev.tectonic-unwrapped;
              codex = (buildAwsLcFromSource prev.codex).overrideAttrs (old: {
                # cargoUseSystemLibs makes several crates use system libraries.
                # Provide those libraries explicitly for pkg-config and linking.
                buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd prev.oniguruma prev.sqlite ];
              });
            })
        ];
      };
      master = import inputs.nixpkgs-master {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      pr = import inputs.nixpkgs-pr {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      oldstable = import inputs.nixpkgs-oldstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
  };
  overlays = import ./overlays.nix { inherit inputs username; };
}
