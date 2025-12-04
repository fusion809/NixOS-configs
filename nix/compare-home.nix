{ hmRev }:

let
  hmSrc = builtins.fetchGit {
    url = "https://github.com/nix-community/home-manager.git";
    rev = hmRev;
  };
  # Return the store path of the modules directory
  # This will change if any module changes
in hmSrc + "/modules"
