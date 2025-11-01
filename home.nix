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

  #wayland.windowManager.hyprland = {
  #  enable = true;
    # ...
  #  plugins = [
  #    inputs.hyprland-plugins.packages.${pkgs.system}.hyprbars
      # ...
  #  ];
  #};
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
    ".config/hypr/hyprland.conf" = {
      source = /home/fusion809/GitHub/mine/config/hyprland-configs/hyprland.conf;
    };
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
  programs = {
  	home-manager.enable = true;
  	bash = {
    		enable = true;
    		bashrcExtra = "
function vbash {
  vim $HOME/.bashrc
}

function sbash {
  source $HOME/.bashrc
}

function vcf {
  sudo vim /etc/nixos/configuration.nix
}

function vhc {
  vim $HOME/.config/hypr/hyprland.conf
}

function vwc {
  vim $HOME/.config/waybar/config.jsonc
}

if [[ -v $HYPRLAND_INSTANCE_SIGNATURE ]]; then
  if `bt-device -l | grep -i \"00:A4:1C:F5:00:63\"` &> /dev/null; then
    bluetoothctl scan on
    bluetoothctl pair 00:A4:1C:F5:00:63
    bluetoothctl connect 00:A4:1C:F5:00:63
  fi
fi
function nixcg {
  sudo nix-collect-garbage -d
}

function git-branch {
  if ! [[ -n \"$1\" ]]; then
    git rev-parse --abbrev-ref HEAD
  else
    git -C \"$1\" rev-parse --abbrev-ref HEAD
  fi
}

function nixver {
  sudo nix-channel --list | grep nixos | cut -d '-' -f 2
}

function umount_arch {
  if `mountpoint -q /arch/boot`; then
    sudo umount /arch/boot -l
    sudo umount /arch -l
  fi
}

function mount_arch {
  if ! `mountpoint -q /arch`; then
    sudo mount /dev/disk/by-label/arch /arch
    sudo mount /dev/disk/by-label/ARCHEFI /arch/boot
  fi
}
function nixrsu {
  #if [[ $(git-branch $HOME/NixOS-configs) != $(nixver) ]]; then
  #  cdnc
  #  git checkout $(nixver) || (printf 'git checkout has failed.' && return 1)
  #fi
  umount_arch
  sudo nixos-rebuild switch --upgrade
  mount_arch
}

function update {
  sudo nix-store --repair --verify --check-contents
  nixrsu
  nixcg
}

function rebuild {
  if [[ $(git-branch $HOME/NixOS-configs) != $(nixver) ]]; then
    cdnc
    git checkout $(nixver) || (printf 'git checkout has failed.' && return 1)
  fi
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

function nixstrep {
  sudo nix-store --repair --verify --check-contents
}

function push {
  git add --all
  git commit -m \"$@\"
  git push origin $(git-branch)
}

function pushf {
  git add --all
  git commit -m \"$@\"
  git push origin $(git-branch) -f
}

function gitsw {
  repo=$(git remote -v | grep fetch | grep origin | sed 's|.*github.com[/:]||g' | cut -d ' ' -f 1)
  git remote rm origin
  git remote add origin git@github.com:$repo
}

function cdnc {
  cd $HOME/NixOS-configs/$1
}

function vhom {
  vim $HOME/NixOS-configs/home.nix
}

alias vhx=vhom
function vrm {
  vim $HOME/NixOS-configs/README.md
}
mount_arch
  ";
  	};
  	git = {
	    	enable = true;
    		userName = "fusion809";
   	  	userEmail = "brentonhorne77@gmail.com";
  	};
	zsh = {
		enable = true;
                initExtra = "
sed -i '/^:/!d' $HOME/.zsh_history
source $HOME/NixOS-configs/hnixos.zsh-theme
function shopt {
  #echo \"shopt called with arguments: $@\"
}
source $HOME/.bashrc

function vzsh {
  vim $HOME/.zshrc
}

function szsh {
  source $HOME/.zshrc
}
#sudo virsh net-define $HOME/NixOS-configs/virbr0.xml
#sudo virsh net-start virbr0
#ip link add virbr0 type bridge
#ip address ad dev virbr0 10.25.0.1/24
#ip link set dev virbr0 up
function cdhc {
cd $HOME/GitHub/mine/config/hyprland-configs
}

function vhc {
vim $HOME/GitHub/mine/config/hyprland-configs/hyprland.conf
}

function vwc {
vim $HOME/.config/waybar/config.jsonc
}

function vst {
vim $HOME/GitHub/mine/config/hyprland-configs/style.css
}

function cdpi {
cd $HOME/Pictures
}

function cdap {
cd $HOME/.local/share/applications
}

function cdphd {
cd /arch$HOME/PhD/$1
}
";
};
 };
 dconf = {
   enable = false;
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
    "org/gnome/desktop/lockdown" = {
      disable-lock-screen = true;
    };
    "org/gnome/desktop/screensaver" = {
      lock-enabled = false;
    };
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
        height-fraction = 1.00;
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
    "org/gnome/desktop/session" = {
      idle-delay = 0;
    };
    "org/virt-manager/virt-manager/connections" = {
    autoconnect = ["qemu:///system"];
    uris = ["qemu:///system"];
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
