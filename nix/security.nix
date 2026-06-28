{ pkgs, ... }:

{
  rtkit.enable = true;
  sudo.wheelNeedsPassword = false;
  
  wrappers.Hyprland = pkgs.lib.mkForce {
    owner = "root";
    group = "root";
    source = "${pkgs.hyprland}/bin/Hyprland";
  };
}
