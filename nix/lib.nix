{ username }: rec {
  homeDir = "/home/${username}";
  nixcfgDir = "${homeDir}/GitHub/mine/config/NixOS-configs";
}
