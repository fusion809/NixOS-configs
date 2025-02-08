let
  pkgs = import <nixpkgs> {};
in {
  marvin = pkgs.callPackage ./package.nix { };
}
