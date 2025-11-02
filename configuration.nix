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
  # Bootloader.
  boot = {
    initrd.systemd.tpm2.enable = false;
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      timeout = -1;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        default = 1;
      };
      efi.canTouchEfiVariables = true;
    };
  };

# List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    home-manager
    grimblast              # Screenshots under Hyprland
    hyprlandPlugins.hy3    # Tabbing under Hyprland
    swaynotificationcenter # Required for notifications
    # Theming
    pantheon.elementary-wallpapers
    whitesur-gtk-theme
    whitesur-cursors
    whitesur-icon-theme
    # Required by Waybar widgets
    lm_sensors
    wttrbar
    # Core apps for Hyprland
    gnome-text-editor
    nautilus
    ffmpegthumbnailer
    alacritty
    unstable.kitty
    # Games
    openra-git
    superTux
    superTuxKart
    aisleriot
    gnome-chess
    gnuchess
    # Chemistry software
    jmol
    marvin
    pymol
    # Maths software
    julia
    R
    octave
    sage
    python313Packages.jupyterlab
    # Required for a clipboard
    wl-clip-persist
    wl-clipboard
    # Application menu for Hyprland
    rofi-wayland
    # Assorted Hyprland utilities
    swaybg
    # Command-line utilities
    dnsmasq
    #distrohoop
    fastfetch
    jq
    git
    keychain
    hyfetch
    gtop
    nix-prefetch-git
    dotnetCorePackages.sdk_8_0_3xx
    nuget-to-json
    optipng
    pciutils
    wget
    # Bluetooth
    bluez
    bluez-tools
    # Assorted other apps    
    brave
    discord
    docker
    docker-compose
    gimp
    google-chrome
    onlyoffice-desktopeditors
    steam-run
    texliveFull
    texstudio
    virt-viewer
    vlc
    vscode
    unstable.winboat
    # Other packages
    gtk2
    font-awesome
  ];
  fonts = {
    packages = with pkgs; [ 
      nerd-fonts.jetbrains-mono 
      nerd-fonts.noto
      nerd-fonts.hurmit
      nerd-fonts.hasklug
    ];
  };
  hardware = {
    steam-hardware.enable = true;
    bluetooth.enable = true;
    graphics.enable = true;
    nvidia.open = false;  # Should only be true for newer cards
  };
  # Set up home manager
  home-manager.users.fusion809 = {
        imports =
          [
            ./home.nix
          ];
  };

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
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
  };

  # Enable networking
  networking = {
    hostName = "nixos"; # Define your hostname.
    # Enable networking
    networkmanager.enable = true;
  };
  nix.settings.experimental-features = ["nix-command" "flakes"];
  # Allow unfree packages
  nixpkgs = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
                  "openssl-1.1.1w"
                  "dotnet-runtime-6.0.36"
                  "dotnet-sdk-6.0.428"
      ];
      packageOverrides = pkgs: {
        unstable = import <unstable> {
          config = config.nixpkgs.config;
        };
      };
    };
    overlays = import ./overlays.nix;
  };
  # Install firefox.
  programs = {
    appimage = {
      enable = true;
      binfmt = true;
    };
    bash.shellInit = "
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
    cd $HOME/GitHub/mine/config/NixOS-configs $1
  }

  function nixver {
    nix-channel --list | grep nixos | cut -d '-' -f 2
  }
  
  function rebuild {
    if [[ $(git-branch $HOME/GitHub/mine/config/NixOS-configs) != $(nixver) ]]; then
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
    if [[ $(git-branch $HOME/GitHub/mine/config/NixOS-configs) != $(nixver) ]]; then
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
    firefox = {
      enable = false;
    };
    hyprland.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    vim = {
      enable = true;
      defaultEditor = true;
      package = pkgs.vim_configurable;
    };
    virt-manager.enable = true;
    waybar.enable = true;
    zsh = {
      autosuggestions.enable = true;
      enable = true;
      enableCompletion = true;
      ohMyZsh = {
        enable = true;
        plugins = [
          "safe-paste"
          "vi-mode"
        ];
      };
      shellInit = "
sed -i '/^:/!d' $HOME/.zsh_history
source /etc/profile
source $HOME/GitHub/mine/config/NixOS-configs/hnixos.zsh-theme
  ";
      syntaxHighlighting.enable = true; 
    };
  };
  # Enable sound with pipewire.
  security = {
    rtkit.enable = true;
    sudo.wheelNeedsPassword = false;
  };
  services = {
    blueman = {
      enable = true;
    };
    displayManager = {
      sddm.enable = true;
      autoLogin = {
        enable = true;
        user = "fusion809";
      };
    };
    pipewire = {
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
    pulseaudio = {
      enable = false;
    };
    printing = {
      enable = false;
    };
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb = {
        layout = "us";
        variant = "";
      };
    };
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
  # Set up systemd services
  systemd = {
    # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
    services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
      dev-tpmrm0.enable = false;
    };
    tpm2.enable = false;
    user.services.swaync = {
      description = "Sway Notification Center";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
        Restart = "always";
        RestartSec = 3;
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Australia/Brisbane";
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users.fusion809 = {
      isNormalUser = true;
      description = "Brenton";
      extraGroups = [ "networkmanager" "wheel" "input" "docker" "libvirtd" ];
      packages = with pkgs; [
      #  thunderbird
      ];
    };
  };
  #virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableKvm = true;
  #virtualisation.virtualbox.host.addNetworkInterface = false;
  #virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation = {
    docker = {
      enable = true;
    };
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = { # not needed in NixOS 25.11 since https://github.com/NixOS/nixpkgs/pull/421549
          enable = true;
          packages = [(pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd];
        };
      };
    };
    spiceUSBRedirection.enable = true;
  };
}


