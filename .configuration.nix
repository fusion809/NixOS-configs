# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  #boot.initrd.prepend = [ "/boot/initramfs-linux.img" ];
  boot.loader.grub.default = 0;
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "nodev"; # or "nodev" for efi only
  boot.loader.grub.useOSProber = true; # got to OS probe other distros
  boot.loader.grub.configurationLimit = 2;
  nix.autoOptimiseStore = true;
  #nixpkgs.config.firefox.enableAdobeFlash = true;
  
  networking.hostName = "fusion809-pc"; # Define your hostname.
  # Select internationalisation properties.
  console.keyMap = "us";
  console.font = "Lat2-Terminus16";
  i18n = {
    defaultLocale = "en_AU.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "Australia/Brisbane";

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  nixpkgs.overlays = import /home/fusion809/.config/nixpkgs/overlays.nix ;
  environment.systemPackages = with pkgs; [
  # These packages will be from the stable branch of the repos (with older, but more tested packages)
  # If you need newer ones install them as user, after adding the unstable repository by running:
  # sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
  # sudo nix-channel --update nixos-unstable
  # and then install the package with:
  # nix-env -f '<nixos-unstable>' -iA package
    wget psmisc efibootmgr xclip neofetch pciutils

    # Archiving
    p7zip
    ark
    unzip
    libarchive

    # Terminals
    dolphin
    mate.eom
    texlive.combined.scheme-full
    texstudio

    # i3 stuff
    pcmanfm
    lxappearance

    # Audio/graphics/video/fonts
    ffmpegthumbnailer
    ffmpeg
    ffmpegthumbs
    kdeApplications.kio-extras
    font-awesome_5
    gimp
    optipng
    imagemagick
    inkscape
    vlc
    mediainfo-gui
    librsvg

    # Browsers
#    chrome-gnome-shell
    google-chrome
    aria2

    # IRC
    hexchat
 #   konversation

    # Other network stuff
 #   gnome3.empathy
 #   aria2
    #googleearth

    # Office
    libreoffice-fresh
    #wpsoffice
    zotero
#    okular
    gnome3.evince

    # Editors
    atom
    vscode
 #   neovim
    notepadqq
    vimHugeX
  
    # Development tools
 #   clang_7
 #   cloc
 #   codeblocks
 #   cppcheck
 #   dpkg
 #   gcc
 #   gdb
     gist
     git
     gitAndTools.hub
 #   gnome-builder
 #   gnumake
 #   kdevelop
 #   python27Packages.osc
 #   rpm
 #   ruby_2_5
    
    # Chemistry
    avogadro
    marvin
    #pymol, commented out due to build failures
    jmol

    # Math
  #  gap
  #  giac
  #  gnuplot
    ( octaveFull.override { python = python.withPackages (ps: with ps; [ sympy ]);} ) 
    python37Packages.jupyterlab
    python37Packages.jupyterlab_launcher
    #pspp
    # Best to use it through the Arch chroot
    #sagemath
    jabref
    # julia_10; commented out due to the insane RAM and CPU usage of test suite that I have not found how to disable, even when editing nix file directly
  #  julia_10
    # Doesn't run per https://github.com/NixOS/nixpkgs/issues/70319
    #scilab-bin
  #  wxmaxima
    # Games
#    zeroad
#    urbanterror
    superTuxKart
    superTux
#    warzone2100
    gnome3.aisleriot
    gnome3.gnome-chess
    gnome3.gnome-mines
    gnome3.gnome-mahjongg
    # Cannot add SuperTux or SuperTuxKart as their build fails, have to install from nixos (stable)

    ## OpenRA
    # Can no longer be built
    #openraPackages.engines.bleed
    #openraPackages.mods.ca
    #openraPackages.mods.d2
    #openraPackages.mods.dr
    #openraPackages.mods.gen
    #openraPackages.mods.kknd
    #openraPackages.mods.mw
    #openraPackages.mods.ra2
    #openraPackages.mods.raclassic
    #openraPackages.mods.rv
    #openraPackages.mods.sp
    #openraPackages.mods.ss
    #openraPackages.mods.ura
    #openraPackages.mods.yr
    # Other GNOME apps
  #  gnome3.gnome-tweaks
    gnome3.zenity
  #  gnome3.gnome-calculator
  ];

  # As user I could install additional packages, like: 
  # atom, codeblocks-full, julia_10, octaveFull, #openra, sage, scilab-bin, vscode
  services.flatpak.enable = true;
  services.accounts-daemon.enable = true;
  environment.shells = [
     pkgs.zsh pkgs.bashInteractive
  ];

  users.defaultUserShell = pkgs.zsh;
  nixpkgs.config.allowUnfree = true;
 
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.bash.enableCompletion = true;
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.networkmanager.enable = true;
  users.extraUsers.fusion809 = 
 { isNormalUser = true;
   home = "/home/fusion809";
   uid = 1000;
   description = "Brenton Horne";
   extraGroups = [ "audio" "wheel" "networkmanager" ];
   packages = [
   (pkgs.appimage-run.override {
      extraPkgs = p: with p; [ harfbuzz mono fuse ]; 
    })
    ];
 };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  services.xserver.libinput.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable the KDE Desktop Environment.
  #services.xserver.desktopManager.plasma5.enable = true;
  # Enable the GNOME Desktop Environment.
  #services.xserver.desktopManager.gnome3.enable = true;
  #services.gnome3.chrome-gnome-shell.enable = true;
  # i3
  services.xserver.windowManager.i3.enable = true;
  services.xserver.windowManager.i3.extraPackages = with pkgs; [
     rofi i3status konsole
     (python37.withPackages(ps: [ (ps.toPythonModule (i3pystatus.override { python3Packages = ps; })) ]))
  ];
  services.xserver.displayManager.sddm = {
     enable = true;
     autoLogin.enable = true;
     autoLogin.user = "fusion809";
  };
  services.xserver.displayManager.gdm = {
     enable = false;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.extraUsers.guest = {
  #   isNormalUser = true;
  #   uid = 1000;
  # };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = https://nixos.org/channels/nixos-unstable;
  system.autoUpgrade.dates = "19:30";
  system.stateVersion = "20.03pre"; # Did you read the comment?
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Using UUIDs is important, as if /dev/sdXn is used NixOS will try to mount the wrong petition
  # Due to the presence of two disks, which confuses it sometimes
  fileSystems.arch.device = "/dev/disk/by-uuid/c324ba12-1932-45e4-9f38-f13bbcfef1d0";
  fileSystems.arch.mountPoint = "/arch";
  fileSystems.data.device = "/dev/disk/by-uuid/95eac782-d467-42c1-b31e-11020b29a353";
  fileSystems.data.mountPoint = "/data";
  fileSystems.debian.device = "/dev/disk/by-uuid/dd381240-03fa-4255-a89b-39b6b28bd0a0";
  fileSystems.debian.mountPoint = "/debian";
  #virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableExtensionPack = true;
  nixpkgs.config.allowBroken = true;
  xdg.portal.enable = true;
}
