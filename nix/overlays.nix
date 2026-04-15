{ inputs, username }:
[
  (self: super:

    let
      pkgs = self;
      inherit (pkgs) lib;
      forkNixpkgsPath = ../nixpkgs;
      callPackage = lib.callPackageWith (pkgs
        // builtins.removeAttrs pkgs.xorg [
          "callPackage"
          "newScope"
          "overrideScope"
          "packages"
        ]);

      myLib = import ./lib.nix { inherit username; };
      inherit (myLib) homeDir;

    in with pkgs; {
      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      hyprland = pkgs.master.hyprland;
      hyprlandPlugins = super.hyprlandPlugins // {
        hy3 = pkgs.master.hyprlandPlugins.hy3;
      };
      hyprsession = inputs.hyprsession.packages.${super.stdenv.hostPlatform.system}.default or null;

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
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
      linuxPackages_latest = super.linuxPackages_latest.extend (lfinal: lprev:
        let
          nvidiaRef =
            lfinal.callPackage (forkNixpkgsPath + /nvidia/default.nix) { };
        in {
          nvidia_x11 = nvidiaRef.stable_580;
          nvidiaPackages = lprev.nvidiaPackages // {
            stable = nvidiaRef.stable_580;
            production = nvidiaRef.stable_580;
          };
        });
      # Also patch the default linuxPackages
      linuxPackages = super.linuxPackages.extend (lfinal: lprev:
        let
          nvidiaRef =
            lfinal.callPackage (forkNixpkgsPath + /nvidia/default.nix) { };
        in {
          nvidia_x11 = nvidiaRef.stable_580;
          nvidiaPackages = lprev.nvidiaPackages // {
            stable = nvidiaRef.stable_580;
            production = nvidiaRef.stable_580;
          };
        });

    })
]
