# flake.nix

{
  inputs = {
    home-manager = {
      url =
        "git+https://github.com/nix-community/home-manager.git?ref=release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hyprland
    hy3 = {
      url = "git+https://github.com/outfoxxed/hy3?ref=refs/tags/hl0.53.0.1";
      #refs/tags/hl0.52.0"; # where {version} is the hyprland release version
      # or "github:outfoxxed/hy3" to follow the development branch.
      # (you may encounter issues if you dont do the same for hyprland)
      inputs.hyprland.follows = "hyprland";
    };
    # use the github shorthand with the tag; this resolves Git refs more reliably
    hyprland.url =
      "git+https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/v0.53.3";
    # where 0.52.1 is the hyprland release version
    # or "github:hyprwm/Hyprland?submodules=1" to follow the development branch
    hyprland.inputs.nixpkgs.follows = "nixpkgs";
    # nixpkgs
    nixpkgs-oldstable.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.05";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.11";
    nixpkgs-unstable.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
    nixpkgs-master.url = "git+https://github.com/NixOS/nixpkgs.git?ref=master";
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

  outputs = { self, nixpkgs, home-manager, hyprland, hy3, nixvim, ... }@inputs:
    let username = "fusion809";
    in {
      # expose the hy3 package from the hy3 input so it can be built directly
      packages.x86_64-linux.hy3 = hy3.packages.x86_64-linux.hy3;

      # also set the defaultPackage for this system to hy3 for convenience
      defaultPackage.x86_64-linux = hy3.packages.x86_64-linux.hy3;

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
          {
            nixpkgs.overlays = [
              (final: prev: {
                hyprlandPlugins = prev.hyprlandPlugins // {
                  hy3 = hy3.packages.x86_64-linux.hy3;
                };
              })
            ];
          }
        ];
      };
    };
}
