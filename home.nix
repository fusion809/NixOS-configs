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
  home.stateVersion = "24.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    #gnomeExtensions.show-desktop-button
    #gnomeExtensions.dash-to-dock
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
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
  home.sessionVariables = {
    EDITOR = "vim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "fusion809";
    userEmail = "brentonhorne77@gmail.com";
  };
  programs.bash = {
    enable = true;
    bashrcExtra = "
export PATH=$PATH:/run/current-system/sw/bin:/run/current-system/sw/sbin
function vbash {
  vim $HOME/.bashrc
}

function sbash {
  source $HOME/.bashrc
}

function vcf {
  sudo vim /etc/nixos/configuration.nix
}

function nixcg {
  sudo nix-collect-garbage -d
}

function nixcu {
  sudo nix-channel --update
}

function nixrsu {
  sudo nixos-rebuild switch --upgrade
}

function update {
  nixcu
  nixrsu
  nixcg
}

function rebuild {
  sudo nixos-rebuild switch
}

alias nixrb=rebuild
function clipf {
  xclip -sel clip < $1
}

if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function rainbowfastfetch {
  hyfetch -p rainbow -b fastfetch --args='--localip-show-ipv4 false'
}

export NIXPKGS_ALLOW_INSECURE=1

function sclipf {
  sudo xclip -sel clip < $1
}

function git-branch {
  if ! [[ -n \"$1\" ]]; then
    git rev-parse --abbrev-ref HEAD
  else
    git -C \"$1\" rev-parse --abbrev-ref HEAD
  fi
}

function push {
  git add --all
  git commit -m \"$@\"
  git push origin $(git-branch)
}

function cdnc {
  cd $HOME/NixOS-configs/$1
}

function vhom {
  vim $HOME/NixOS-configs/home.nix
}
  ";
  };
  programs.zsh = {
    enable = true;
    initExtra = "
source $HOME/NixOS-configs/hnixos.zsh-theme
source $HOME/.bashrc

function vzsh {
  vim $HOME/.zshrc
}

function szsh {
  source $HOME/.zshrc
}
   ";
 };
 dconf = {
   enable = true;
   settings = {
    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-uri = "file:///run/current-system/sw/share/backgrounds/Photo%20of%20Valley.jpg";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/Photo%20of%20Valley.jpg";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "WhiteSur-Dark-solid";
      icon-theme = "WhiteSur-dark";
      cursor-theme = "WhiteSur-cursors";
    };
    "org/gnome/desktop/wm" = {
      preferences = "close,maximize,minimize:menu";
    };
    "org/gnome/shell" = {
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "show-desktop-button@amivaleo"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "org.gnome.Terminal.desktop"
        "vim.desktop"
        "gvim.desktop"
        "org.gnome.Extensions.desktop"
      ];
    };
    "org/gnome/shell/extensions/user-theme" = {
      name = "WhiteSur-Dark-solid";
    };
    "org/gnome/shell/extensions/dash-to-dock" = {
        height-fraction = 1.00;
        show-apps-at-top = true;
        isolate-workspaces = true;
    };
    "org/gnome/shell/extensions/show-desktop-button" = {
      indicator-position = "LEFT";
    };
  };
};
  programs.gnome-shell.theme.name = "WhiteSur-Dark-solid";
  gtk = {
    enable = true;
    theme = {
      name = "WhiteSur-Dark-solid";
    };
    iconTheme = {
      name = "WhiteSur-dark";
    };
    cursorTheme = {
      name = "WhiteSur-cursors";
    };
  };
}
