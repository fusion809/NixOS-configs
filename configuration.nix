# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <home-manager/nixos>
    ];
home-manager.users.fusion809 = {
        imports =
          [
            ./home.nix
          ];
  };
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.default = 1;
  boot.loader.grub.timeout = 5;
  systemd.services.dev-tpmrm0.enable = false;
  systemd.tpm2.enable = false;
  boot.initrd.systemd.tpm2.enable = false;
  systemd.services.vboxnet0.enable = false;

  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Australia/Brisbane";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.fusion809 = {
    isNormalUser = true;
    description = "Brenton";
    extraGroups = [ "networkmanager" "vboxvideo" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };
  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "fusion809";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Install firefox.
  programs.firefox.enable = true;
  programs.vim.enable = true;
  programs.vim.defaultEditor = true;
  programs.vim.package = pkgs.vim_configurable;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    xclip
    gnomeExtensions.show-desktop-button
    gnomeExtensions.dash-to-dock
    home-manager
    keychain
    pantheon.elementary-wallpapers
    whitesur-gtk-theme
    whitesur-cursors
    whitesur-icon-theme
    gtk2
    kitty
    wofi
    rofi-wayland
    font-awesome
    bluez
    gnome-terminal
    rofi-bluetooth
    bluez-tools
    google-chrome
    pciutils
    gnome-tweaks
    brave
    gimp
    tor-browser
    runescape
    flatpak
    kdePackages.kdeconnect-kde
    blueman
  ];
  services.flatpak.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
                "openssl-1.1.1w"
              ];
  nixpkgs.overlays = import ./overlays.nix;
  programs.steam = {
  enable = true;
  remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
};
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableKvm = true;
  virtualisation.virtualbox.host.addNetworkInterface = false;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = ["fusion809"];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
programs.bash.shellInit = "
export PATH=$PATH:/run/current-system/sw/bin:/run/current-system/sw/sbin
if [[ \"$EUID\" -eq 0 ]]; then
  function git-branch {
    if ! [[ -n \"$1\" ]]; then
      git rev-parse --abbrev-ref HEAD
    else
      git -C \"$1\" rev-parse --abbrev-ref HEAD
    fi
  }

  function cdnc {
    cd /home/fusion809/NixOS-configs $1
  }

  function nixver {
    nix-channel --list | grep nixos | cut -d '-' -f 2
  }
  
  function rebuild {
    if [[ $(git-branch /home/fusion809/NixOS-configs) != $(nixver) ]]; then
      cdnc
      git checkout $(nixver) || (printf 'git checkout has failed.' && return 1)
    fi
    nixos-rebuild switch
  }

  alias nixrb=rebuild

  function nixstrep {
    nix-store --repair --verify --check-contents
  }
  
  function nixcg {
    nix-collect-garbage -d
  }

  function nixrsu {
    if [[ $(git-branch /home/fusion809/NixOS-configs) != $(nixver) ]]; then
      cdnc
      git checkout $(nixver) || (printf 'git checkout has failed.' && return 1)
    fi

    nixos-rebuild switch --upgrade
  }

  function update {
    nix-store --repair --verify --check-contents
    nixrsu
    nixcg
  }
  
  function vcf {
    vim /etc/nixos/configuration.nix
  }

  function clipf {
    xclip -sel clip < $1
  }

  function rainbowfastfetch {
    hyfetch -p rainbow -b fastfetch --args=\"--localip-show-ipv4 false\"
  }

  function gaymenfastfetch {
    hyfetch -p gay-men -b fastfetch --args=\"--localip-show-ipv4 false\"
  }

  function rffetch {
    cd ~/
    rainbowfastfetch
  }

  function gmffetch {
    cd ~/
    gaymenfastfetch
  }
fi

function vzsh {
  vim $HOME/.zshrc
}

function szsh {
  source $HOME/.zshrc
}

function vbash {
  vim $HOME/.bashrc
}
";
  programs.zsh.enable = true;
  programs.zsh.shellInit = "
sed -i '/^:/!d' $HOME/.zsh_history
source /etc/profile
source /home/fusion809/NixOS-configs/hnixos.zsh-theme
  ";
  programs.hyprland.enable = true;
  programs.waybar.enable = true;
  security.sudo.wheelNeedsPassword = false;
  programs.zsh.ohMyZsh.enable = true;
  programs.zsh.autosuggestions.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;
  programs.zsh.enableCompletion = true;
  programs.zsh.ohMyZsh.plugins = [
	"safe-paste"
	"vi-mode"
  ];
  users.defaultUserShell = pkgs.zsh;
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}


