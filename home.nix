{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "fusion809";
  home.homeDirectory = "/home/fusion809";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs;
    [
      #gnomeExtensions.show-desktop-button
      #gnomeExtensions.dash-to-dock
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".local/share/hyprland/plugins/hy3.so".source =
      "${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so";
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    #  ".config/hypr/hyprland.conf" = {
    #    source = /home/fusion809/GitHub/mine/config/hyprland-configs/hyprland.conf;
    #  };
  };

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
  home.sessionVariables = { EDITOR = "vim"; };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
    bash = {
      enable = true;
      bashrcExtra = ''
        source $HOME/GitHub/mine/config/NixOS-configs/Shell/main.sh
      '';
    };
    git = {
      enable = true;
      userName = "fusion809";
      userEmail = "brentonhorne77@gmail.com";
    };
    #vim = {
    #        enable = true;
    #        plugins = with pkgs.vimPlugins; [
    #          vim-wayland-clipboard
    #        ];
    #}; # Doesn't do anything
    zsh = {
      enable = true;
      initContent = ''
        export PATH=$PATH:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.git}/bin:${pkgs.gnugrep}/bin:${pkgs.wget}/bin:/run/wrappers/bin
        autoload -U colors && colors
        export HISTSIZE=10000000
        export SAVEHIST=10000000
        ${pkgs.coreutils}/bin/cp $HOME/.zsh_history $HOME/.zsh_history.back$(${pkgs.coreutils}/bin/date +"%Y-%m-%d_%H-%M-%S")
        ${pkgs.gnused}/bin/sed -i '/^:/!d' $HOME/.zsh_history
        function shopt {
          #echo "shopt called with arguments: $@"
        }
        source $HOME/GitHub/mine/config/NixOS-configs/Shell/main.sh
        source $NIXCFG/hnixos.zsh-theme
      '';
    };
  };
  dconf = {
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
          "gvim.desktop"
          "org.gnome.Extensions.desktop"
          "steam.desktop"
        ];
      };
      "org/gnome/shell/extensions/user-theme" = {
        name = "WhiteSur-Dark-solid";
      };
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
  };
  programs.gnome-shell.theme.name = "WhiteSur-Dark-solid";
  gtk = {
    enable = true;
    theme = { name = "WhiteSur-Dark-solid"; };
    iconTheme = { name = "WhiteSur-dark"; };
    cursorTheme = { name = "WhiteSur-cursors"; };
  };
}
