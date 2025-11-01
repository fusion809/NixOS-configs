{
  description = "NixOS configuration with distrohoop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
          {
            nixpkgs.overlays = [
              (final: prev: {
                distrohoop = distrohoop.packages.${system}.default;
              })
            ];
          }
        ];
      };
    };
}