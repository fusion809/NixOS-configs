{ stableRev, unstableRev, masterRev }:

let
  fetch = rev:
    builtins.fetchGit {
      url = "https://github.com/NixOS/nixpkgs.git";
      inherit rev;
    };

  stableSrc = fetch stableRev;
  unstableSrc = fetch unstableRev;
  masterSrc = fetch masterRev;

  # Mock inputs for overlays.nix
  inputs = {
    nixpkgs-unstable = unstableSrc;
    nixpkgs-master = masterSrc;
    # vim-src is not critical for package list evaluation unless vim-latest is in the list
    # We can mock it or fetch it if needed. Let's mock it to save time/bandwidth if possible.
    vim-src = builtins.fetchGit {
      url = "https://github.com/vim/vim.git";
      allRefs = true;
    };
  };

  # Import overlays
  userOverlays = import ./overlays.nix inputs;

  # Config with packageOverrides
  config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      unstable = import unstableSrc {
        config = { allowUnfree = true; };
        system = "x86_64-linux";
      };
      master = import masterSrc {
        config = { allowUnfree = true; };
        system = "x86_64-linux";
      };
    };
  };

  # Instantiate pkgs
  pkgs = import stableSrc {
    inherit config;
    overlays = userOverlays;
    system = "x86_64-linux";
  };

  # Import packages.nix
  packageList = import ./packages.nix { inherit pkgs; };

in builtins.toJSON (map (p: p.outPath) packageList)
