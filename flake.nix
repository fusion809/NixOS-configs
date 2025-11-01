{
  description = "NixOS configuration with distrohoop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    distrohoop = {
      url = "github:br0sinski/distrohoop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, distrohoop }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (final: prev: {
                distrohoop = distrohoop.packages.${system}.default;
              })
            ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.fusion809 = { ... }: {
                home.stateVersion = "25.05";
                home.packages = [ pkgs.distrohoop ];
              };
            };
          }
        ];
      };
    };
}