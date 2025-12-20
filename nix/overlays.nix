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

      pkgsOld = import inputs.nixpkgs-oldstable {
        system = pkgs.system;
        config.allowUnfree = true;
      };

    in with pkgs; {
      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
      antigravity = pkgsOld.callPackage
        (inputs.antigravity-pr + /pkgs/by-name/an/antigravity/package.nix) {
          vscode-generic = pkgsOld.path
            + /pkgs/applications/editors/vscode/generic.nix;
        };
    })
]
