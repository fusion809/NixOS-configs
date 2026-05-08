{ pkgs, username, ... }:

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
  user.services.languagetool = {
    description = "LanguageTool HTTP Server";
    wantedBy = [ "default.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.languagetool}/bin/languagetool-http-server --port 8081 --allow-origin '*'";
      Restart = "always";
      RestartSec = 3;
    };
  };
  user.services.swaync-kdeconnect-bridge = {
    description = "Bridge SwayNC and KDE Connect for notification dismissal";
    wantedBy = [ "graphical-session.target" ];
    after = [ "swaync.service" "kdeconnect.service" ];
    path = [ pkgs.kdePackages.kdeconnect-kde ];
    serviceConfig = {
      ExecStart = "${
          pkgs.python3.withPackages (ps: with ps; [
            ps.pydbus
            ps.pygobject3
          ])
        }/bin/python3 -u /home/${username}/GitHub/mine/config/NixOS-configs/shell/user/swaync-kdeconnect-bridge.py";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
