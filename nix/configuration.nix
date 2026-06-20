# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, username, ... }:

{
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./udev-rules.nix

  ];
  # Bootloader.
  boot = import ./boot.nix { inherit pkgs; };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = import ./packages.nix { inherit pkgs; };

  fonts = import ./fonts.nix { inherit pkgs; };
  hardware = import ./hardware.nix { };

  # Select internationalisation properties.
  i18n = import ./i18n.nix { };

  # Enable networking
  networking = import ./networking.nix { };
  nix = import ./nix.nix { };
  # Allow unfree packages
  nixpkgs = import ./nixpkgs.nix { inherit config inputs username; };
  # Install firefox.
  programs = import ./programs.nix { inherit pkgs inputs username; };
  # Enable sound with pipewire.
  security = import ./security.nix { };
  services = import ./services.nix { inherit pkgs username; };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system = import ./system.nix { inherit username; };

  # Set up systemd services
  systemd = import ./systemd.nix { inherit pkgs username; };

  # Set your time zone.
  time.timeZone = "Australia/Brisbane";
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = import ./users.nix { inherit pkgs username; };
  #virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableKvm = true;
  #virtualisation.virtualbox.host.addNetworkInterface = false;
  #virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation = import ./virtualisation.nix { inherit pkgs; };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  qt = {
    enable = true;
    style = "breeze";
    platformTheme = "kde";
  };

  environment.sessionVariables = {
    QT_PLUGIN_PATH = [
      "/run/current-system/sw/lib/qt-6/plugins"
      "/run/current-system/sw/lib/plugins"
    ];
    QML2_IMPORT_PATH = [
      "/run/current-system/sw/lib/qt-6/qml"
      "/run/current-system/sw/lib/qml"
    ];
    QML_IMPORT_PATH = [
      "/run/current-system/sw/lib/qt-6/qml"
      "/run/current-system/sw/lib/qml"
    ];
    GTK_USE_PORTAL = "1";
    NIXOS_OZONE_WL = "1";
  };


  # Manually link KDE menu files into /etc/xdg/menus so Dolphin can find them on Hyprland
  environment.etc."xdg/menus/plasma-applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
  environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}

