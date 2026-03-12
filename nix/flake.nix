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
      url = "github:outfoxxed/hy3";
      #refs/tags/hl0.52.0"; # where {version} is the hyprland release version
      # or "github:outfoxxed/hy3" to follow the development branch.
      # (you may encounter issues if you dont do the same for hyprland)
      inputs.hyprland.follows = "hyprland";
    };
    # use the github shorthand with the tag; this resolves Git refs more reliably
    hyprland.url = "github:hyprwm/Hyprland?submodules=1";
    # where 0.52.1 is the hyprland release version
    # or "github:hyprwm/Hyprland?submodules=1" to follow the development branch
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-guiutils.url = "github:hyprwm/hyprland-guiutils";
    hyprland-guiutils.inputs.nixpkgs.follows = "nixpkgs";
    hyprtoolkit.url = "github:hyprwm/hyprtoolkit/v0.5.3";
    hyprtoolkit.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.inputs.hyprland-guiutils.follows = "hyprland-guiutils";
    hyprland-guiutils.inputs.hyprtoolkit.follows = "hyprtoolkit";

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

  outputs = { self, nixpkgs, home-manager, hyprland, hy3, nixvim, ... }@inputs:
    let username = "fusion809";
    in {
      # expose the hy3 package from the hy3 input so it can be built directly
      packages.x86_64-linux.hy3 = hy3.packages.x86_64-linux.hy3;
      packages.x86_64-linux.hyprland-guiutils =
        inputs.hyprland-guiutils.packages.x86_64-linux.hyprland-guiutils;
      packages.x86_64-linux.hyprtoolkit =
        inputs.hyprtoolkit.packages.x86_64-linux.hyprtoolkit;

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
              inputs.hyprland.overlays.glaze
              inputs.hyprland.overlays.hyprland-packages
              inputs.hyprland-guiutils.overlays.hyprland-guiutils-with-deps
              (final: prev: {
                hyprland = prev.hyprland.override {
                  hyprland-guiutils = final.hyprland-guiutils;
                };
                hyprlandPlugins = prev.hyprlandPlugins // {
                  hy3 = hy3.packages.${prev.stdenv.hostPlatform.system}.hy3;
                };
              })
            ];
          }

        ];
      };
    };
}
