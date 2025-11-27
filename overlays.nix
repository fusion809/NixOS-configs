inputs:
[
  (self: super:

    let
      pkgs = self;
      inherit (pkgs) lib;
      forkNixpkgsPath = ./nixpkgs;
      callPackage = lib.callPackageWith (pkgs
        // builtins.removeAttrs pkgs.xorg [
          "callPackage"
          "newScope"
          "overrideScope"
          "packages"
        ]);

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
        inherit pkgs;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      openra = openraPackages.engines.release;
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vim-latest = pkgs.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
    })
]
