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
    ###############################################################
    # Assorted apps
    ###############################################################   
    brave
    discord
    gimp
    google-chrome
    vlc
    unstable.vscode
    ###############################################################
    # Assorted packages
    ###############################################################
    font-awesome
    ###############################################################
    # Bluetooth
    ###############################################################
    bluez
    bluez-tools
    ###############################################################
    # Chemistry software
    ###############################################################
    unstable.avogadro2    # unstable to silence outdated popup msg.
    ## DS Visualizer
    kdePackages.qtwayland
    qt5.qtwayland
    deepin.qt5platform-plugins
    # tcsh
    jmol
    marvin
    pymol
    molsketch
    openbabel
    ###############################################################
    # Command-line utilities
    ###############################################################
    dnsmasq
    fastfetch
    git
    gtop
    jq
    keychain
    hyfetch
    libnotify
    nh
    optipng
    pciutils
    tcsh
    wget
    zenity
    ###############################################################
    # Hyprland essentials
    ###############################################################
    grimblast                       # Screenshots under Hyprland
    unstable.wayland
    unstable.hyprlandPlugins.hy3             # Tabbing under Hyprland
    swaynotificationcenter          # Required for notifications
    ## Core apps
    alacritty
    ffmpegthumbnailer
    gnome.gvfs
    xfce.mousepad
    unstable.kitty
    libmtp
    nautilus
    ## Required by Waybar widgets
    lm_sensors
    wttrbar
    ## Required for a clipboard
    wl-clip-persist
    wl-clipboard
    cliphist
    ## Other utilities
    rofi-wayland
    swaybg
    ###############################################################
    # Games
    ###############################################################
    aisleriot
    gnome-chess
    gnome-mahjongg
    gnuchess
    kdePackages.kmines
    openra-git
    space-cadet-pinball
    superTux
    superTuxKart    
    zeroad
    ###############################################################
    # Maths software
    ###############################################################
    julia
    python313Packages.jupyterlab
    octave
    R
    sage
    ###############################################################
    # NixOS utilities
    ###############################################################
    home-manager
    nix-prefetch-git
    ###############################################################
    # Office software
    ###############################################################
    onlyoffice-desktopeditors
    texliveFull
    texstudio
    ###############################################################
    # Theming
    ###############################################################
    pantheon.elementary-wallpapers
    whitesur-gtk-theme
    whitesur-cursors
    whitesur-icon-theme
    ###############################################################
    # Virtualization
    ###############################################################
    docker
    docker-compose
    virt-viewer
    unstable.winboat
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
        staging-next = import (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/staging-next.tar.gz";
        })
        { };
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
    hyprland = {
      enable = true;
      package = pkgs.unstable.hyprland; # Thought using unstable lead to RS3 bugs, but happens even with stable
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        alsa-lib
        audit
        cairo
        libtiff
        e2fsprogs
        expat
        fontconfig
        freetype
        gd
        glib
        glibc
        keyutils
        krb5
        libdrm
        libgcc
        #libstdcxx
        bc
        bzip2
        xorg.libICE
        #libice
        libjpeg_turbo
        libnsl
        libpcap
        libpng
        libselinux
        libsepol
        xorg.libSM
        #libsm
        #libx11
        xorg.libX11
        #libxau
        xorg.libXau
        #libxdamage
        xorg.libXdamage
        zlib
        tcsh
        pam_krb5
        pam_p11
        #libxxf86vm
        xorg.libXxf86vm
        #libxtst
        xorg.libXtst
        #libxt
        xorg.libXt
        #libxrender
        xorg.libXrender
        #libxpm
        xorg.libXpm
        #libxmu
        xorg.libXmu
        #libxinerama
        xorg.libXinerama
        #libxi
        xorg.libXi
        #libxfixes
        xorg.libXfixes
        #libxext
        xorg.libXext
        #libxdmcp
        xorg.libXdmcp
        #tests.pkg-config.defaultPkgConfigPackages.libpcre2-16
        libGLU
        qt5.qtwayland
        deepin.qt5platform-plugins
        #deepin.qt5platform-plugins
        egl-wayland
        #gtk4-layer-shell # Seems irrelevant to error but on Arch
        libsForQt5.kwin
        libsForQt5.kwayland
        kdePackages.qtwayland
        kdePackages.kwayland
        kdePackages.wayqt
      ];
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    vim = {
      enable = true;
      defaultEditor = true;
      package = pkgs.staging-next.vim-full;
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
    gvfs = {
      enable = true;
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
  system = {
    autoUpgrade = {
      enable = true;
      dates = "daily";       # Following 2 are the default, so could be removed
      #, included for docs
      operation = "switch";
    };
    stateVersion = "25.05"; # Did you read the comment?
  };
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


