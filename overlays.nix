[ (self: super:

let
  pkgs = self;
  inherit (pkgs) lib;
  forkNixpkgsPath = /home/fusion809/NixOS-configs/nixpkgs;
  callPackage = lib.callPackageWith (pkgs // builtins.removeAttrs pkgs.xorg [ "callPackage" "newScope" "overrideScope" "packages" ]);

in with pkgs; {
  fork = import forkNixpkgsPath {
    config = {
      allowUnfree = true;
    };
    permittedInsecurePackages = [
      "dotnet-sdk-6.0.428"
    ];
    overlays = [ ];
  };

  openraPackages = import (forkNixpkgsPath + /openra/default.nix); # Import as a set
  openra-git = openraPackages.engines.git; # Access the git engine directly
  runescape = callPackage (forkNixpkgsPath + /runescape/package.nix) {}; 
}) ]
