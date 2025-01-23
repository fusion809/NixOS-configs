# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

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
  services.xserver.excludePackages = with pkgs; [
	xterm
  ];

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = false; # Make it use X11 by default
  services.gnome.gnome-browser-connector.enable = true;
  environment.gnome.excludePackages = (with pkgs; [
  	epiphany
        geary
	totem
        gnome-maps
        yelp
        gnome-logs
	gnome-calculator
	gnome-calendar
	gnome-clocks
	gnome-contacts
	gnome-disk-utility
	gnome-music
	gnome-system-monitor
	gnome-tour
	gnome-weather
	evince
	gnome-connections
	snapshot
	gnome-characters
	baobab
	loupe
	simple-scan
	file-roller
	rygel
	gnome-bluetooth
	gnome-color-manager
	gnome-console
	gnome-font-viewer
	gnome-online-accounts
	gnome-remote-desktop
	gnome-user-share
	seahorse
  ]);

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  security.sudo.wheelNeedsPassword = false;
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
    description = "Brenton Horne";
    extraGroups = [ "networkmanager" "wheel" ];
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

  # Omit nano
  programs.nano.enable = false;

  # Use Vim instead
  programs.vim.enable = true;
  programs.vim.defaultEditor = true;
  programs.vim.package = pkgs.vim_configurable;

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
    # "openssl-1.1.1w" Used by RuneScape
      "dotnet-runtime-6.0.36"
      "dotnet-sdk-6.0.428"
    ];
  };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.overlays = import ./overlays.nix;

  environment.systemPackages = (with pkgs; [
	fastfetch
	hyfetch
        keychain
        wget
	gnome-tweaks
        whitesur-gtk-theme
        whitesur-cursors
        whitesur-icon-theme
        gnome-terminal
	deepin.deepin-wallpapers
        budgie-backgrounds
	pantheon.elementary-wallpapers
        unzip
        #runescape
	cosmic-wallpapers
	git
	xclip
        #openra-git
        vimPlugins.vim-nix
        vimPlugins.vim-nixhash
        ((vim_configurable.override {  }).customize{
      name = "vim";
      # Install plugins for example for syntax highlighting of nix files
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [ vim-nix vim-nixhash ];
        opt = [];
      };
      vimrcConfig.customRC = ''
        " your custom vimrc
        set nocompatible
        set backspace=indent,eol,start
        " Turn on syntax highlighting by default
        syntax on
        " ...
      '';
    }
  )
    ]) ++ (with pkgs.nixos-artwork.wallpapers; [
		binary-black
		catppuccin-mocha
		catppuccin-macchiato
		catppuccin-latte
		catppuccin-frappe
		moonscape
		nineish
		nineish-dark-gray
		nineish-solarized-dark
		nineish-solarized-light
		simple-blue
		simple-dark-gray
		simple-dark-gray-bootloader
		simple-dark-gray-bottom
		simple-light-gray
		simple-red
		stripes-logo
		stripes
		waterfall
		watersplash
	]);

  environment.pathsToLink = ["/share/backgrounds/nixos"];
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh.enable = true;
  programs.zsh.autosuggestions.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;
  programs.zsh.enableCompletion = true;
  programs.zsh.ohMyZsh.plugins = [
	"safe-paste"
	"vi-mode"
  ];
  users.defaultUserShell = pkgs.zsh;
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

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
  system.stateVersion = "24.11"; # Did you read the comment?
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.dragAndDrop = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

