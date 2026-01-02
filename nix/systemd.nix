{ pkgs, ... }:

{
  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  services = {
    "getty@tty1".enable = false;
    "autovt@tty1".enable = false;
    dev-tpmrm0.enable = false;
  };
  tpm2.enable = false;
  coredump.enable = false;
  user.services.swaync = {
    description = "Sway notification centre";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
