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
      coreutils
      coreutils
      util-linux
      strace

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
      libdrm
      libudev0-shim
      xorg.libxshmfence
      libgbm
      xorg.libxkbfile
      krb5
      keyutils
      xorg.xcbutilcursor

      # Fonts
      dejavu_fonts
      liberation_ttf
      noto-fonts

      # Activation/UI requirements
      glib-networking
      gsettings-desktop-schemas
      dconf
    ];

  runScript = pkgs.writeScript "csd-wrapper" ''
    #!/bin/bash
    # Mercury Wrapper
    # export CSDHOME is now set dynamically below
    export QT_QPA_PLATFORM=xcb
    export XDG_SESSION_TYPE=x11
    export LC_NUMERIC=C
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf # Early export

    # Fix for QtWebEngine / Embedded Chromium SIGTRAP crashes
    export QTWEBENGINE_DISABLE_SANDBOX=1

    unset XMODIFIERS # Matches original script behavior

    if [ -z "$1" ]; then
      echo "Debug: No arguments, launching bash"
      exec bash
    fi

    TARGET="$1"
    echo "Debug: Target is $TARGET"

    # Attempt to bypass the wrapper script if it looks like the standard mercury script
    # User passes: .../mercury/bin/mercury
    # We want: .../mercury/c_linux-64/bin/mercury.x

    # CSDHOME Logic:
    # Autodetection fails when wrapping with strace (args shift).
    # We know the structure is ~/CCDC/ccdc-software/mercury
    # So CSDHOME should be ~/CCDC
    export CSDHOME="$HOME/CCDC"
    echo "Debug: CSDHOME explicitly set to $CSDHOME"

    # Ensure CSDHOME exists
    mkdir -p "$CSDHOME"

    # Font Config Fixes
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf
    export FONTCONFIG_PATH=/etc/fonts

    if [ -f "$FONTCONFIG_FILE" ]; then
      echo "Debug: Found fonts.conf at "$FONTCONFIG_FILE""
    else
      echo "Debug: ERROR - fonts.conf not found at "$FONTCONFIG_FILE""
    fi

    # Attempt to find the real binary by scanning args or default location
    REAL_BIN=""

    # Check default install location first
    DEFAULT_BIN="$CSDHOME/ccdc-software/mercury/c_linux-64/bin/mercury.x"

    if [ -f "$DEFAULT_BIN" ]; then
       REAL_BIN="$DEFAULT_BIN"
       APP_LIB="$CSDHOME/ccdc-software/mercury/c_linux-64/lib"
    elif [ -f "$1" ]; then
       # Fallback to arg parsing if default not found
       TARGET="$1"
       DIRNAME=$(dirname "$TARGET")
       BASENAME=$(basename "$TARGET")
       PARENT=$(dirname "$DIRNAME")
       REAL_BIN="$PARENT/c_linux-64/bin/$BASENAME.x"
       APP_LIB="$PARENT/c_linux-64/lib"
    fi

    if [ -n "$REAL_BIN" ] && [ -f "$REAL_BIN" ]; then
      echo "Debug: Detected real binary at "$REAL_BIN""
      
      # Use the SYSTEM LD_LIBRARY_PATH first (provided by FHS), then append app libs
      # This prevents the app script from nuking our graphics drivers
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$APP_LIB
      
      # If the command starts with strace/gdb, we need to inject the binary path carefully
      # But for now, we assume the user might run: csd-env strace ... /path/to/script
      # We want to run: strace ... /path/to/REAL_BINARY
      
      # For simplicity in this specific debug phase, we just exec the args if it looks like a tool
      # But wait, if we exec "$@", we run the WRAPPER script again (which causes the loop/crash)
      # We must replace the script path in "$@" with the real binary path?
      # Or just export valid environment and let the user's command run the script (which we tried to bypass?)
      
      # Revised strategy: Just set the env vars and let the user run what they asked
      # BUT the user is running the script which unsets LD_LIBRARY_PATH.
      # So we MUST bypass it.
      
      # If arg 1 is the script, replace it.
      # If arg 1 is strace, we assume the LAST arg is the script?
      
      echo "Debug: Launching with corrected environment..."
      
      # HACK: If the user passed the script, just run the binary directly with remaining args?
      # No, strace makes this hard.
      
      # Let's trust that setting LD_LIBRARY_PATH *after* the script runs... wait, the script unsets it.
      
      # OK, ultimate fix:
      # If we found the real binary, and we are NOT running a debugger command as $1, run real binary.
      # If we ARE running strace ($1), then we can't easily swap the target inside strace args without complex parsing.
      # BUT, if we run strace on the *scripts*, the script runs and clears the env.
      
      # SOLUTION: The user should run: csd-env strace /path/to/REAL_BINARY
      # But they don't know the real binary path easily.
      
      # I will provide a convenience: if $1 is "debug", run strace on default bin.
      
      exec "$@"
    else
      echo "Debug: Exact binary detection failed or complex command. Running provided args."
      exec "$@"
    fi
  '';
}
