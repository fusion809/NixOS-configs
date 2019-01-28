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

  networking.hostName = "fusion809-pc"; # Define your hostname.
  # Select internationalisation properties.
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
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
    wget os-prober psmisc efibootmgr gnome3.gnome-tweaks gnome3.zenity xclip p7zip

    # Terminals
    yakuake
    libsForQt5.kglobalaccel
    rxvt_unicode-with-plugins

    # Audio/graphics/video/fonts
    ffmpegthumbnailer
    font-awesome_5
    gimp
    imagemagick
    vlc
    librsvg

    # Browsers
    chrome-gnome-shell
    google-chrome
    firefox
    tor-browser-bundle-bin

    # IRC
    hexchat
    konversation

    # Other network stuff
    googleearth
    qbittorrent

    # Office
    libreoffice-fresh
    wpsoffice

    # Editors
    atom
    vscode
    neovim
    notepadqq
    sublime3
    vimHugeX
  
    # Development tools
    clang_7
    cloc
    codeblocks
    cppcheck
    dpkg
    gcc
    gdb
    gist
    git
    gitAndTools.hub
    gnome-builder
    gnumake
    kdevelop
    python27Packages.osc
    python37Full
    rpm
    
    # Chemistry
    marvin
    #pymol, commented out due to build failures
    jmol

    # Math
    gap
    giac
    gnuplot
    octaveFull
    # julia_10; commented out due to the insane RAM and CPU usage of test suite that I have not found how to disable, even when editing nix file directly
    scilab-bin
    wxmaxima
    # SageMath can be handy, but really increases build time

    # Games
    gnome3.aisleriot
    gnome3.gnome-mines
    # Cannot add SuperTux or SuperTuxKart as their build fails, have to install from nixos (stable)

    ## OpenRA
    openraPackages.engines.bleed
    openraPackages.mods.ca
    openraPackages.mods.d2
    openraPackages.mods.dr
    #openraPackages.mods.gen
    openraPackages.mods.kknd
    openraPackages.mods.mw
    openraPackages.mods.ra2
    openraPackages.mods.raclassic
    openraPackages.mods.rv
    openraPackages.mods.sp
    openraPackages.mods.ss
    openraPackages.mods.ura
    openraPackages.mods.yr
  ];

  # As user I could install additional packages, like: 
  # atom, codeblocks-full, julia_10, octaveFull, openra, sage, scilab-bin, vscode

  services.flatpak.enable = true;
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
      extraPkgs = p: with p; [ harfbuzz mono ]; 
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
  services.xserver.desktopManager.plasma5.enable = true;
  # Enable the GNOME Desktop Environment.
  services.xserver.desktopManager.gnome3.enable = true;
  services.gnome3.chrome-gnome-shell.enable = true;
  # i3
  services.xserver.windowManager.i3.enable = true;
  services.xserver.windowManager.i3.extraPackages = with pkgs; [
     rofi i3status feh networkmanager_dmenu i3pystatus rxvt kdevelop
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
  system.stateVersion = "18.09"; # Did you read the comment?
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  fileSystems.gentoo.device = "/dev/sda5";
  fileSystems.gentoo.mountPoint = "/gentoo";
  fileSystems.arch.device = "/dev/sda6";
  fileSystems.arch.mountPoint = "/arch";
  fileSystems.data.device = "/dev/sdb1";
  fileSystems.data.mountPoint = "/data";
  fileSystems.tumbleweed.device = "/dev/sda9";
  fileSystems.tumbleweed.mountPoint = "/tumbleweed";
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
}
