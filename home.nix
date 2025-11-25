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
        function cdc {
          cd $HOME/Chem/$1
        }

        function cddc {
          cd $HOME/Documents/$1
        }

        function cddo {
          cd $HOME/Downloads/$1
        }

        function cdg {
          cd $HOME/GitHub/$1
        }

        function cdgo {
          cdg others/$1
        }

        function cdm {
          cd $HOME/Music/$1
        }

        function cdp {
          cd $HOME/Pictures/$1
        }

        function cdv {
          cd $HOME/Videos/$1
        }

        function cdvm {
          cd $HOME/VirtMachines/$1
        }

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
            touch ~/.cache/umount_arch
          fi
        }

        function mount_arch {
          if ! `mountpoint -q /arch` && ! [[ -f $HOME/.cache/umount_arch ]]; then
            sudo mount /dev/disk/by-label/arch /arch
            sudo mount /dev/disk/by-label/ARCHEFI /arch/boot
          elif [[ -f $HOME/.cache/umount_arch ]]; then
            echo '$HOME/.cache/umount_arch exists, so a Nix rebuild is likely happening...'
          fi
        }

        function mount_data {
          if ! `mountpoint -q /data`; then
            sudo mount '/dev/disk/by-label/Data\x20partition' /data
          fi
        }

        mount_data

        function rebuild {
          umount_arch
          sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix
          rm -f $HOME/.cache/umount_arch
          mount_arch
        }

        alias nixrb=rebuild
        function nixrsu {
          sudo nix-channel --update
          nixrb
        }

        function nixfrb {
          sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix --flake $HOME/GitHub/mine/config/NixOS-configs/#nixos --impure
        }

        function update {
          sudo nix-store --repair --verify --check-contents
          nixrsu
          nixcg
        }

        function clipf {
          if `ps ax | grep wayland &> /dev/null`; then
            wl-copy < $1
          else
            xclip -sel clip < $1
          fi
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
          cd $HOME/GitHub/mine/config/NixOS-configs/$1
        }

        function vhom {
          vim $HOME/GitHub/mine/config/NixOS-configs/home.nix
        }

        alias vhx=vhom
        function vrm {
          if [[ -f README.md ]]; then
            vim README.md
          else
            vim $HOME/GitHub/mine/config/NixOS-configs/README.md
          fi
        }
        mount_arch

        function vsnc {
          code $HOME/GitHub/mine/config/NixOS-configs
        }

        function vshc {
          code $HOME/GitHub/mine/config/hyprland-configs
        }

        function comno {
        	git rev-list --count HEAD
        }

        function revision {
        	git log | head -n 1 | cut -d ' ' -f 2
        }
        pushd -q $HOME/GitHub/others/OpenRA
        git pull origin bleed -q
        latestRev=$(revision)
        popd -q
        packagedRev=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '"' -f 2)
        if [[ $latestRev != $packagedRev ]]; then
          echo \"OpenRA git package is out of date. openraup will update it.\"
        fi

        function openraup {
          pushd -q $HOME/GitHub/others/OpenRA
          git pull origin bleed -q
          latestRev=$(revision)
          upno=$(comno)
          uphash=$(revision | head -c 7)
          popd -q
          packagedRev=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '"' -f 2)
          sed -i -e \"s|$packagedRev|$latestRev|g\" $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix
          latestHash=$(nix-prefetch-git --url https://github.com/OpenRA/OpenRA --rev $latestRev 2>&1 | grep '\"hash\"' | cut -d '"' -f 4)
          packagedHash=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'hash' | cut -d '"' -f 2)
          packagedVer=$(cat $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix | grep 'version' | cut -d '"' -f 2)
          latestVer=\"$upno.git.$uphash\"
          sed -i -e \"s|$packagedHash|$latestHash|g\" -e \"s|$packagedVer|$latestVer|g\" $HOME/GitHub/mine/config/NixOS-configs/nixpkgs/openra/engines/git/default.nix        
          nixrb
        }
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
