{ pkgs ? import <nixpkgs> { } }:

pkgs.buildFHSEnv {
  name = "csd-env";

  targetPkgs = pkgs:
    with pkgs; [
      # Core
      glibc
      glib
      zlib
      bash

      # X11 / GUI
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXtst
      xorg.libXi
      xorg.libxcb

      # More X11 libs for Mercury
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXinerama

      # Missing lib in steam-run
      xorg.xcbutilwm # provides libxcb-icccm.so.4
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil

      # Common UI libs
      freetype
      fontconfig
      dbus
      gtk3
      cairo
      pango
      gdk-pixbuf
      alsa-lib
      nss

      nspr
      e2fsprogs

      # Missing deps
      libxkbcommon
      libglvnd
      mesa
      numactl
      zstd
    ];

  runScript = "bash";
}
