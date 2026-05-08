{ config, pkgs, username, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
    vlc
    desktop-file-utils
    kdePackages.kservice
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = import ./home-file.nix { inherit pkgs config username; };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/fusion809/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "vim";
    USER = username;
    NIXCFG = "/home/${username}/GitHub/mine/config/NixOS-configs";
    NIXOS_OZONE_WL = "1";
    # Ensure KDE apps like Dolphin find their associations and themes on Hyprland
    QT_QPA_PLATFORMTHEME = "kde";
    XDG_CURRENT_DESKTOP = "KDE";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "okularApplication_pdf.desktop" ];
      "application/vnd.apple.mpegurl" = [ "codium.desktop" ];
      "audio/mpeg" = [ "vlc.desktop" ];
      "audio/x-wav" = [ "vlc.desktop" ];
      "video/mp4" = [ "vlc.desktop" ];
      "video/quicktime" = [ "vlc.desktop" ];
      "video/x-matroska" = [ "vlc.desktop" ];
      "image/jpeg" = [ "org.gnome.eog.desktop" ];
      "image/png" = [ "org.gnome.eog.desktop" ];
      "image/svg+xml" = [ "org.inkscape.Inkscape.desktop" ];
      "text/html" = [ "google-chrome.desktop" ];
      "text/markdown" = [ "codium.desktop" ];
      "text/plain" = [ "codium.desktop" ];
      "text/x-tex" = [ "texstudio.desktop" ];
      "x-scheme-handler/about" = [ "google-chrome.desktop" ];
      "x-scheme-handler/http" = [ "google-chrome.desktop" ];
      "x-scheme-handler/https" = [ "google-chrome.desktop" ];
      "x-scheme-handler/kdeconnect" = [ "org.kde.dolphin.desktop" ];
      "x-scheme-handler/unknown" = [ "google-chrome.desktop" ];
    };
    associations = {
      added = {
        "image/jpeg" = [ "org.gnome.eog.desktop" "eog.desktop" ];
        "image/png" = [ "gimp.desktop" "org.gnome.eog.desktop" ];
        "text/html" = [ "google-chrome-stable-2.desktop" "google-chrome-stable.desktop" ];
      };
    };
  };

  # Let Home Manager install and manage itself.
  programs = import ./home-programs.nix { inherit pkgs username; };
  # This part is probably largely redundant, due to GNOME not being used, 
  # but may affect theming in GTK+ apps. 
  dconf = import ./home-dconf.nix { };
  gtk = import ./home-gtk.nix { };
}
