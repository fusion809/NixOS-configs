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
    wantedBy = [ "default.target" ];
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
    wantedBy = [ "default.target" ];
    after = [ "swaync.service" "kdeconnect.service" ];
    path = [ pkgs.kdePackages.kdeconnect-kde pkgs.dbus ];
    serviceConfig = {
      ExecStart = "${
          pkgs.python3.withPackages (ps: with ps; [ ps.pydbus ps.pygobject3 ])
        }/bin/python3 -u /home/${username}/GitHub/mine/config/NixOS-configs/python/swaync-kdeconnect-bridge.py";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Rclone mounts
  tmpfiles.rules = [
    "d /DDrive-BH 0755 ${username} users"
    "d /GDrive-BH 0755 ${username} users"
    "d /GDrive-BH777 0755 ${username} users"
    "d /GDrive-WS 0755 ${username} users"
    "d /OneDrive-Uni 0755 ${username} users"
    "d /GDrive-RL 0755 ${username} users"
    "d /GDrive-FH 0755 ${username} users"
    "d /GDrive-FH21 0755 ${username} users"
  ];

  user.services.rclone-dropbox = {
    description = "Rclone mount for Dropbox (Brenton Horne)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount dropbox-brentonhorne: /DDrive-BH --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /DDrive-BH";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-gdrive-brenton = {
    description = "Rclone mount for Google Drive (Brenton Horne)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-brentonhorne: /GDrive-BH --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-BH";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  user.services.rclone-gdrive-brenton777 = {
    description = "Rclone mount for Google Drive (Brenton Horne 777)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-brentonhorne777: /GDrive-BH777 --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-BH777";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-gdrive-william = {
    description = "Rclone mount for Google Drive (William Sutter)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-williamsutter: /GDrive-WS --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-WS";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  user.services.rclone-onedrive-uni = {
    description = "Rclone mount for OneDrive (Uni)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount onedrive-uni: /OneDrive-Uni --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /OneDrive-Uni";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  user.services.rclone-gdrive-rooslus = {
    description = "Rclone mount for Google Drive (Rooslus96)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-rooslus96: /GDrive-RL --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-RL";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  user.services.rclone-gdrive-felicityhorne = {
    description = "Rclone mount for Google Drive (Felicity Horne)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-felicityhorne: /GDrive-FH --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-FH";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  user.services.rclone-gdrive-felicityhorne21 = {
    description = "Rclone mount for Google Drive (Felicity Horne 21)";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    path = [ "/run/wrappers" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive-felicityhorne21: /GDrive-FH21 --vfs-cache-mode writes --allow-other";
      ExecStop = "/run/wrappers/bin/fusermount -u /GDrive-FH21";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
