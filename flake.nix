# flake.nix

{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.05";
    nixpkgs-unstable.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
    nixpkgs-master.url = "git+https://github.com/NixOS/nixpkgs.git?ref=master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    staging-next.url =
      "git+https://github.com/NixOS/nixpkgs.git?ref=staging-next";

    vim-src = {
      url = "git+https://github.com/vim/vim.git?allRefs=1";
      flake = false;
    };

    # use the github shorthand with the tag; this resolves Git refs more reliably
    hyprland.url = "github:hyprwm/Hyprland/v0.52.1?submodules=1";
    # where 0.52.1 is the hyprland release version
    # or "github:hyprwm/Hyprland?submodules=1" to follow the development branch

    hy3 = {
      url =
        "github:outfoxxed/hy3/hl0.52.0"; # where {version} is the hyprland release version
      # or "github:outfoxxed/hy3" to follow the development branch.
      # (you may encounter issues if you dont do the same for hyprland)
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, nixpkgs, home-manager, hyprland, hy3, ... }@inputs: {
    # expose the hy3 package from the hy3 input so it can be built directly
    packages.x86_64-linux.hy3 = hy3.packages.x86_64-linux.hy3;

    # also set the defaultPackage for this system to hy3 for convenience
    defaultPackage.x86_64-linux = hy3.packages.x86_64-linux.hy3;

    nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.fusion809 = import ./home.nix;

          # Pass inputs to home-manager modules
          home-manager.extraSpecialArgs = { inherit inputs; };
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
