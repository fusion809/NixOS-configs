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
      runescape = callPackage (forkNixpkgsPath + /runescape/package.nix) { };
      whitesur-icon-theme =
        callPackage (forkNixpkgsPath + /whitesur-icon-theme/package.nix) { };
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vscode-generic = builtins.fetchurl
        "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/applications/editors/vscode/generic.nix";

      antigravity-master = let
        base =
          "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/an/antigravity";
        pkg = builtins.fetchurl "${base}/package.nix";
        info = builtins.fetchurl "${base}/information.json";
        update = builtins.fetchurl "${base}/update.js";
      in callPackage (runCommand "antigravity-package.nix" { } ''
        cp ${pkg} $out
        substituteInPlace $out \
          --replace "./information.json" "${info}" \
          --replace "./update.js" "${update}"
      '') { };
    })
]
