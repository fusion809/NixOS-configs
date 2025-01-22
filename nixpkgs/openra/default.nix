{ pkgs }:

let
#  pkgs = import <nixpkgs> {};
  buildOpenRAEngine = pkgs.callPackage ./build-engine.nix { };
  callPackage' = path: pkgs.callPackage path { inherit buildOpenRAEngine; };
};
in
{
  engines = {
    release = callPackage' ./engines/release;
    playtest = callPackage' ./engines/playtest;
    git = callPackage' ./engines/git;
  };
}
