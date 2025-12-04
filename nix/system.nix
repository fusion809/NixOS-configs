{ username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;

in {
  activationScripts.rootBashrc = {
    text = ''
      mkdir -p /root
      {
        echo 'export USER="${username}"'
        echo 'export NIXCFG="${nixcfgDir}"'
        cat ${../shell/root/main.sh}
      } > /root/.bashrc
    '';
    deps = [ ];
  };

  # Preserve OpenRA git cache from garbage collection
  activationScripts.preserve-openra-git = {
    text = ''
      mkdir -p /nix/var/nix/gcroots/auto
      ln -sfn ${
        builtins.fetchGit {
          url = "file:///home/fusion809/GitHub/others/OpenRA";
          ref = "bleed";
        }
      } /nix/var/nix/gcroots/auto/openra-git-cache
    '';
    deps = [ ];
  };

  stateVersion = "25.05";
}
