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

      # Use OpenRA bleed engine from nixpkgs-master, override source to track latest
      openra-git = pkgs.master.openraPackages.engines.bleed.overrideAttrs
        (oldAttrs: {
          src = inputs.openra-src;
          version = "${toString (inputs.openra-src.revCount or 0)}.git.${
              inputs.openra-src.shortRev or "dirty"
            }";
        });
      openra = pkgs.master.openra;
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
    })
]
