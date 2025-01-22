[ (self: super:

let
  pkgs = self;
  inherit (pkgs) lib;
  forkNixpkgsPath = /home/fusion809/nixpkgs;

in with pkgs; {
  fork = import forkNixpkgsPath {
    config = {
      allowUnfree = true;
    };
    overlays = [ ];
  };

  openraPackages = import (forkNixpkgsPath + /openra/default.nix); # Import as a set
  openra-git = openraPackages.engines.git; # Access the git engine directly

}) ]
