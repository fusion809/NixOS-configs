# flake.nix

{
  inputs = {
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixpkgs
    nixpkgs-oldstable.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.05";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05";
    nixpkgs-unstable.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
    nixpkgs-master.url = "git+https://github.com/NixOS/nixpkgs.git?ref=master";
    nixpkgs-pr.url = "git+https://github.com/NixOS/nixpkgs.git?rev=8a62462a67c9c30b311da868e0c66935a8a1ed09";
    # Vim
    vim-src = {
      url = "git+https://github.com/vim/vim.git?allRefs=1";
      flake = false;
    };
    nixvim = {
      url = "git+https://github.com/nix-community/nixvim.git?ref=nixos-26.05";
      # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
    };
    hy3 = {
      url = "github:outfoxxed/hy3?rev=a7282db2d7ca336d3c9faa5d10d75fc43eed37aa";
    };
    waybar = {
      url = "github:Alexays/Waybar?rev=90b209add8937514d0a987aa842e701bd8f1232e"; # 0.15.0 stable
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixvim,
      hy3,
      waybar,
      ...
    }@inputs:
    let
      username = "fusion809";
    in
    {
      # also set the defaultPackage for this system to hy3 for convenience
      defaultPackage.x86_64-linux =
        inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.hyprlandPlugins.hy3;

      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs username; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          nixvim.nixosModules.nixvim
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${username} = import ./home.nix;
              backupFileExtension = "backup";
              # Pass inputs to home-manager modules
              extraSpecialArgs = { inherit inputs username; };
            };
          }
        ];
      };
    };
}
