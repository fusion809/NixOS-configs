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
  hardware.pulseaudio.enable = true; # Not sure if audio will work without it

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
  environment.systemPackages = with pkgs; [
     wget vim git zsh vlc firefox hexchat konversation os-prober yakuake libsForQt5.kglobalaccel pcmanfm lxappearance virtualbox flatpak
  ];

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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
#  networking.networkmanager.enable = true;
  users.extraUsers.fusion809 = 
 { isNormalUser = true;
   home = "/home/fusion809";
   uid = 1000;
   description = "Brenton Horne";
   extraGroups = [ "wheel" "networkmanager" ];
 };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  services.xserver.libinput.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.slim.autoLogin = true;
  services.xserver.windowManager.i3.enable = true;
 # services.xserver.displayManager.lightdm = {
 #   enable = true;
 #   autoLogin.enable = true;
 #   autoLogin.user = "fusion809";
 # };
  services.xserver.windowManager.i3.extraPackages = with pkgs; [
     rofi i3status feh networkmanager_dmenu
  ];
  services.xserver.windowManager.i3.extraSessionCommands = "bash $HOME/.xsession";
  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable the KDE Desktop Environment.
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.desktopManager.gnome3.enable = true;

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
  security.sudo.wheelNeedsPassword = false;

  fileSystems.gentoo.device = "/dev/sda5";
  fileSystems.gentoo.mountPoint = "/gentoo";
  fileSystems.arch.device = "/dev/sda6";
  fileSystems.arch.mountPoint = "/arch";
  fileSystems.data.device = "/dev/sdb1";
  fileSystems.data.mountPoint = "/data";
  fileSystems.tumbleweed.device = "/dev/sda8";
  fileSystems.tumbleweed.mountPoint = "/tumbleweed";
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
}
