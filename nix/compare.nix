{ mode, ... }@args:

let
  # Home-manager modules comparison
  # Home-manager modules comparison
  compareHome = { hmRev, hmPath ? null }:
    let
      hmSrc = if hmPath != null then
        builtins.toPath hmPath
      else
        builtins.fetchGit {
          url = "https://github.com/nix-community/home-manager.git";
          rev = hmRev;
        };
      # Return the store path of the modules directory
    in hmSrc + "/modules";

  # Master packages comparison
  compareMaster = { masterRev, packageNames, masterPath ? null }:
    let
      masterSrc = if masterPath != null then
        builtins.toPath masterPath
      else
        builtins.fetchGit {
          url = "https://github.com/NixOS/nixpkgs.git";
          rev = masterRev;
        };
      masterPkgs = import masterSrc { config.allowUnfree = true; };

      # packageNames is passed as a space-separated string from the shell
      namesList =
        builtins.filter (x: x != "") (builtins.split " " packageNames);

      # Get output paths for these packages
      outPaths = builtins.map (name: masterPkgs.${name}.outPath) namesList;
    in builtins.toJSON outPaths;

  # All packages comparison
  comparePackages = { stableRev, unstableRev, masterRev, vimRev
    , stablePath ? null, unstablePath ? null, masterPath ? null, vimPath ? null
    }:
    let
      fetch = rev:
        builtins.fetchGit {
          url = "https://github.com/NixOS/nixpkgs.git";
          inherit rev;
        };

      stableSrc = if stablePath != null then
        builtins.toPath stablePath
      else
        fetch stableRev;
      unstableSrc = if unstablePath != null then
        builtins.toPath unstablePath
      else
        fetch unstableRev;
      masterSrc = if masterPath != null then
        builtins.toPath masterPath
      else
        fetch masterRev;
      vimSrc = if vimPath != null then
        builtins.toPath vimPath
      else
        builtins.fetchGit {
          url = "https://github.com/vim/vim.git";
          rev = vimRev;
        };

      # Mock inputs for overlays.nix
      inputs = {
        nixpkgs-unstable = unstableSrc;
        nixpkgs-master = masterSrc;
        vim-src = vimSrc;
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
    in builtins.toJSON (map (p: p.outPath) packageList);

in if mode == "home" then
  compareHome (builtins.removeAttrs args [ "mode" ])
else if mode == "master" then
  compareMaster (builtins.removeAttrs args [ "mode" ])
else if mode == "packages" then
  comparePackages (builtins.removeAttrs args [ "mode" ])
else
  throw "Invalid mode: ${mode}. Must be 'home', 'master', or 'packages'."
