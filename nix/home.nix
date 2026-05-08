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
  home.stateVersion = "25.05"; # Please read the comment before changing

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
    XDG_MENU_PREFIX = "plasma-";
  };

  # Let Home Manager install and manage itself.
  programs = import ./home-programs.nix { inherit pkgs username; };
  # This part is probably largely redundant, due to GNOME not being used, 
  # but may affect theming in GTK+ apps. 
  dconf = import ./home-dconf.nix { };
  gtk = import ./home-gtk.nix { };
}
