let
  pkgs = import <nixpkgs> {};
  runescape = pkgs.callPackage ./package.nix { };
