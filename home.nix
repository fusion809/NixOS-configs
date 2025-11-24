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
      bashrcExtra =
        "\nfunction vbash {\n  vim $HOME/.bashrc\n}\n\nfunction sbash {\n  source $HOME/.bashrc\n}\n\nfunction vcf {\n  sudo vim /etc/nixos/configuration.nix\n}\n\nfunction vhc {\n  vim $HOME/.config/hypr/hyprland.conf\n}\n\nfunction vwc {\n  vim $HOME/.config/waybar/config.jsonc\n}\n\nif [[ -v $HYPRLAND_INSTANCE_SIGNATURE ]]; then\n  if `bt-device -l | grep -i \"00:A4:1C:F5:00:63\"` &> /dev/null; then\n    bluetoothctl scan on\n    bluetoothctl pair 00:A4:1C:F5:00:63\n    bluetoothctl connect 00:A4:1C:F5:00:63\n  fi\nfi\nfunction nixcg {\n  sudo nix-collect-garbage -d\n}\n\nfunction git-branch {\n  if ! [[ -n \"$1\" ]]; then\n    git rev-parse --abbrev-ref HEAD\n  else\n    git -C \"$1\" rev-parse --abbrev-ref HEAD\n  fi\n}\n\nfunction nixver {\n  sudo nix-channel --list | grep nixos | cut -d '-' -f 2\n}\n\nfunction umount_arch {\n  if `mountpoint -q /arch/boot`; then\n    sudo umount /arch/boot -l\n    sudo umount /arch -l\n    touch ~/.cache/umount_arch\n  fi\n}\n\nfunction mount_arch {\n  if ! `mountpoint -q /arch` && ! [[ -f $HOME/.cache/umount_arch ]]; then\n    sudo mount /dev/disk/by-label/arch /arch\n    sudo mount /dev/disk/by-label/ARCHEFI /arch/boot\n  elif [[ -f $HOME/.cache/umount_arch ]]; then\n    echo '$HOME/.cache/umount_arch exists, so a Nix rebuild is likely happening...'\n  fi\n}\n\nfunction rebuild {\n  umount_arch\n  sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix\n  rm -f $HOME/.cache/umount_arch\n  mount_arch\n}\n\nalias nixrb=rebuild\nfunction nixrsu {\n  sudo nix-channel --update\n  nixrb\n}\n\nfunction nixfrb {\n  sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix --flake .#nixos --impure\n}\n\nfunction update {\n  sudo nix-store --repair --verify --check-contents\n  nixrsu\n  nixcg\n}\n\nfunction clipf {\n  if `ps ax | grep wayland &> /dev/null`; then\n    wl-copy < $1\n	else\n  	xclip -sel clip < $1\n  fi\n}\n\nif ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then\n  mkdir -p $HOME/.ssh\n  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'\n  clipf $HOME/.ssh/id_rsa.pub\n  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'\nfi\n\nfunction rainbowfastfetch {\n  hyfetch -p rainbow -b fastfetch --args='--localip-show-ipv4 false'\n}\n\nexport NIXPKGS_ALLOW_INSECURE=1\n\nfunction sclipf {\n  sudo xclip -sel clip < $1\n}\n\nfunction nixstrep {\n  sudo nix-store --repair --verify --check-contents\n}\n\nfunction push {\n  git add --all\n  git commit -m \"$@\"\n  git push origin $(git-branch)\n}\n\nfunction pushf {\n  git add --all\n  git commit -m \"$@\"\n  git push origin $(git-branch) -f\n}\n\nfunction gitsw {\n  repo=$(git remote -v | grep fetch | grep origin | sed 's|.*github.com[/:]||g' | cut -d ' ' -f 1)\n  git remote rm origin\n  git remote add origin git@github.com:$repo\n}\n\nfunction cdnc {\n  cd $HOME/GitHub/mine/config/NixOS-configs/$1\n}\n\nfunction vhom {\n  vim $HOME/GitHub/mine/config/NixOS-configs/home.nix\n}\n\nalias vhx=vhom\nfunction vrm {\n  if [[ -f README.md ]]; then\n    vim README.md\n  else\n    vim $HOME/GitHub/mine/config/NixOS-configs/README.md\n  fi\n}\nmount_arch\n\nfunction vsnc {\n  code $HOME/GitHub/mine/config/NixOS-configs\n}\n\nfunction vshc {\n  code $HOME/GitHub/mine/config/hyprland-configs\n}\n\nfunction comno {\n	git rev-list --count HEAD\n}\n\nfunction revision {\n	git log | head -n 1 | cut -d ' ' -f 2\n}\npushd -q $HOME/GitHub/others/OpenRA\ngit pull origin bleed -q\nlatestRev=$(revision)\npopd -q\npackagedRev=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '\"' -f 2)\nif [[ $latestRev != $packagedRev ]]; then\n  echo \"OpenRA git package is out of date. openraup will update it.\"\nfi\n\nfunction openraup {\n  pushd -q $HOME/GitHub/others/OpenRA\n  git pull origin bleed -q\n  latestRev=$(revision)\n  upno=$(comno)\n  uphash=$(revision | head -c 7)\n  popd -q\n  packagedRev=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '\"' -f 2)\n  sed -i -e \"s|$packagedRev|$latestRev|g\" $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix\n  latestHash=$(nix-prefetch-git --url https://github.com/OpenRA/OpenRA --rev $latestRev 2>&1 | grep '\"hash\"' | cut -d '\"' -f 4)\n  packagedHash=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'hash' | cut -d '\"' -f 2)\n  packagedVer=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'version' | cut -d '\"' -f 2)\n  latestVer=\"$upno.git.$uphash\"\n  sed -i -e \"s|$packagedHash|$latestHash|g\" -e \"s|$packagedVer|$latestVer|g\" $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix\n  \n  nixrb\n}\n  ";
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

        export HISTSIZE=10000000
        export SAVEHIST=10000000
        sed -i '/^:/!d' $HOME/.zsh_history
        source $HOME/GitHub/mine/config/NixOS-configs/hnixos.zsh-theme
        function shopt {
          #echo "shopt called with arguments: $@"
        }
        source $HOME/.bashrc

        function vzsh {
          vim $HOME/.zshrc
        }

        function szsh {
          source $HOME/.zshrc
        }

        function cdgm {
          cd $HOME/GitHub/mine/$1
        }
        function cdhc {
          cdgm config/hyprland-configs
        }

        function cdim {
          cd /arch$HOME/GitHub/mine/websites/images
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

        function cdvi {
          cd /arch$HOME/'VirtualBox VMs'/iso
        }

        function cdvm {
          cd $HOME/VirtMachines/$1
        }
        function cdap {
          cd $HOME/.local/share/applications
        }

        function cdphd {
          cd /arch$HOME/PhD/$1
        }
        # First argument is the repository, e.g. nixpkgs, second is the package regex
        function nixs {
          nix search $1 $2
        }
        function rollback {
          sudo nixos-rebuild --rollback switch
        }

        function aroot {
          sudo $HOME/.local/bin/arch-chroot /arch /bin/zsh -c "/bin/su - fusion809"
        }
        function notif {
        	lenOfStr=$(echo "$1" | awk -F ":" '{print NF-1}')
        	while :
        	do
        		if ( [[ $lenOfStr == 1 ]] && [[ $(date +"%H:%M") == "$1" ]] ); then
        			zenity --error --title="$2" --text "$2" && return
        		elif ( [[ $lenOfStr == 2 ]] && [[ $(date +"$H:$M:$S") == "$1" ]] ); then
        			zenity --error --title="$2" --text "$2" && return
        		fi
        	done
        }

        function ved {
        	cdphd Rcode/RQ5
        	vim Edits_to_parameters_$(date +"%Y-%m-%d").txt
        }

        function ged {
        	cdphd Rcode/RQ5
        	grep --include="Edits_to_parameters*.txt" -R "$1" | sort
        }
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
