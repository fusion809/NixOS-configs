{
  description = "NixOS configuration with distrohoop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    distrohoop.url = "github:br0sinski/distrohoop";
  };

  outputs = { self, nixpkgs, distrohoop }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [
            (final: prev: {
              distrohoop = distrohoop.packages.${prev.system}.default;
            })
          ];
        }
      ];
    };
  };
}