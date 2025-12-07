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
      #fork = import forkNixpkgsPath {
      #  config = {
      #    allowUnfree = true;
      #  };
      #  permittedInsecurePackages = [
      #    "dotnet-sdk-6.0.428"
      #    "dotnet-runtime-6.0.428"
      #  ];
      #  overlays = [ ];
      #};

      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
    })
]
