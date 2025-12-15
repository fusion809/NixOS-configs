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

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });

      pulsar = super.pulsar.overrideAttrs (oldAttrs: rec {
        version = "1.130.1";
        src = fetchurl {
          url =
            "https://github.com/pulsar-edit/pulsar/releases/download/v${version}/Linux.pulsar-${version}.tar.gz";
          hash = "sha256-1qdbcxayna1kiwxz68kwir0c7pmypr5q49cjf9yf4m43c66arkgy";
        };
        meta = oldAttrs.meta // { knownVulnerabilities = [ ]; };
        postFixup = lib.replaceStrings [
          "unlink $dugite/git/libexec/git-core/git-lfs"
          "unlink $asarBundle/node_modules/document-register-element/dre"
          "rm $opt/resources/app.asar.unpacked/node_modules/tree-sitter-bash/build/node_gyp_bins/python3"
        ] [
          "rm -f $dugite/git/libexec/git-core/git-lfs"
          "rm -f $asarBundle/node_modules/document-register-element/dre"
          "rm -f $opt/resources/app.asar.unpacked/node_modules/tree-sitter-bash/build/node_gyp_bins/python3"
        ] oldAttrs.postFixup;
      });
    })
]
