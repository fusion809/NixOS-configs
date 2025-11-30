{ username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;
in

{
    activationScripts.rootBashrc = {
    text = ''
      mkdir -p /root
      {
        echo 'export USER="${username}"'
        echo 'export NIXCFG="${nixcfgDir}"'
        cat ${../shell/root/main.sh}
      } > /root/.bashrc
    '';
    deps = [];
  };
  stateVersion = "25.05";
}