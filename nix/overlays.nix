{ inputs, username }:
[
  (
    self: super:

    let
      pkgs = self;
      inherit (pkgs) lib;
      forkNixpkgsPath = ../nixpkgs;
      callPackage = lib.callPackageWith (
        pkgs
        // builtins.removeAttrs pkgs.xorg [
          "callPackage"
          "newScope"
          "overrideScope"
          "packages"
        ]
      );

      myLib = import ./lib.nix { inherit username; };
      inherit (myLib) homeDir;

    in
    with pkgs;
    {
      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };
      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
      hyprland = pkgs.pr.hyprland;
      hyprlandPlugins = super.hyprlandPlugins // {
        hy3 = pkgs.hyprlandPlugins.mkHyprlandPlugin {
          pluginName = "hy3";
          version = "0.55.1";
          src = inputs.hy3;
          nativeBuildInputs = [ pkgs.cmake ];
          dontStrip = true;
          cmakeFlags = [ "-DHY3_NO_VERSION_CHECK=ON" ];
          postPatch = ''
            sed -i 's/target hyprland version mismatch/ANTIGRAVITY CANARY/g' src/main.cpp
          '';
          meta = {
            homepage = "https://github.com/outfoxxed/hy3";
            description = "Hyprland plugin for an i3 / sway like manual tiling layout";
            license = pkgs.lib.licenses.gpl3;
          };
        };
      };
      rstudio-binary = callPackage ../nixpkgs/rstudio-binary { };

      # antigravity = callPackage (forkNixpkgsPath + /antigravity/package.nix) {
      #   buildVscode = { customizeFHSEnv ? null, ... }@args:
      #     let
      #       generic = pkgs.path + /pkgs/applications/editors/vscode/generic.nix;
      #       buildFHSEnv = if customizeFHSEnv != null then
      #         (fhsArgs: pkgs.buildFHSEnv (customizeFHSEnv fhsArgs))
      #       else
      #         pkgs.buildFHSEnv;
      #     in pkgs.callPackage generic
      #     (builtins.removeAttrs args [ "customizeFHSEnv" ] // {
      #       inherit buildFHSEnv;
      #     });
      # };
      linuxPackages_latest = super.linuxPackages_latest.extend (
        lfinal: lprev:
        let
          nvidiaRef = lfinal.callPackage (forkNixpkgsPath + /nvidia/default.nix) { };
        in
        {
          nvidia_x11 = nvidiaRef.stable_580 // {
            mod = nvidiaRef.stable_580.bin;
          };
          nvidiaPackages = lprev.nvidiaPackages // {
            stable = nvidiaRef.stable_580 // {
              mod = nvidiaRef.stable_580.bin;
            };
            production = nvidiaRef.stable_580 // {
              mod = nvidiaRef.stable_580.bin;
            };
          };
        }
      );
      # Also patch the default linuxPackages
      linuxPackages = super.linuxPackages.extend (
        lfinal: lprev:
        let
          nvidiaRef = lfinal.callPackage (forkNixpkgsPath + /nvidia/default.nix) { };
        in
        {
          nvidia_x11 = nvidiaRef.stable_580 // {
            mod = nvidiaRef.stable_580.bin;
          };
          nvidiaPackages = lprev.nvidiaPackages // {
            stable = nvidiaRef.stable_580 // {
              mod = nvidiaRef.stable_580.bin;
            };
            production = nvidiaRef.stable_580 // {
              mod = nvidiaRef.stable_580.bin;
            };
          };
        }
      );

    }
  )
]
