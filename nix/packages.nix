{ pkgs, ... }:

with pkgs; [
  ###############################################################
  # Assorted apps
  ###############################################################   
  unstable.antigravity
  brave
  discord
  firefox
  gimp
  google-chrome
  inkscape
  nixfmt-classic # Needed for Nix IDE extension of vscode/antigravity
  pinta
  vscode
  ###############################################################
  # Assorted packages
  ###############################################################
  #font-awesome
  ###############################################################
  # Bluetooth
  ###############################################################
  bluez
  bluez-tools
  ###############################################################
  # Chemistry software
  ###############################################################
  unstable.avogadro2 # unstable to silence outdated popup msg.
  (import ./ds-fhs-env.nix { pkgs = pkgs.oldstable; }) # DSV
  (import ./csd-env.nix { inherit pkgs; }) # Mercury / CSD
  jmol
  marvin
  molsketch
  pymol
  ###############################################################
  # Command-line utilities
  ###############################################################
  aria2
  dnsmasq
  fastfetch
  doctoc
  fdupes
  ffmpeg-full
  ghostscript
  git
  glib # provides gdbus, needed by Waybar kdeconnect script
  gnuplot
  gtop
  jq
  keychain
  hyfetch
  imagemagick
  libnotify
  nethogs
  nh
  nil
  nixd
  nodejs
  optipng
  p7zip
  pciutils
  python3
  scc
  smartmontools
  psmisc # For fuser
  sshfs # Required for KDE Connect device browsing
  sshpass
  usbutils
  unzip
  wget
  winetricks
  wineWowPackages.stable
  unstable.yt-dlp
  zenity
  zstd
  ###############################################################
  # Hyprland essentials
  ###############################################################
  grimblast # Screenshots under Hyprland
  hyprlandPlugins.hy3 # Tabbing under Hyprland
  swaynotificationcenter # Required for phone notifications
  ## Core apps
  alacritty
  desktop-file-utils
  kdePackages.dolphin
  ffmpegthumbnailer
  kdePackages.gwenview
  # Required to change file associations
  kdePackages.kde-cli-tools
  # Required for mimeapps.list file associations to stick in Dolphin
  kdePackages.kio-extras
  kdePackages.kio-fuse
  kdePackages.kio-gdrive
  kdePackages.kaccounts-providers
  kdePackages.kaccounts-integration
  kdePackages.signon-kwallet-extension
  kdePackages.kservice
  kdePackages.plasma-desktop
  kdePackages.plasma-workspace
  kdePackages.systemsettings
  kdePackages.knewstuff
  kdePackages.kdeclarative
  kdePackages.ksvg
  kdePackages.qqc2-desktop-style
  # Other apps
  unstable.kitty # the stable package for 25.05 didn't have a scrollbar
  libmtp
  rclone
  vlc
  ## Required by Waybar widgets
  lm_sensors
  pavucontrol
  wttrbar
  ## Required for a clipboard
  cliphist
  wl-clip-persist
  wl-clipboard
  ## Other utilities
  rofi
  swaybg
  ###############################################################
  # Games
  ###############################################################
  aisleriot
  gnome-chess
  gnome-mahjongg
  gnuchess
  kdePackages.kmines
  lutris
  openra-git
  space-cadet-pinball
  superTux
  superTuxKart
  #zeroad
  ###############################################################
  # Maths software
  ###############################################################
  julia
  python313Packages.jupyterlab
  octave
  R
  rstudio
  sage
  ###############################################################
  # NixOS utilities
  ###############################################################
  home-manager
  nix-prefetch-git
  linuxPackages_latest.kernel
  python3Packages.pydbus
  python3Packages.pygobject3

  ###############################################################
  # Office software
  ###############################################################
  kdePackages.okular
  languagetool
  texliveFull
  texstudio
  zotero
  hunspell
  hunspellDicts.en_AU
  ###############################################################
  # Theming
  ###############################################################
  whitesur-gtk-theme
  whitesur-cursors
  master.whitesur-icon-theme
  ###############################################################
  # Virtualization
  ###############################################################
  docker
  docker-compose
  freerdp
  guestfs-tools
  OVMF
  xorriso # Can be used to get files from host to guest
  virt-viewer
  virtiofsd
  #(unstable.winboat.override { nodejs_24 = pkgs.nodejs_24; })
  (winboat.override { electron = electron_40; })
]
