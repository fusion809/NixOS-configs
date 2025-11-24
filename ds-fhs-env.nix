{ pkgs ? import <nixpkgs> { } }:

pkgs.buildFHSEnv {
  name = "ds-fhs-env";

  # -----------------------------------------------------------------
  # Packages that will be present inside the sandbox
  # -----------------------------------------------------------------
  targetPkgs = pkgs:
    with pkgs; [
      # Core utilities
      glibc
      # Core utilities and libraries
      coreutils
      gawk
      gnugrep
      gnused
      findutils
      which
      file
      gdb

      # Shell
      bash

      # X11 & graphics libraries
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXtst
      xorg.libXi
      xorg.libXmu
      xorg.libXpm
      xorg.libXau
      xorg.libXdmcp
      xorg.libXfixes
      xorg.libXdamage
      xorg.libXinerama
      xorg.libXxf86vm
      xorg.libSM
      xorg.libICE
      xorg.libXrandr
      xorg.libXcursor
      xorg.libXcomposite
      xorg.libxcb
      xorg.xcbutil
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm

      # OpenGL and GPU acceleration
      libglvnd
      libGLU
      mesa
      libgbm
      libdrm
      qt5.qtbase # already present, but also add:
      qt5.qtx11extras
      # libglvnd-glx  # removed – not a separate package in nixpkgs
      xorg.libxshmfence
      xorg.libXrandr
      xorg.libXrender
      xorg.libXfixes

      # Basic libraries
      glib
      glibc
      zlib
      fontconfig
      freetype
      cairo
      expat
      dbus

      # Network libraries
      curl
      openssl

      # Additional libraries from your nix‑ld config
      alsa-lib
      audit
      libtiff
      e2fsprogs
      gd
      keyutils
      krb5
      libdrm
      libgcc
      bzip2
      libjpeg_turbo
      libnsl
      libpcap
      libpng
      libselinux
      libxcrypt-legacy # Added by instruction
      libsepol
      tcsh
      pam_krb5
      pam_p11
      libxcrypt-legacy # Added by instruction

      # **NEW – libxcrypt (provides libcrypt.so.1)**
      libxcrypt

      # Additional runtime dependencies
      stdenv.cc.cc.lib
      libxkbcommon
      nspr
      nss
      cups
      zstd
    ];

  # -----------------------------------------------------------------
  # Environment that will be sourced when you enter the sandbox
  # -----------------------------------------------------------------
  extraMounts = [{
    source = "/dev/dri";
    target = "/dev/dri";
    isReadOnly = false;
  }];

  profile = ''
    export LD_LIBRARY_PATH=$out/lib:$out/lib/libxcrypt-legacy:$HOME/BIOVIA/DiscoveryStudio2025/lib:/usr/lib:/usr/lib64:$LD_LIBRARY_PATH
    export QT_QPA_PLATFORM_PLUGIN_PATH=$out/lib/qt5/plugins
    export QT_PLUGIN_PATH=$out/lib/qt5/plugins
    # Force X11 backend (more stable for proprietary apps)
    export QT_QPA_PLATFORM=xcb
    export XDG_SESSION_TYPE=x11
    # Fallback to software rendering if GPU access fails
    export LIBGL_ALWAYS_SOFTWARE=1

    # Discovery Studio helpers
    export BIOVIA_HOME=$HOME/BIOVIA/DiscoveryStudio2025
    export BIOVIA_LIC_PACK_DIR=$HOME/BIOVIA/BIOVIA_LicensePack
  '';

  # -----------------------------------------------------------------
  # Create /bin/csh symlink (needed by the license scripts)
  # -----------------------------------------------------------------
  extraInstallCommands = ''
    ln -sf ${pkgs.tcsh}/bin/tcsh $out/bin/csh
  '';
}
