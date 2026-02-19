{ config, inputs, username, ... }:

{
  config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    permittedInsecurePackages = [ "openssl-1.1.1w" "qtwebengine-5.15.19" ];
    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [ "antigravity" ];
    packageOverrides = pkgs: {
      unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
      master = inputs.nixpkgs-master.legacyPackages.x86_64-linux;
      pr = inputs.nixpkgs-pr.legacyPackages.x86_64-linux;
      oldstable = inputs.nixpkgs-oldstable.legacyPackages.x86_64-linux;
    };
  };
  overlays = import ./overlays.nix { inherit inputs username; };
}
