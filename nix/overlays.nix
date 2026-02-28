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

      system = pkgs.stdenv.hostPlatform.system;

    in with pkgs; {
      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      # Hyprland 0.54.0's hyprpm/CMakeLists.txt does find_package(glaze 7.0.0)
      # and falls back to FetchContent/git if not found, which breaks in the Nix
      # sandbox. Inject glaze 7.0.0 (from nixpkgs-master) so CMake finds it.
      hyprland = (inputs.hyprland.packages.${system}.hyprland).overrideAttrs
        (old: { buildInputs = old.buildInputs ++ [ pkgs.master.glaze ]; });

      # Patch hy3 to link against our glaze-fixed hyprland above rather than
      # the raw inputs.hyprland package (which still lacks glaze 7.0.0).
      # pkgs.hyprland resolves to the overrideAttrs'd version via the fixed point.
      # Must use super.hyprlandPlugins (not pkgs/self) to avoid infinite recursion.
      hyprlandPlugins = super.hyprlandPlugins // {
        hy3 = (inputs.hy3.packages.${system}.hy3).override {
          hyprland = pkgs.hyprland;
        };
      };

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
