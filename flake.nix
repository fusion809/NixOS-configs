# flake.nix

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  # use the github shorthand with the tag; this resolves Git refs more reliably
  hyprland.url = "github:hyprwm/Hyprland/v0.52.1?submodules=1";
    # where 0.52.1 is the hyprland release version
    # or "github:hyprwm/Hyprland?submodules=1" to follow the development branch

    hy3 = {
      url = "github:outfoxxed/hy3"; # where {version} is the hyprland release version
      # or "github:outfoxxed/hy3" to follow the development branch.
      # (you may encounter issues if you dont do the same for hyprland)
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { nixpkgs, home-manager, hyprland, hy3, ... }: {
    # expose the hy3 package from the hy3 input so it can be built directly
    packages.x86_64-linux.hy3 = hy3.packages.x86_64-linux.hy3;

    # also set the defaultPackage for this system to hy3 for convenience
    defaultPackage.x86_64-linux = hy3.packages.x86_64-linux.hy3;

    homeConfigurations."fusion809@nixos" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        hyprland.homeManagerModules.default

        {
          wayland.windowManager.hyprland = {
            enable = true;
            plugins = [ hy3.packages.x86_64-linux.hy3 ];
          };
        }
      ];
    };
  };
}

