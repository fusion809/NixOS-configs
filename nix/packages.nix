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
  master.vscode
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
  openbabel
  pymol
  ###############################################################
  # Command-line utilities
  ###############################################################
  aria2
  dnsmasq
  fastfetch
  ffmpeg-full
  git
  gnuplot
  gtop
  jq
  keychain
  hyfetch
  libnotify
  nethogs
  nh
  nil
  nixd
  nodejs
  ollama
  optipng
  p7zip
  pciutils
  python3
  scc
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
  zotero
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
  xorriso # Can be used to get files from host to guest
  virt-viewer
  #(unstable.winboat.override { nodejs_24 = pkgs.nodejs_24; })
  unstable.winboat
]
