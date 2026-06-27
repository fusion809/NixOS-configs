{
  config,
  inputs,
  username,
  ...
}:

{
  config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    permittedInsecurePackages = [
      "openssl-1.1.1w"
      "qtwebengine-5.15.19"
      #"electron-37.10.3" "electron-38.8.4"
    ];
    packageOverrides = pkgs: {
      unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      master = import inputs.nixpkgs-master {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      pr = import inputs.nixpkgs-pr {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      oldstable = import inputs.nixpkgs-oldstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
  };
  overlays = import ./overlays.nix { inherit inputs username; };
}
