{ masterRev, packageNames }:

let
  masterPkgs = import (builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    rev = masterRev;
  }) { config.allowUnfree = true; };

  # packageNames is passed as a space-separated string from the shell
  # Convert to list
  namesList = builtins.filter (x: x != "") (builtins.split " " packageNames);

  # Get output paths for these packages
  outPaths = builtins.map (name: masterPkgs.${name}.outPath) namesList;

in builtins.toJSON outPaths
