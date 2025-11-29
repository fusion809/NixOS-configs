{ ... }: {
  enable = false;
  settings = {
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-uri =
        "file:///run/current-system/sw/share/backgrounds/Photo%20of%20Valley.jpg";
      picture-uri-dark =
        "file:///run/current-system/sw/share/backgrounds/Photo%20of%20Valley.jpg";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "WhiteSur-Dark-solid";
      icon-theme = "WhiteSur-dark";
      cursor-theme = "WhiteSur-cursors";
    };
    "org/gnome/desktop/lockdown" = { disable-lock-screen = true; };
    "org/gnome/desktop/screensaver" = { lock-enabled = false; };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "close,maximize,minimize:menu";
    };
    "org/gnome/shell" = {
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "show-desktop-button@amivaleo"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "gsconnect@andyholmes.github.io"
      ];
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "com.brave.Browser"
        "org.gnome.Terminal.desktop"
        "vim.desktop"
        "org.gnome.Extensions.desktop"
        "steam.desktop"
      ];
    };
    "org/gnome/shell/extensions/user-theme" = { name = "WhiteSur-Dark-solid"; };
    "org/gnome/shell/extensions/dash-to-dock" = {
      height-fraction = 1.0;
      show-apps-at-top = true;
      custom-theme-shrink = true;
      isolate-workspaces = true;
      apply-custom-theme = true;
    };
    "org/gnome/shell/extensions/show-desktop-button" = {
      indicator-position = "LEFT";
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gnome/desktop/session" = { idle-delay = 0; };
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

  };
}
