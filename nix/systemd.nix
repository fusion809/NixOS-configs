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
    path = [ pkgs.kdePackages.kdeconnect-kde pkgs.dbus ];
    serviceConfig = {
      ExecStart = "${
          pkgs.python3.withPackages (ps: with ps; [
            ps.pydbus
            ps.pygobject3
          ])
        }/bin/python3 -u /home/${username}/GitHub/mine/config/NixOS-configs/python/swaync-kdeconnect-bridge.py";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Rclone mounts
  user.services.rclone-dropbox = {
    description = "Rclone mount for Dropbox (Brenton Horne)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p /home/${username}/DDrive-BrentonHorne";
      ExecStart = "${pkgs.rclone}/bin/rclone mount dropbox-brentonhorne: /home/${username}/DDrive-BrentonHorne --vfs-cache-mode writes";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/${username}/DDrive-BrentonHorne";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-gdrive-brenton = {
    description = "Rclone mount for Google Drive (Brenton Horne)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p /home/${username}/GDrive-BrentonHorne";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive-brentonhorne: /home/${username}/GDrive-BrentonHorne --vfs-cache-mode writes";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/${username}/GDrive-BrentonHorne";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-gdrive-william = {
    description = "Rclone mount for Google Drive (William Sutter)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p /home/${username}/GDrive-WilliamSutter";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive-williamsutter: /home/${username}/GDrive-WilliamSutter --vfs-cache-mode writes";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/${username}/GDrive-WilliamSutter";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-onedrive-uni = {
    description = "Rclone mount for OneDrive (Uni)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p /home/${username}/OneDrive-Uni";
      ExecStart = "${pkgs.rclone}/bin/rclone mount onedrive-uni: /home/${username}/OneDrive-Uni --vfs-cache-mode writes";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/${username}/OneDrive-Uni";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  user.services.rclone-gdrive-rooslus = {
    description = "Rclone mount for Google Drive (Rooslus96)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p /home/${username}/GDrive-Rooslus96";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive-rooslus96: /home/${username}/GDrive-Rooslus96 --vfs-cache-mode writes";
      ExecStop = "/run/current-system/sw/bin/fusermount -u /home/${username}/GDrive-Rooslus96";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
