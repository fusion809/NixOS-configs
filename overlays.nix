[ (self: super:

let
  pkgs = self;
  inherit (pkgs) lib callPackage;
  forkNixpkgsPath = ./nixpkgs;

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

  openraPackages = import (forkNixpkgsPath + /openra/default.nix) pkgs; # Import as a set
  openra-git = openraPackages.engines.git; # Access the git engine directly
  runescape = callPackage (forkNixpkgsPath + /runescape/package.nix) {}; 
}) ]
