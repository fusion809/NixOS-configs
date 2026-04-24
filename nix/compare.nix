{ mode, ... }@args:

let
  # Home-manager modules comparison
  # Home-manager modules comparison
  compareHome = { hmRev, hmPath ? null }:
    let
      hmSrc = if hmPath != null && hmPath != "" then
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
      masterSrc = if masterPath != null && masterPath != "" then
        builtins.toPath masterPath
      else
        builtins.fetchGit {
          url = "https://github.com/NixOS/nixpkgs.git";
          rev = masterRev;
        };
      masterPkgs = import masterSrc { config.allowUnfree = true; };

      # packageNames is passed as a space-separated string from the shell
      # builtins.split returns both matched strings and separators (empty lists)
      # so we need to filter for strings only
      namesList = builtins.filter (x: builtins.isString x && x != "")
        (builtins.split " " packageNames);

      # Get output paths for these packages
      outPaths = builtins.map (name: masterPkgs.${name}.outPath) namesList;
    in builtins.toJSON outPaths;

  # All packages comparison
  comparePackages = { stableRev, unstableRev, masterRev, oldstableRev, vimRev
    , username, stablePath ? null, unstablePath ? null, masterPath ? null
    , oldstablePath ? null, vimPath ? null, hyprsessionPath ? null }:
    let
      fetch = rev:
        builtins.fetchGit {
          url = "https://github.com/NixOS/nixpkgs.git";
          inherit rev;
        };

      stableSrc = if stablePath != null && stablePath != "" then
        builtins.toPath stablePath
      else
        fetch stableRev;
      unstableSrc = if unstablePath != null && unstablePath != "" then
        builtins.toPath unstablePath
      else
        fetch unstableRev;
      masterSrc = if masterPath != null && masterPath != "" then
        builtins.toPath masterPath
      else
        fetch masterRev;
      oldstableSrc = if oldstablePath != null && oldstablePath != "" then
        builtins.toPath oldstablePath
      else
        fetch oldstableRev;
      vimSrc = if vimPath != null && vimPath != "" then
        builtins.toPath vimPath
      else
        builtins.fetchGit {
          url = "https://github.com/vim/vim.git";
          rev = vimRev;
        };
      hyprsessionSrc = if hyprsessionPath != null && hyprsessionPath != "" && hyprsessionPath != "null" then
        builtins.toPath hyprsessionPath
      else
        null;

      # Mock inputs for overlays.nix
      inputs = {
        nixpkgs-unstable = unstableSrc;
        nixpkgs-master = masterSrc;
        nixpkgs-oldstable = oldstableSrc;
        vim-src = vimSrc;
        hyprsession = if hyprsessionSrc != null then
          if builtins.pathExists (hyprsessionSrc + "/flake.nix") then
            builtins.getFlake (toString hyprsessionSrc)
          else if builtins.pathExists (hyprsessionSrc + "/default.nix") then {
            packages.x86_64-linux.default = import hyprsessionSrc {
              pkgs = import stableSrc { system = "x86_64-linux"; };
            };
          } else
            null
        else
          null;
      };

      # Import overlays
      userOverlays = import ./overlays.nix { inherit inputs username; };

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
          oldstable = import oldstableSrc {
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
      # Filter out nulls to prevent crashes if some packages are conditionally null
      validPackages = builtins.filter (p: p != null) packageList;
    in builtins.toJSON (map (p: p.outPath) validPackages);

in if mode == "home" then
  compareHome (builtins.removeAttrs args [ "mode" ])
else if mode == "master" then
  compareMaster (builtins.removeAttrs args [ "mode" ])
else if mode == "packages" then
  comparePackages (builtins.removeAttrs args [ "mode" ])
else
  throw "Invalid mode: ${mode}. Must be 'home', 'master', or 'packages'."
