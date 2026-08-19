{ pkgs, inputs, ... }:

with pkgs;
[
  ###############################################################
  # Assorted apps
  ###############################################################
  unstable.antigravity-ide
  brave
  discord
  gimp
  google-chrome
  inkscape
  nixfmt # Needed for Nix IDE extension of vscode/antigravity
  opencode
  pinta
  vscode
  inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
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
  jpegoptim
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
  wineWow64Packages.stable
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
  kdePackages.kaccounts-providers
  kdePackages.kaccounts-integration
  kdePackages.kdeclarative
  kdePackages.kio-extras
  kdePackages.kio-fuse
  kdePackages.kio-gdrive
  kdePackages.knewstuff
  kdePackages.kservice
  kdePackages.ksvg
  kdePackages.plasma-desktop
  kdePackages.plasma-workspace
  kdePackages.qqc2-desktop-style
  kdePackages.signon-kwallet-extension
  kdePackages.systemsettings
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
  supertux
  supertuxkart
  #zeroad
  ###############################################################
  # Maths software
  ###############################################################
  julia
  python313Packages.jupyterlab
  octave
  (pkgs.callPackage ./r-fhs-env.nix { })
  rstudio-binary
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
  onlyoffice-desktopeditors
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
  (
    let
      # WinBoat's getFreeRDP() checks for "xfreerdp3" first, runs "--version" and checks stdout
      # for "version 3.". We create an xfreerdp3 shim pointing to the real xfreerdp binary.
      xfreerdp3Shim = pkgs.runCommand "winboat-xfreerdp3-shim" { } ''
              mkdir -p $out/bin
              
              cat > $out/bin/xfreerdp3 <<'EOF'
        #!/bin/sh
        if [ -n "$WAYLAND_DISPLAY" ]; then
          export SDL_VIDEO_DRIVER=wayland
          export SDL_VIDEODRIVER=wayland
        else
          export SDL_VIDEO_DRIVER=x11
          export SDL_VIDEODRIVER=x11
        fi

        W=1920
        H=1080
        if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
          focused_mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)' 2>/dev/null)
          if [ -n "$focused_mon" ]; then
            mon_w=$(echo "$focused_mon" | jq -r '.width' 2>/dev/null)
            mon_h=$(echo "$focused_mon" | jq -r '.height' 2>/dev/null)
            if [ -n "$mon_w" ] && [ "$mon_w" -ge 200 ] && [ -n "$mon_h" ] && [ "$mon_h" -ge 200 ]; then
              W=$mon_w
              H=$mon_h
            fi
          fi
        fi

        # Strip /f, -f, /fullscreen from arguments to prevent Wayland size-detection crash
        args=""
        has_size=0
        for arg in "$@"; do
          case "$arg" in
            /f|-f|/fullscreen)
              # Skip fullscreen flags
              ;;
            /size:*|-size:*|/w:*|/h:*)
              has_size=1
              args="$args \"$arg\""
              ;;
            *)
              args="$args \"$arg\""
              ;;
          esac
        done

        if [ $has_size -eq 0 ]; then
          eval exec ${pkgs.freerdp}/bin/sdl-freerdp "\"/size:''${W}x''${H}\"" $args
        else
          eval exec ${pkgs.freerdp}/bin/sdl-freerdp $args
        fi
        EOF
              chmod +x $out/bin/xfreerdp3

              cat > $out/bin/xfreerdp <<'EOF'
        #!/bin/sh
        if [ -n "$WAYLAND_DISPLAY" ]; then
          export SDL_VIDEO_DRIVER=wayland
          export SDL_VIDEODRIVER=wayland
        else
          export SDL_VIDEO_DRIVER=x11
          export SDL_VIDEODRIVER=x11
        fi

        W=1920
        H=1080
        if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
          focused_mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)' 2>/dev/null)
          if [ -n "$focused_mon" ]; then
            mon_w=$(echo "$focused_mon" | jq -r '.width' 2>/dev/null)
            mon_h=$(echo "$focused_mon" | jq -r '.height' 2>/dev/null)
            if [ -n "$mon_w" ] && [ "$mon_w" -ge 200 ] && [ -n "$mon_h" ] && [ "$mon_h" -ge 200 ]; then
              W=$mon_w
              H=$mon_h
            fi
          fi
        fi

        # Strip /f, -f, /fullscreen from arguments to prevent Wayland size-detection crash
        args=""
        has_size=0
        for arg in "$@"; do
          case "$arg" in
            /f|-f|/fullscreen)
              # Skip fullscreen flags
              ;;
            /size:*|-size:*|/w:*|/h:*)
              has_size=1
              args="$args \"$arg\""
              ;;
            *)
              args="$args \"$arg\""
              ;;
          esac
        done

        if [ $has_size -eq 0 ]; then
          eval exec ${pkgs.freerdp}/bin/sdl-freerdp "\"/size:''${W}x''${H}\"" $args
        else
          eval exec ${pkgs.freerdp}/bin/sdl-freerdp $args
        fi
        EOF
              chmod +x $out/bin/xfreerdp
      '';
    in
    winboat.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
      postInstall = (old.postInstall or "") + ''
        wrapProgram $out/bin/winboat \
          --prefix PATH : "${xfreerdp3Shim}/bin"
      '';
    })
  )
]
