{ pkgs }:

let
  openRaUpdater = pkgs.callPackage ./updater.nix { };
  buildOpenRAEngine = pkgs.callPackage ./build-engine.nix { inherit openRaUpdater; };
  callPackage' = path: pkgs.callPackage path { inherit buildOpenRAEngine; };
in
{
  engines = {
    release = callPackage' ./engines/release;
    git = callPackage' ./engines/git;
  };
}
