{ pkgs, homeDir }:

let
  openRaUpdater = pkgs.callPackage ./updater.nix { };
  buildOpenRAEngine =
    pkgs.callPackage ./build-engine.nix { inherit openRaUpdater; };
  callPackage' = path:
    pkgs.callPackage path { inherit buildOpenRAEngine homeDir; };
in { engines = { git = callPackage' ./engines/git; }; }
