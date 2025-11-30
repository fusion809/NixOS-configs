{ pkgs, ... }:

with pkgs; [
  ###############################################################
  # Assorted apps
  ###############################################################   
  master.antigravity
  brave
  discord
  element-desktop
  gimp
  google-chrome
  inkscape
  nixfmt-classic # Needed for Nix IDE extension of vscode/antigravity
  pinta
  vlc
  unstable.vscode
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
  (import ./ds-fhs-env.nix { inherit pkgs; }) # DSV
  jmol
  marvin
  molsketch
  openbabel
  pymol
  ###############################################################
  # Command-line utilities
  ###############################################################
  aria2
  cloc
  dnsmasq
  fastfetch
  ffmpeg-full
  git
  gtop
  jq
  keychain
  hyfetch
  libnotify
  nh
  optipng
  p7zip
  pciutils
  unzip
  wget
  winetricks
  wineWowPackages.stable
  yt-dlp
  zenity
  ###############################################################
  # Hyprland essentials
  ###############################################################
  grimblast # Screenshots under Hyprland
  hyprlandPlugins.hy3 # Tabbing under Hyprland
  swaynotificationcenter # Required for notifications
  ## Core apps
  alacritty
  eog # For viewing images
  ffmpegthumbnailer
  gnome.gvfs
  unstable.kitty # the stable package for 25.05 didn't have a scrollbar
  libmtp
  nautilus
  ## Required by Waybar widgets
  lm_sensors
  wttrbar
  ## Required for a clipboard
  cliphist
  wl-clip-persist
  wl-clipboard
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
  ###############################################################
  # Office software
  ###############################################################
  kdePackages.okular
  onlyoffice-desktopeditors
  texliveFull
  texstudio
  ###############################################################
  # Theming
  ###############################################################
  pantheon.elementary-wallpapers
  whitesur-gtk-theme
  whitesur-cursors
  master.whitesur-icon-theme
  ###############################################################
  # Virtualization
  ###############################################################
  docker
  docker-compose
  freerdp
  OVMF
  xorriso # Can be used to get files from host to guest
  virt-viewer
  (unstable.winboat.override { nodejs_24 = pkgs.nodejs_24; })
]
