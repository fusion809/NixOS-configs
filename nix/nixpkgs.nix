{ config, inputs, username, ... }:

{
  config = {
    allowUnfree = true;
    permittedInsecurePackages =
      [ "openssl-1.1.1w" "qtwebengine-5.15.19" "pulsar-1.130.1" ];
    packageOverrides = pkgs: {
      unstable = import inputs.nixpkgs-unstable {
        config = config.nixpkgs.config;
        system = "x86_64-linux";
      };
      staging-next = import inputs.staging-next {
        config = config.nixpkgs.config;
        system = "x86_64-linux";
      };
      master = import inputs.nixpkgs-master {
        config = config.nixpkgs.config;
        system = "x86_64-linux";
      };
    };
  };
  overlays = import ./overlays.nix { inherit inputs username; };
}
