# flake.nix

{
  inputs = {
    home-manager = {
      url =
        "git+https://github.com/nix-community/home-manager.git?ref=release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixpkgs
    nixpkgs-oldstable.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.05";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.11";
    nixpkgs-unstable.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
    nixpkgs-master.url = "git+https://github.com/NixOS/nixpkgs.git?ref=master";
    nixpkgs-pr.url =
      "git+https://github.com/NixOS/nixpkgs.git?rev=4fdbc9eff3a9511a8795e13167425cc96f63a946";
    # Vim
    vim-src = {
      url = "git+https://github.com/vim/vim.git?allRefs=1";
      flake = false;
    };
    nixvim = {
      url = "git+https://github.com/nix-community/nixvim.git?ref=nixos-25.11";
      # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, ... }@inputs:
    let username = "fusion809";
    in {
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
