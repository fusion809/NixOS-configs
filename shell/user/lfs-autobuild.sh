#!/usr/bin/env bash
# Automate LFS/BLFS package building by scraping official books (Development/SVN)

# Ensure NIXCFG is set
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 0. Global Setup: Better as_root that handles redirections
as_root() {
  if [ ${EUID:-$(id -u)} = 0 ]; then
    "$@"
  else
    local cmd="$*"
    # If the command contains redirections or pipes, wrap it in bash -c
    if [[ "$cmd" == *">"* ]] || [[ "$cmd" == *"<<"* ]] || [[ "$cmd" == *"|"* ]]; then
      if command -v sudo >/dev/null 2>&1; then
        sudo bash -c "$cmd"
      else
        su -c "$cmd"
      fi
    else
      if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
      else
        su -c "$cmd"
      fi
    fi
  fi
}
export -f as_root

# Source SSH helpers if available (only on host)
HOST_MODE=false
if [ -f "$NIXCFG/shell/user/08-ssh.sh" ]; then
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    HOST_MODE=true
else
    # Running inside the VM (piped via bash -s from host or uploaded).
    # ssh_lfs is a no-op passthrough: just run the command locally.
    ssh_lfs() {
        local cmd="$1"
        shift
        case "$cmd" in
            "bash -s")
                # stdin-redirect form: ssh_lfs "bash -s" < script
                bash -s "$@"
                ;;
            *)
                # eval form: ssh_lfs "cmd args"
                eval "$cmd" "$@"
                ;;
        esac
    }
fi

LFS_BOOK_DEFAULT="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_BOOK_DEFAULT="https://linuxfromscratch.org/blfs/view/systemd"
LFS_BOOK="$LFS_BOOK_DEFAULT"
BLFS_BOOK="$BLFS_BOOK_DEFAULT"

# 0.5 Ensure non-interactive builds for Perl and other tools
export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"

DRY_RUN=false
STRIP=false
UPSTREAM=true
INCLUDE_CONFIG=false
RM_LIBS=false
SEARCH_LFS=true
SEARCH_BLFS=true
PACKAGES=()
XORG_MULTI_MODE=false
FORCE=false
YES=false
SKIP_TESTS=false
IGNORE_TEST_FAILURES=false

usage() {
    echo "Usage: autobuild [options] <package-name> [package-name-2...]"
    echo "Options:"
    echo "  --dry-run             Show commands without executing them"
    echo "  --strip               Run stripping commands after build"
    echo "  --no-upstream         Disable upstream version searching [DEFAULT is to track upstream]"
    echo "  --include-config      Include configuration commands in the LFS/BLFS book entry"
    echo "  --rm-libs             Remove old library versions after build (disabled by default)"
    echo "  --lfs                 Search only in the LFS book"
    echo "  --blfs                Search only in the BLFS book"
    echo "  --lfs-book <book>     Specify LFS book (e.g., development, systemd, stable, or full URL)"
    echo "  --blfs-book <book>    Specify BLFS book (e.g., systemd, development, stable, or full URL)"
    echo "  --skip-tests          Skip test commands (make check/test, etc.)"
    echo "  --ignore-test-failures Ignore test failures by appending '|| true' to test commands"
    echo "  -f, --force           Force build even if already installed"
    echo "  -h, --help            Show this help message"
    echo "$COMMANDS" > /tmp/cmds_final.out
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --strip) STRIP=true ;;
        --no-upstream) UPSTREAM=false ;;
        --upstream) UPSTREAM=true ;; # Hidden compatibility flag
        --include-config) INCLUDE_CONFIG=true ;;
        --rm-libs) RM_LIBS=true ;;
        --lfs)
            SEARCH_LFS=true
            SEARCH_BLFS=false
            ;;
        --blfs)
            SEARCH_LFS=false
            SEARCH_BLFS=true
            ;;
        --lfs-book)
            LFS_BOOK="$2"
            shift
            SEARCH_LFS=true
            SEARCH_BLFS=false
            # Handle shorthand names
            if [[ ! "$LFS_BOOK" =~ ^https?:// ]]; then
                LFS_BOOK="https://www.linuxfromscratch.org/lfs/view/$LFS_BOOK"
            fi
            ;;
        --blfs-book)
            BLFS_BOOK="$2"
            shift
            SEARCH_LFS=false
            SEARCH_BLFS=true
            # Handle shorthand names
            if [[ ! "$BLFS_BOOK" =~ ^https?:// ]]; then
                BLFS_BOOK="https://www.linuxfromscratch.org/blfs/view/$BLFS_BOOK"
            fi
            ;;
        --skip-tests) SKIP_TESTS=true ;;
        --ignore-test-failures) IGNORE_TEST_FAILURES=true ;;
        -f|--force) FORCE=true ;;
        -y|--yes) YES=true ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) PACKAGES+=("$1") ;;
    esac
    shift
done

# Define a target runner that works locally or via SSH
target_run() {
    if [[ "$HOST_MODE" == "true" ]]; then
        ssh_lfs "$@"
    else
        bash -c "$@"
    fi
}

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    usage
    exit 1
fi

log() { echo "[$(date +'%H:%M:%S')] $*"; }

# Synchronize clock to prevent build errors from time skew
if [[ "$DRY_RUN" == "false" ]]; then
    if [[ "$HOST_MODE" == "true" ]]; then
        log "Synchronizing LFS guest clock to host..."
        ssh_lfs "sudo date -s '@$(date +%s)'" >/dev/null 2>&1
    else
        log "Synchronizing LFS clock from hardware clock..."
        as_root hwclock -s >/dev/null 2>&1
    fi
fi
error() { echo "[ERROR] $*" >&2; echo "$COMMANDS" > /tmp/cmds_final.out; exit 1; }

# Guard against circular dependencies across recursive invocations
BUILDING_STACK="${BUILDING_STACK:-}"

# Save initial state of variables that might be modified per-package
INITIAL_UPSTREAM="$UPSTREAM"

# Loop over all requested packages
for PACKAGE in "${PACKAGES[@]}"; do
    if [[ ":${BUILDING_STACK}:" == *":${PACKAGE}:"* ]]; then
        log "Skipping '$PACKAGE': already in build stack (circular dependency guard)."
        continue
    fi
    # Reset per-package variables to prevent leakage between packages in the same loop
    unset DOWNLOAD_URLS
    declare -a DOWNLOAD_URLS=()
    ALL_FILENAMES=()
    MAIN_DOWNLOAD_URL=""
    MAIN_FILENAME=""
    DIRNAME=""
    GEN_DIRNAME=""
    LFS_VERSION=""
    UPSTREAM_VERSION=""
    UPSTREAM_FULL=""
    UPSTREAM_MM=""
    LFS_MM=""
    COMMANDS=""
    HTML_CONTENT=""
    FULL_HTML_CONTENT=""
    PAGE_URL=""
    METAPACKAGE_TARGET=""
    XORG_MULTI_MODE=false
    FRAMEWORKS_MODE=false
    PLASMA_MODE=false
    UPSTREAM="$INITIAL_UPSTREAM"
    
    export BUILDING_STACK="${BUILDING_STACK:+${BUILDING_STACK}:}${PACKAGE}"

    # Translate friendly aliases to canonical upstream names used in archives/loops
    case "$PACKAGE" in
        xorg-libinput)   PACKAGE="xf86-input-libinput" ;;
        xorg-evdev)      PACKAGE="xf86-input-evdev" ;;
        xorg-synaptics)  PACKAGE="xf86-input-synaptics" ;;
        xorg-vmmouse)    PACKAGE="xf86-input-vmmouse" ;;
        xorg-vmware)     PACKAGE="xf86-video-vmware" ;;
        xorg-fbdev)      PACKAGE="xf86-video-fbdev" ;;
        xorg-vesa)       PACKAGE="xf86-video-vesa" ;;
        xorg-intel)      PACKAGE="xf86-video-intel" ;;
        xorg-amdgpu)     PACKAGE="xf86-video-amdgpu" ;;
        xorg-nouveau)    PACKAGE="xf86-video-nouveau" ;;
        attica|kapidox|karchive|kcodecs|kconfig|kcoreaddons|kdbusaddons|kdnssd|kguiaddons|ki18n|kidletime|kimageformats|kitemmodels|kitemviews|kplotting|kwidgetsaddons|kwindowsystem|networkmanager-qt|solid|sonnet|threadweaver|kauth|kcompletion|kcrash|kdoctools|kpty|kunitconversion|kcolorscheme|kconfigwidgets|kservice|kglobalaccel|kpackage|kdesu|kiconthemes|knotifications|kjobwidgets|ktextwidgets|kxmlgui|kbookmarks|kwallet|kded|kio|kdeclarative|kirigami|kcmutils|syndication|knewstuff|frameworkintegration|kparts|syntax-highlighting|ktexteditor|modemmanager-qt|kcontacts|kpeople|bluez-qt|kfilemetadata|baloo|krunner|prison|qqc2-desktop-style|kholidays|purpose|kcalendarcore|kquickcharts|knotifyconfig|kdav|kstatusnotifieritem|ksvg|ktexttemplate|kuserfeedback)
            METAPACKAGE_TARGET="$PACKAGE"
            PACKAGE="frameworks6"
            log "Redirecting '$METAPACKAGE_TARGET' to frameworks6 bundle (single-component build)."
            ;;
        xdg-desktop-portal-kde) PACKAGE="plasma-all" ;;
        # Plasma sub-packages: build only the named component from the plasma-all loop
        libksysguard|kwin|kscreenlocker|kwayland|kpipewire|\
        kinfocenter|ksystemstats|plasma-workspace|plasma-desktop|\
        plasma-nm|plasma-pa|plasma-sdk|plasma-thunderbolt|\
        plasma-disks|powerdevil|bluedevil|drkonqi|kscreen|\
        breeze|breeze-gtk|kdeplasma-addons|sddm-kcm|\
        plasma-systemmonitor|plasma-firewall|ksshaskpass|\
        plasma-vault|plasma-pass|oxygen|plasma-browser-integration|\
        milou|kde-cli-tools|kactivitymanagerd|ktexteditor|\
        layer-shell-qt|plasma-activities|plasma-activities-stats|\
        kde-gtk-config)
            METAPACKAGE_TARGET="$PACKAGE"
            PACKAGE="plasma-all"
            log "Redirecting '$METAPACKAGE_TARGET' to plasma-all bundle (single-component build)."
            ;;
        glib)                    PACKAGE="glib2" ;;
        # Xorg apps, libs, and fonts sub-packages
        libX11|libXext|libXrender|libXft|libXi|libXau|libXdmcp|libxcb|xcb-util*)
            METAPACKAGE_TARGET="$PACKAGE"
            PACKAGE="xorg-lib"
            log "Redirecting '$METAPACKAGE_TARGET' to xorg-lib bundle (single-component build)."
            ;;
        xterm|xclock|xinit|xauth|iceauth|sessreg|setxkbmap|xauth|xbacklight|xcmsdb|xcursorgen|xdpyinfo|xdriinfo|xev|xgamma|xhost|xinput|xkbcomp|xkbevd|xkbutils|xkill|xlsatoms|xlsclients|xmodmap|xpr|xprop|xrandr|xrdb|xrefresh|xset|xsetroot|xvinfo|xwd|xwininfo|xwud)
            METAPACKAGE_TARGET="$PACKAGE"
            PACKAGE="xorg-app"
            log "Redirecting '$METAPACKAGE_TARGET' to xorg-app bundle (single-component build)."
            ;;
        font-*)
            METAPACKAGE_TARGET="$PACKAGE"
            PACKAGE="xorg-font"
            log "Redirecting '$METAPACKAGE_TARGET' to xorg-font bundle (single-component build)."
            ;;
    esac

    # 0. Check for custom package in ~/lfs_packaging
CUSTOM_BUILD_SH=$(target_run "find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name build.sh 2>/dev/null | xargs grep -il -E \"^[a-zA-Z_]*name=['\\\"']?${PACKAGE}['\\\"']?\\$\" 2>/dev/null | head -n 1" 2>/dev/null | grep -vE "^(Warning:|Connection|IP|SSH|grep:)" | tr -d '\r')
if [[ -z "$CUSTOM_BUILD_SH" ]]; then
    CUSTOM_BUILD_SH=$(target_run "find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name build.sh 2>/dev/null | grep -E \"/$PACKAGE/build.sh$\" | head -n 1" 2>/dev/null | grep -vE "^(Warning:|Connection|IP|SSH|grep:)" | tr -d '\r')
fi
if [[ -n "$CUSTOM_BUILD_SH" ]]; then
    CUSTOM_DIR=$(dirname "$CUSTOM_BUILD_SH")
    log "Custom package detected at $CUSTOM_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY RUN: Would execute $CUSTOM_BUILD_SH on VM."
        continue
    fi
    
    log "Starting remote custom build for $PACKAGE..."
    
    REMOTE_SCRIPT=$(cat <<'EOF'
set -eo pipefail
cd "$CUSTOM_DIR"
# Create timestamp BEFORE build
touch "/tmp/build_start_timestamp_${TARGET_PKG}"
BUILD_LOG="/tmp/build_log_${TARGET_PKG}.txt"
bash build.sh 2>&1 | tee "$BUILD_LOG"

# Update registry (needs sudo)
sudo mkdir -p /var/lib/custom-packages
# Determine the new version we just installed
new_ver=""
version_line_num=$(grep -niE '^[a-z_]*version=' build.sh | head -n 1 | cut -d: -f1 || true)
if [ -n "$version_line_num" ]; then
    eval_script="/tmp/eval_ver_${TARGET_PKG}.sh"
    echo 'set +e' > "$eval_script"
    echo 'export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> "$eval_script"
    head -n "$version_line_num" build.sh | tr -d '\r' >> "$eval_script"
    var_name=$(grep -iE '^[a-z_]*version=' build.sh | head -n 1 | cut -d= -f1 || true)
    echo "echo \"\$$var_name\"" >> "$eval_script"
    new_ver=$(bash "$eval_script" 2>/dev/null | tail -n 1 | tr -d '\r\n[:space:]')
    rm -f "$eval_script"
fi

if [ -z "$new_ver" ]; then
    # Auto-detect if there's a sub-directory with a git clone
    subdirs=($(find . -maxdepth 1 -mindepth 1 -type d ! -name ".*"))
    for dir in "${subdirs[@]}"; do
        if [ -d "$dir/.git" ]; then
            cd "$dir"
            new_ver=$(git rev-parse HEAD 2>/dev/null)
            cd ..
            break
        fi
    done
fi

if [ -z "$new_ver" ] && grep -q "git clone" build.sh; then
    repo_url=$(perl -nle 'while (m{git clone \K[^ ]+}g) { print $& }' build.sh | head -n 1)
    if [ -n "$repo_url" ]; then
        new_ver=$(git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}' || true)
    fi
fi

if [ -n "$new_ver" ]; then
    if [ $(wc -l < /var/lib/custom-packages/"$TARGET_PKG" 2>/dev/null || echo 0) -gt 1 ]; then
        sudo sed -i "1s/.*/$new_ver/" /var/lib/custom-packages/"$TARGET_PKG"
    else
        echo "$new_ver" | sudo tee /var/lib/custom-packages/"$TARGET_PKG" > /dev/null
    fi
    echo "Updated registry for $TARGET_PKG to version $new_ver"
else
    echo "Could not determine version for $TARGET_PKG to update registry"
fi

# Record file list for custom package
if [ -f "/tmp/build_start_timestamp_${TARGET_PKG}" ]; then
    SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt /boot"
    EXISTING_DIRS=""
    for d in $SEARCH_DIRS; do [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"; done
    find $EXISTING_DIRS -xdev -newer "/tmp/build_start_timestamp_${TARGET_PKG}" 2>/dev/null | sudo tee -a "/var/lib/custom-packages/${TARGET_PKG}" > /dev/null || true
    
    # 2. Capture via build log (CMake/Meson files that are already up-to-date)
    if [ -f "$BUILD_LOG" ]; then
        echo "Parsing build log for additional files (Up-to-date/Installing)..."
        # Parse CMake: -- Installing: /path OR -- Up-to-date: /path
        grep -E "^-- (Installing|Up-to-date): " "$BUILD_LOG" | sed -E 's@^-- (Installing|Up-to-date): @@; s@^.*(/usr/|/bin/|/sbin/|/lib/|/lib64/|/etc/|/opt/)@\1@' | sudo tee -a "/var/lib/custom-packages/${TARGET_PKG}" > /dev/null || true
        # Parse Meson: Installing <src> to <dst>
        grep -E "^Installing .* to /" "$BUILD_LOG" | sed -E 's@^Installing .* to (.*)$@\1@; s@^.*(/usr/|/bin/|/sbin/|/lib/|/lib64/|/etc/|/opt/)@\1@' | sudo tee -a "/var/lib/custom-packages/${TARGET_PKG}" > /dev/null || true
        rm -f "$BUILD_LOG"
    fi

    sudo awk '!seen[$0]++' "/var/lib/custom-packages/${TARGET_PKG}" > "/tmp/dedup_${TARGET_PKG}"
    sudo mv "/tmp/dedup_${TARGET_PKG}" "/var/lib/custom-packages/${TARGET_PKG}"
    sudo chmod 755 "/var/lib/custom-packages/${TARGET_PKG}"
    echo "Recorded installed files for custom package $TARGET_PKG in /var/lib/custom-packages/"
    sudo rm -f "/tmp/build_start_timestamp_${TARGET_PKG}"
fi
EOF
)
    # Skip logic for custom packages: evaluate version on VM before building
    if [[ "$FORCE" != "true" ]]; then
        INSTALLED_VER=$(target_run "[ -f /var/lib/custom-packages/$PACKAGE ] && head -n 1 /var/lib/custom-packages/$PACKAGE" 2>/dev/null | tr -d '\r\n[:space:]')
        
        # Determine target version from build script
        TARGET_VER=""
        EVAL_SCRIPT=$(cat <<EOF
pkg_dir="$CUSTOM_DIR"
build_script="$CUSTOM_BUILD_SH"
version_line_num=\$(grep -niE '^[a-z_]*version=' "\$build_script" | head -n 1 | cut -d: -f1)
var_name=\$(grep -iE '^[a-z_]*version=' "\$build_script" | head -n 1 | cut -d= -f1)
if [ -n "\$version_line_num" ]; then
    tmp_eval="/tmp/eval_autobuild_ver_\$\$.sh"
    echo 'set +e' > "\$tmp_eval"
    echo 'export PATH=/opt/texlive/2025/bin/x86_64-linux:$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> "$tmp_eval"
    head -n "\$version_line_num" "\$build_script" | tr -d '\r' >> "\$tmp_eval"
    echo "echo \"\\$\$var_name\"" >> "\$tmp_eval"
    cd "\$pkg_dir" && bash "\$tmp_eval" 2>/dev/null | tail -n 1 | tr -d '\r\n[:space:]'
    rm -f "\$tmp_eval"
fi
EOF
)
        TARGET_VER=$(printf "%s" "$EVAL_SCRIPT" | target_run "bash -s" 2>/dev/null | tail -n 1)

        if [[ -n "$INSTALLED_VER" && -n "$TARGET_VER" ]]; then
            if [[ "$INSTALLED_VER" == "$TARGET_VER" ]]; then
                log "[LFS-AUTOBUILD] Skipping custom package $PACKAGE: version $INSTALLED_VER already installed (use -f to force build)."
                continue
            fi
        fi
    fi

    ssh_lfs "TARGET_PKG=\"$PACKAGE\" CUSTOM_DIR=\"$CUSTOM_DIR\" bash -s" <<EOF
$(echo "$REMOTE_SCRIPT")
EOF
    build_exit_code=$?
    if [ $build_exit_code -ne 0 ]; then
        echo "[ERROR] Custom build failed for $PACKAGE"
        exit $build_exit_code
    fi


    
    if [[ "$STRIP" == "true" ]]; then
        if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
            source "$NIXCFG/shell/user/21-lfs.sh"
            lfs_strip
        else
            echo "Warning: STRIP skipped because 21-lfs.sh is not available locally."
        fi
    fi

    continue
fi

log "[LFS-AUTOBUILD] Script initialization complete. Version 2026.04.02.1"

# 1. Discover package page
find_package_page() {
    local pkg="$1"
    local found=""

    if [[ "$SEARCH_LFS" == "true" ]]; then
        if [[ "$pkg" == "linux" ]]; then
            echo "$LFS_BOOK/chapter10/kernel.html"
            return 0
        fi
        if [[ "$pkg" == "tzdata" ]]; then
            echo "$LFS_BOOK/chapter08/glibc.html"
            return 0
        fi

        local lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"((?:[^\"]*\/)?\Q$pkg\E(?:-(?:[0-9]|\$|patch)|(?:\.html))[^\"]*)\"/is) { print \$1; exit }")
        
        # Fallback to strict start match (e.g. zip vs zip-3.0)
        if [[ -z "$lfs_page" ]]; then
            lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"((?:[^\"]*\/)?\Q$pkg\E[0-9-][^\"]*\.html)\"/is) { print \$1; exit }")
        fi
        
        if [[ -n "$lfs_page" ]]; then
            echo "$LFS_BOOK/chapter08/$lfs_page"
            return 0
        fi
    fi

    if [[ "$SEARCH_BLFS" == "true" ]]; then
        case "$pkg" in
            xorg-lib|x7lib|xtrans|libICE|libSM|libX11|libXext|libXrender|libXft|libXi|libXinerama|libXrandr|libXcursor|libXcomposite|libXdamage|libXfixes|libXfont2|libXmu|libXpm|libXt|libXtst|libXv|libXvMC|libXxf86vm|libxkbfile|libFS|libXScrnSaver|libXaw|libXres|libXxf86dga|libpciaccess|libxshmfence|libXpresent|libfontenc)
                                  echo "$BLFS_BOOK/x/x7lib.html"; return 0 ;;
            xorg-app|x7app) echo "$BLFS_BOOK/x/x7app.html"; return 0 ;;
            iceauth|sessreg|setxkbmap|smproxy|xauth|xbacklight|xcmsdb|xcursorgen|xdpyinfo|xdriinfo|xev|xgamma|xhost|xinput|xkbcomp|xkbevd|xkbutils|xkill|xlsatoms|xlsclients|xmodmap|xpr|xprop|xrandr|xrdb|xrefresh|xset|xsetroot|xvinfo|xwd|xwininfo|xwud)
                                  echo "$BLFS_BOOK/x/x7app.html#xorg-app"; return 0 ;;
            xorg-font|x7font)     echo "$BLFS_BOOK/x/x7font.html"; return 0 ;;
            font-*)               echo "$BLFS_BOOK/x/x7font.html"; return 0 ;;
            xorg-driver|x7driver) echo "$BLFS_BOOK/x/x7driver.html"; return 0 ;;
            xorg-libinput|xf86-input-libinput) echo "$BLFS_BOOK/x/x7driver.html#xorg7-libinput-driver"; return 0 ;;
            xorg-evdev-driver|xf86-input-evdev) echo "$BLFS_BOOK/x/x7driver.html#xorg7-evdev-driver"; return 0 ;;
            xf86-input-synaptics) echo "$BLFS_BOOK/x/x7driver.html#xorg7-synaptics-driver"; return 0 ;;
            xf86-input-vmmouse)   echo "$BLFS_BOOK/x/x7driver.html#xorg7-vmmouse-driver"; return 0 ;;
            xf86-video-*)         echo "$BLFS_BOOK/x/x7driver.html#xorg7-video-drivers"; return 0 ;;
            sdl2-compat) echo "$BLFS_BOOK/multimedia/sdl2.html"; return 0 ;;
        esac

        log "Searching for '$pkg' in BLFS index..." >&2

        local search_pkg="$pkg"
        if [[ "$pkg" =~ ^gst-plugins-(base|good|bad|ugly|libav|vaapi)$ ]]; then
            search_pkg="gst10-plugins-${BASH_REMATCH[1]}"
        elif [[ "$pkg" == "rustc" ]]; then
            search_pkg="rust"
        elif [[ "$pkg" == "pygobject" ]]; then
            search_pkg="pygobject3"
        elif [[ "$pkg" == "plasma-disks" ]]; then
            search_pkg="kinfocenter" # plasma-disks is part of kinfocenter
        elif [[ "$pkg" == "plasma-pa" ]]; then
            search_pkg="plasma-pa"
        elif [[ "$pkg" == "print-manager" ]]; then
            search_pkg="print-manager"
        elif [[ "$pkg" == "kgamma" ]]; then
            search_pkg="kgamma5"
        elif [[ "$pkg" == "kquickimageditor" ]]; then
            search_pkg="kquickimageeditor"
        elif [[ "$pkg" == "kcolorpicker" ]]; then
            search_pkg="kColorPicker"
        elif [[ "$pkg" == "ocean-sound-theme" ]]; then
            search_pkg="ocean-sound-theme"
        elif [[ "$pkg" == "plymouth-kcm" ]]; then
            search_pkg="plymouth-kcm"
        elif [[ "$pkg" == "kdenlive" ]]; then
            search_pkg="kdenlive"
        elif [[ "$pkg" == "kdevelop" ]]; then
            search_pkg="kdevelop"
        elif [[ "$pkg" == "kmail" ]]; then
            search_pkg="kmail"
        elif [[ "$pkg" == "korganizer" ]]; then
            search_pkg="korganizer"
        elif [[ "$pkg" == "knotes" ]]; then
            search_pkg="knotes"
        elif [[ "$pkg" == "kontact" ]]; then
            search_pkg="kontact"
        elif [[ "$pkg" == "kaddressbook" ]]; then
            search_pkg="kaddressbook"
        elif [[ "$pkg" == "akonadi" ]]; then
            search_pkg="akonadi"
        elif [[ "$pkg" == "akonadi-calendar" ]]; then
            search_pkg="akonadi-calendar"
        elif [[ "$pkg" == "akonadi-contacts" ]]; then
            search_pkg="akonadi-contacts"
        elif [[ "$pkg" == "akonadi-mime" ]]; then
            search_pkg="akonadi-mime"
        elif [[ "$pkg" == "akonadi-notes" ]]; then
            search_pkg="akonadi-notes"
        elif [[ "$pkg" == "akonadi-search" ]]; then
            search_pkg="akonadi-search"
        elif [[ "$pkg" == "calendarsupport" ]]; then
            search_pkg="calendarsupport"
        elif [[ "$pkg" == "eventviews" ]]; then
            search_pkg="eventviews"
        elif [[ "$pkg" == "incidenceeditor" ]]; then
            search_pkg="incidenceeditor"
        elif [[ "$pkg" == "kcalendarcore" ]]; then
            search_pkg="kcalendarcore"
        elif [[ "$pkg" == "kcontacts" ]]; then
            search_pkg="kcontacts"
        elif [[ "$pkg" == "kholidays" ]]; then
            search_pkg="kholidays"
        elif [[ "$pkg" == "kidentitymanagement" ]]; then
            search_pkg="kidentitymanagement"
        elif [[ "$pkg" == "kmailtransport" ]]; then
            search_pkg="kmailtransport"
        elif [[ "$pkg" == "knotes" ]]; then
            search_pkg="knotes"
        elif [[ "$pkg" == "kparts" ]]; then
            search_pkg="kparts"
        elif [[ "$pkg" == "libkdepim" ]]; then
            search_pkg="libkdepim"
        elif [[ "$pkg" == "mailcommon" ]]; then
            search_pkg="mailcommon"
        elif [[ "$pkg" == "mailimporter" ]]; then
            search_pkg="mailimporter"
        elif [[ "$pkg" == "messagelist" ]]; then
            search_pkg="messagelist"
        elif [[ "$pkg" == "pimcommon" ]]; then
            search_pkg="pimcommon"
        elif [[ "$pkg" == "pimtextedit" ]]; then
            search_pkg="pimtextedit"
        elif [[ "$pkg" == "templateparser" ]]; then
            search_pkg="templateparser"
        elif [[ "$pkg" == "kdepim-runtime" ]]; then
            search_pkg="kdepim-runtime"
        elif [[ "$pkg" == "libjpeg-turbo" ]]; then
            search_pkg="libjpeg"
        fi

        # First try match for pkg.html (with optional fragment)
        local blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"((?:[^\"]*\/)?\Q$search_pkg\E(?:\.html|-[0-9])[^\"]*(?:#[^\"]*)?)\"/is) { print \$1; exit }")
        
        # Second try: match fragment directly (if search_pkg is used as a fragment)
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]+\.html#\Q$search_pkg\E)\"/is) { print \$1; exit }")
        fi

        # NEW: Try exact match in anchor text first to avoid fuzzy matches (vlc vs phonon-backend-vlc)
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/<a\s+[^>]*href=\"([^\"]+)\"[^>]*>\s*\Q$search_pkg\E\s*<\/a>/is) { print \$1; exit }")
        fi

        # Fallback to match at start of filename (strict)
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"((?:[^\"]*\/)?\Q$search_pkg\E[0-9-][^\"]*\.html(?:#[^\"]*)?)\"/is) { print \$1; exit }")
        fi

        # Fourth try: match package name in the anchor text (the visible link text)
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/<a\s+[^>]*href=\"([^\"]+)\"[^>]*>\s*\Q$search_pkg\E(?:-|\$|\s|<)/is) { print \$1; exit }")
        fi
        
        if [[ -n "$blfs_page" ]]; then
            # BLFS links might be relative or absolute-ish depending on where they are
            if [[ "$blfs_page" == ..* ]]; then
                # Handle relative links like ../general/python3.html
                echo "$BLFS_BOOK/${blfs_page#../}"
            else
                echo "$BLFS_BOOK/$blfs_page"
            fi
            return 0
        fi
    fi

    return 1
}

SKIP_HTML_EXTRACTION=false
if [[ "$PACKAGE" == "openjdk" ]]; then
    log "Special case for OpenJDK: Fetching the latest JDK release from jdk.java.net..."
    JDK_MAJOR=$(curl -s https://jdk.java.net/ | perl -nle 'while (m{href=\x22\./\K[0-9]+}g) { print $& }' | sort -rn | head -n 1)
    if [[ -z "$JDK_MAJOR" ]]; then
        error "Could not determine latest JDK major version."
    fi
    JDK_TARBALL=$(curl -s "https://jdk.java.net/${JDK_MAJOR}/" | perl -nle 'while (m{https://download.java.net/java/.*?/openjdk-[0-9]+.*?_linux-x64_bin\.tar\.gz}g) { print $& }' | head -n 1)
    if [[ -z "$JDK_TARBALL" ]]; then
        error "Could not determine latest JDK tarball URL."
    fi
    DOWNLOAD_URLS=("$JDK_TARBALL")
    PKG_BASE="openjdk"
    MAIN_DOWNLOAD_URL="$JDK_TARBALL"
    SKIP_HTML_EXTRACTION=true

    COMMANDS="
install -vdm755 /opt/jdk
rm -rf /opt/jdk/*
cp -Rv * /opt/jdk/
chown -R root:root /opt/jdk
cat > /etc/profile.d/java.sh << \"EOF\"
export JAVA_HOME=/opt/jdk
export PATH=\\\$PATH:\\\$JAVA_HOME/bin
EOF
"
fi

SETUP_COMMANDS=""

if [[ "$SKIP_HTML_EXTRACTION" == "false" ]]; then
# 1. Discover package page
PAGE_URL=$(find_package_page "$PACKAGE")

# 2. If it's a known metapackage component or if no individual page was found, search metapackages
if [[ -z "$PAGE_URL" ]] || [[ "$PACKAGE" =~ ^(xorg|x7|libX|libx|font-|xf86-input-|xf86-video-) ]]; then
    log "Searching prominent metapackages for component '$PACKAGE'..."
    for mp_page in "kde/frameworks6.html" "kde/plasma-all.html" "x/x7app.html" "x/x7lib.html" "x/x7font.html"; do
        # Avoid misidentifying core packages that are just dependencies
        if [[ "$PACKAGE" =~ ^(wayland|mesa|libglvnd|libdrm|vulkan-loader|libxkbcommon|systemd|dbus|glib2?|perl|python|jinja2|markupsafe|ninja|meson|cmake)$ ]]; then
            continue
        fi

        # Fetch metapackage content to verify if PACKAGE is actually a component (listed in md5 block)
        mp_html=$(curl -s "$BLFS_BOOK/$mp_page")
        if echo "$mp_html" | grep -iqE "[a-fA-F0-9]{32}[[:space:]]+${PACKAGE}[-_][0-9].*\.tar"; then
            PAGE_URL="$BLFS_BOOK/$mp_page"
            METAPACKAGE_TARGET=$(basename "$mp_page" .html)
            SINGLE_COMPONENT_MODE="$PACKAGE"
            log "Found component '$PACKAGE' securely nested within metapackage: $METAPACKAGE_TARGET"
            break
        fi
        
        # Fallback for Xorg where sometimes names are simplified
        if [[ "$mp_page" =~ "x7" ]] && echo "$mp_html" | grep -iqE "href=\"${PACKAGE}\.html\""; then
            PAGE_URL="$BLFS_BOOK/$mp_page"
            METAPACKAGE_TARGET=$(basename "$mp_page" .html)
            SINGLE_COMPONENT_MODE="$PACKAGE"
            log "Found component '$PACKAGE' in Xorg metapackage: $METAPACKAGE_TARGET"
            break
        fi
    done
fi

if [[ -z "$PAGE_URL" ]]; then
    error "Could not find page for package '$PACKAGE'"
fi

if [[ -z "$PAGE_URL" ]]; then
    error "Could not find page for package '$PACKAGE'"
fi

log "Found package page: $PAGE_URL"

if [[ "$PACKAGE" =~ ^(xorg|x7)-(lib|app|font)$ ]] || \
   [[ "$PAGE_URL" =~ x7(lib|app|font)\.html$ ]] || \
   [[ "$METAPACKAGE_TARGET" =~ ^x7(lib|app|font)$ ]]; then
    XORG_MULTI_MODE=true
    log "Enabling Xorg multi-package mode."
elif [[ "$PACKAGE" =~ ^(xorg|x7)-driver$ ]]; then
    # Drivers are NOT in a loop, they have individual sections. 
    # Only enable multi-mode for the bulk alias if the logic supports it, 
    # but currently x7driver.html is better handled as individual packages.
    XORG_MULTI_MODE=false
elif [[ "$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true" ]]; then
    # Enable multi-mode for KDE to allow isolating single components from the bulk loop
    XORG_MULTI_MODE=true
    log "Enabling KDE multi-package isolation mode."
fi

# 2. Extract Download URL and Build Commands
log "Fetching content from $PAGE_URL..."
HTML_CONTENT=$(curl -s "$PAGE_URL")
FULL_HTML_CONTENT="$HTML_CONTENT"

if [[ -z "$HTML_CONTENT" ]]; then
    error "Empty content from $PAGE_URL"
fi

# 2.1 Help extraction by slicing HTML if URL has a fragment (e.g. #pygobject3)
FRAG=$(echo "$PAGE_URL" | grep -o "#.*$")
if [[ -n "$FRAG" ]]; then
    FRAG_ID=${FRAG#\#}
    log "Slicing HTML content for fragment: $FRAG_ID"
    # Extract starting from the anchor or container with the id $FRAG_ID up to the next sect/header
    HTML_CONTENT=$(printf '%s' "$HTML_CONTENT" | perl -0777 -nse '
        if (/(<(?:a|div|h[1-6]|section|p|li)\s+[^>]*?\b(?:id|name)="\Q$id\E"[^>]*>.*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$id\E)[^"]+")/is) {
            print $1;
        } elsif (/(id="\Q$id\E".*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$id\E)[^"]+")/is) {
            print $1;
        } elsif (/(<(?:a|div|h[1-6]|section|p|li)\s+[^>]*?\b(?:id|name)="\Q$id\E"[^>]*>.*)/is) {
            print $1;
        } elsif (/(id="\Q$id\E".*)/is) {
            print $1;
        } else {
            print $_;
        }' -- -id="$FRAG_ID")
    if [[ -z "$HTML_CONTENT" ]]; then
         log "Fallback: Fragment $FRAG_ID not found in slice, using full content."
         HTML_CONTENT="$FULL_HTML_CONTENT"
    fi
fi

# 2.2 Resolve and build required dependencies before this package
if [[ "${RESOLVE_DEPS:-true}" != "false" ]]; then
    log "Extracting required dependencies from page..."
    REQUIRED_DEPS=$(printf '%s' "$HTML_CONTENT" | perl -0777 -ne '
        while (/class="required"(.*?)<\/p>/gs) {
            my $block = $1;
            while ($block =~ /href="([^">]+\.html)"/g) {
                my $href = $1;
                $href =~ s|.*/||; $href =~ s|\.html$||;
                print "$href\n";
            }
        }
    ' | sort -u)
    
    # Custom dependency injection
    if [[ "${PACKAGE,,}" == "prison" || "${PACKAGE,,}" == "frameworks6" ]]; then
        log "Injecting custom dependency 'libdmtx' for $PACKAGE..."
        REQUIRED_DEPS=$(printf "libdmtx\n%s" "$REQUIRED_DEPS" | sort -u)
    fi

    if [[ -n "$REQUIRED_DEPS" ]]; then
        log "Required deps: $(echo "$REQUIRED_DEPS" | tr '\n' ' ')"
        while read -r dep; do
            [[ -z "$dep" ]] && continue
            # Skip if already being built (circular dep guard)
            if [[ ":${BUILDING_STACK}:" == *":${dep}:"* ]]; then
                log "Skipping dep '$dep': already in build stack."
                continue
            fi
            # Check if the dependency is installed on the VM
            # Write check to a temp file to avoid heredoc-in-$() syntax issues
            _dep_check_script="/tmp/dep_check_${dep//[^a-zA-Z0-9]/_}.sh"
            cat > "$_dep_check_script" <<DEPCHECK
dep='$dep'
# 1. Standard pkg-config check
# Special check for KDE/Plasma upstream dependencies to ensure version compatibility
if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" ]]; then
    # Identify KDE components that usually share the Frameworks/Plasma version
    if [[ "$dep" =~ ^(k[a-z0-9]+|breeze-icons|extra-cmake-modules|attica|polkit-kde-agent-1|libkscreen|libksysguard|milou|plasma-|sddm-kcm|khotkeys|kwrited|kscreenlocker|ksshaskpass|kgamma|kdecoration|ksysguard)$ ]]; then
        # Check if the installed version in our registry matches the target upstream version
        for reg_dir in "/var/lib/book-packages" "/var/lib/custom-packages"; do
            if [ -f "\$reg_dir/\$dep" ]; then
                INSTALLED_VER=\$(head -n 1 "\$reg_dir/\$dep" | grep -v "^#" | tr -d "[:space:]")
                # Compare only major.minor if it's a dot-zero release or if versions match exactly
                if [[ "\$INSTALLED_VER" == "$UPSTREAM_VERSION" ]] || [[ "\$INSTALLED_VER" == "${UPSTREAM_VERSION}.0" ]] || [[ "\${INSTALLED_VER}.0" == "$UPSTREAM_VERSION" ]]; then
                    echo installed && exit 0
                else
                    echo "outdated (\$INSTALLED_VER vs $UPSTREAM_VERSION)" >&2
                    exit 1
                fi
            fi
        done
    fi
fi

pkg-config --exists "$dep" 2>/dev/null && echo installed && exit 0
pkg-config --exists "${dep}-1" "${dep}-0" 2>/dev/null && echo installed && exit 0

# 2. Xorg special cases
if [[ "$dep" =~ ^x7(font|lib|app|driver)$ ]]; then
    # If we have any of the common component dirs, assume it is installed
    # e.g. for x7font, check if /usr/share/fonts/X11 exists
    [ "$dep" == "x7font" ] && [ -d /usr/share/fonts/X11 ] && echo installed && exit 0
    [ "$dep" == "x7lib" ] && [ -d /usr/include/X11 ] && echo installed && exit 0
fi

# 3. Mesa special case (often called mesa but provides gbm, egl, gl)
if [ "$dep" == "mesa" ]; then
    pkg-config --exists gbm egl gl 2>/dev/null && echo installed && exit 0
fi

# 4. xcursor-themes special case
if [ "$dep" == "xcursor-themes" ]; then
    [ -d /usr/share/icons/whiteglass ] && echo installed && exit 0
fi

# 4.5 KDE/Plasma Meta-package special cases
if [[ "$dep" == "frameworks6" || "$dep" == "frameworks" ]]; then
    # Check for core components like extra-cmake-modules or kf6-config
    (pkg-config --exists extra-cmake-modules || [ -d /usr/lib/cmake/KF6 ] || [ -d /usr/include/KF6 ]) && echo installed && exit 0
fi
if [[ "$dep" == "plasma-all" || "$dep" == "plasma" ]]; then
    # Check for plasma-desktop or similar
    ([ -f /usr/bin/plasma-desktop ] || [ -f /usr/lib/libPlasma.so ]) && echo installed && exit 0
fi

# 5. Executable check
command -v "$dep" >/dev/null 2>&1 && echo installed && exit 0

# 6. Library search
dep_u=$(echo "$dep" | tr '-' '_')
ls /usr/lib/lib${dep_u}*.so* /usr/lib/lib${dep}*.so* /usr/lib/${dep}*.so* 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0

# 7. Versioned pkg-config fallback
dep_base=$(echo "$dep" | sed -E 's/[0-9]+$//')
dep_ver=$(echo "$dep" | grep -oE '[0-9]+$')
if [ -n "$dep_ver" ]; then
    pkg-config --exists "${dep_base}+-${dep_ver}.0" "${dep_base}-${dep_ver}.0" 2>/dev/null && echo installed && exit 0
    ls /usr/lib/lib${dep_base}-${dep_ver}.so* /usr/lib/lib${dep_base}${dep_ver}*.so* 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0
fi

# 8. Include/Share dir check
ls -d /usr/include/${dep} /usr/include/${dep_u} 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0
dep_nodash=$(echo "$dep" | tr -d '-')
find /usr/lib/cmake -maxdepth 1 -iname "${dep}" -o -iname "${dep_nodash}" -o -iname "*${dep_nodash}*" 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0
ls -d /usr/share/${dep} /usr/share/icons/${dep} 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0
ls -d /usr/share/doc/${dep}-* 2>/dev/null | head -n1 | grep -q . && echo installed && exit 0

echo not_installed
DEPCHECK
            dep_status=$(target_run "bash -s" < "$_dep_check_script" 2>/dev/null | grep -vE '^(Warning:|Connection|IP|SSH|grep:)' | tr -d '\r' | tail -n1)
            rm -f "$_dep_check_script"


            if [[ "$dep_status" != "installed" ]]; then
                log "Required dep '$dep' not found — building it first..."
                DRY_FLAG=""; [[ "$DRY_RUN" == "true" ]] && DRY_FLAG="--dry-run"
                RESOLVE_DEPS=true BUILDING_STACK="$BUILDING_STACK" \
                    "$0" $DRY_FLAG "$dep" \
                    || log "[WARNING] Failed to build dep '$dep'. Continuing with main build..."
            else
                log "Dependency '$dep' already installed."
            fi
        done <<< "$REQUIRED_DEPS"
    else
        log "No required dependencies found on page."
    fi
fi
fi

get_commands() {
    local html="$1"
    local target_pkg="$2"
    
    # If it is a driver, try to simplify for anchor matching
    if [[ "$target_pkg" =~ ^xorg-.*-driver$ ]]; then
        target_pkg=$(echo "$target_pkg" | sed 's/^xorg-//; s/-driver$//')
    fi

    # If target_pkg is provided, try to isolate its section (Identity Crisis Fix)
    if [[ -n "$target_pkg" ]]; then
        # Try a more robust sectioning: find the anchor and take everything until the next major section or header.
        # We use environment variable to safely pass target_pkg to perl.
        local sectioned_html=$(TARGET_PKG="$target_pkg" printf '%s' "$html" | perl -0777 -ne '
            my $tp = $ENV{TARGET_PKG};
            # Match 1: Header containing anchor with ID/Name (More specific, should come first)
            if (/(<(h[1-6])[^>]*>.*?<(?:a|div)\s+[^>]*?\b(?:id|name)="\Q$tp\E"[^>]*>.*?<\/ \2>.*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$tp\E)[^"]+")/is) {
                print $1;
            }
            # Match 2: Standalone anchor or div - capture until next major section
            elsif (/(<(?:a|div|h[1-6]|section|p|li)[^>]*?\b(?:id|name)="\Q$tp\E"[^>]*>.*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$tp\E)[^"]+")/is) {
                my $content = $1;
                # If we captured almost nothing (no substantial tags), continue matching until the next section
                if ($content !~ /<(?:pre|p|div|table|ul|ol|h[3-6]|section)/is) {
                    if (/(<(?:a|div|h[1-6]|section|p|li)[^>]*?\b(?:id|name)="\Q$tp\E"[^>]*>.*?(?:<div\s+class="sect[12]"|<h[12]).*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$tp\E)[^"]+")/is) {
                        print $1;
                    } else { print $content }
                } else { print $content }
            }
        ')
        if [[ -n "$sectioned_html" ]]; then
             html="$sectioned_html"
             log "[DEBUG] Successfully isolated section for $target_pkg"
        fi
    fi

    # Extract blocks and clean them individually, preserving root vs userinput class
    printf '%s' "$html" | awk '
        BEGIN { IGNORECASE=1; next_is_root=0; in_block=0; current_block=""; in_screen=0 }
        
        /<pre[^>]*>/ {
            tag=$0;
            if (tag ~ /class="screen"/) { in_screen=1; next }
            if (tag ~ /class="root"/) { mode="root" }
            else if (next_is_root) { mode="root"; next_is_root=0 }
            else { mode="user" }
            
            if (mode == "root") { print "___BLOCK_START_ROOT___" }
            else { print "___BLOCK_START_USER___" }
            in_block=1;
        }
        
        in_screen {
            if ($0 ~ /<\/pre>/) { in_screen=0 }
            next;
        }
        
        in_block {
            line=$0;
            # Strip tags we process
            gsub(/<pre[^>]*>/, "", line);
            
            if (line ~ /<\/pre>/) {
                # Ended on this line
                content = line;
                gsub(/<\/pre>.*/, "", content); # Keep before
                gsub("<[^>]+>", "", content);
                if (content !~ /^[[:space:]]*$/) {
                    print content;
                    current_block = current_block content
                }
                
                if (current_block ~ /^[[:space:]]*root[[:space:]]*$/) { next_is_root=1 }
                print "___BLOCK_END___";
                in_block=0; current_block="";
            } else {
                # Line entirely inside
                gsub("<[^>]+>", "", line);
                if (line !~ /^[[:space:]]*$/) {
                    print line;
                    current_block = current_block line
                }
            }
        }
    ' | perl -0777 -pe 's/<[^>]+>//gs' | \
        sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | \
        perl -0777 -pe 's/\\\n\s*/ /gs; s/\\\s+/ /gs' | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        grep -vE "^$|^exec |vim -c |mountpoint -q /dev/shm|mount -t tmpfs devshm" | \
        grep -vE "^[[:space:]]*<[a-zA-Z ]+>[[:space:]]*$" | \
        grep -vEi '^(\.desktop|/usr/share/.*|/etc/.*)$' | \
        grep -vEi '(---[>]|Options ---[>]|^\s*\[[ *]*\] )' | \
        grep -vE '^rm /etc/resolv\.conf$' | \
        grep -vE '^\s*\.{3,}\s*$' | \
        grep -vE '\[[A-Z0-9_]{3,}\]$|--->' | \
        grep -vE '^(\s*<[*/]?(M|Y|N)>\s+.*\[.*\]\s*$|.*--->\s*\[.*\]|.*\[USB_|.*\[PARPORT)' | \
        grep -vE '^[[:space:]]*(and[[:space:]]*)?(CONFIG_[A-Z0-9_]+[,[:space:]]*(and[[:space:]]*)?)+[[:space:]]*$' | \
        sed 's/yes | cpan -i/yes | sudo cpan -i/g' | \
        sed -E 's/[[:space:]]\.{3,}([[:space:]]|$)/ /g; s/^\.{3,}[[:space:]]//g; s/[[:space:]]+$//' | \
        perl -0777 -pe '
            # 1. Remove trailing && before block ends or start of next markers
            s/\s*&&\s*\n\s*?___BLOCK_END___/\n___BLOCK_END___/gs;
            s/\s*&&\s*\n\s*?___BLOCK_START_/\n___BLOCK_START_/gs;
            # 2. Remove empty blocks
            s/___BLOCK_START_(ROOT|USER)___\s*___BLOCK_END___\s*//gs;
            # 3. Final cleanup of any trailing && at end of file
            s/\s*&&\s*$//gs;
            # 4. Suppress errors for redundant symlinks
            s/^[[:space:]]*(ln -sv? [^|&\n]+)$/$1 || true/gm;
        '
}

    if [[ -n "$METAPACKAGE_TARGET" ]]; then
        RAW_CONTENT=$(get_commands "$HTML_CONTENT")
    else
        RAW_CONTENT=$(get_commands "$HTML_CONTENT" "$PACKAGE")
    fi

    # Handle custom hardcoded packages (libelf, elfutils, etc)
    if [[ "$PACKAGE" == "libelf" || "$PACKAGE" == "elfutils" ]]; then
        log "Using hardcoded metadata for $PACKAGE (elfutils package)"
        # LFS Chapter 8 / BLFS style build for libelf/elfutils
        RAW_CONTENT="___BLOCK_START_USER___
./configure --prefix=/usr                \\
            --disable-debuginfod         \\
            --enable-libdebuginfod=dummy &&
make
___BLOCK_END___
___BLOCK_START_ROOT___
make install
___BLOCK_END___"
        # Since we have RAW_CONTENT, we don't need to fetch it from HTML later
        SKIP_HTML_EXTRACTION="true"
        MAIN_DOWNLOAD_URL="https://sourceware.org/elfutils/ftp/0.194/elfutils-0.194.tar.bz2"
        DOWNLOAD_URLS=("$MAIN_DOWNLOAD_URL")
        LFS_VERSION="0.194"
        log "Hardcoded commands for $PACKAGE injected into RAW_CONTENT."
    fi

    # TZDATA special case: glibc.html contains many things, we only want the tzdata block
    if [[ "$PACKAGE" == "tzdata" ]]; then
        log "Filtering commands for tzdata only..."
        RAW_CONTENT=$(echo "$RAW_CONTENT" | perl -0777 -ne "
            if (/(ZONEINFO=\\/usr\\/share\\/zoneinfo.*unset ZONEINFO tz)/is) {
                my \$c = \$1;
                # Strip inappropriate glibc commands that might have bled in
                \$c =~ s/^[[:space:]]*(patch|\\.\\/configure|make[[:space:]]+.*|sed[[:space:]]+.*|localedef[[:space:]]+.*|cat[[:space:]]+.*>.*nsswitch\.conf).*\\n//gm;
                # Strip redundant tar extraction from the page
                \$c =~ s/^[[:space:]]*tar -xf .*?tzdata.*?\.tar\..*\\n//gm;
                print \"___BLOCK_START_ROOT___\\n\";
                print \$c;
                print \"\\n___BLOCK_END___\\n\";
            }
        ")
        if [[ -z "$RAW_CONTENT" ]]; then
            # Try second pattern if the first one failed (LFS version variations)
            RAW_CONTENT=$(echo "$HTML_CONTENT" | perl -0777 -ne "
                if (/(ZONEINFO=\\/usr\\/share\\/zoneinfo\\s+mkdir -pv \\\$ZONEINFO.*?unset ZONEINFO tz)/is) {
                    my \$c = \$1; \$c =~ s/<[^>]+>//gs;
                    # Same stripping logic
                    \$c =~ s/^[[:space:]]*(patch|\\.\\/configure|make[[:space:]]+.*|sed[[:space:]]+.*|localedef[[:space:]]+.*).*\\n//gm;
                    \$c =~ s/^[[:space:]]*tar -xf .*?tzdata.*?\.tar\..*\\n//gm;
                    print \"___BLOCK_START_ROOT___\\n\$c\\n___BLOCK_END___\\n\";
                }
            ")
        fi
        log "Tzdata commands isolated and cleaned (using internal markers)."
    fi

    # Special handling for Linux kernel - include headers
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Adding Linux API Headers build steps..."
        HEADER_HTML=$(curl -s "$LFS_BOOK/chapter05/linux-headers.html")
        # In a running system, we don't use $LFS prefix and we install to /usr
        # Prepend header commands to RAW_CONTENT so they get processed by the annotation loop
        HEADER_CMDS=$(get_commands "$HEADER_HTML" "linux-headers" | sed 's/\$LFS//g')
        RAW_CONTENT="${HEADER_CMDS}
${RAW_CONTENT}"
    fi

    if [[ "$PACKAGE" == "wireplumber" ]]; then
        log "Disabling documentation for wireplumber to fix Doxygen/XML generation issues..."
        RAW_CONTENT=$(echo "$RAW_CONTENT" | sed 's/meson setup/meson setup -Ddoc=disabled -Dintrospection=disabled/g')
    fi

    if [[ "$PACKAGE" == "fltk" ]]; then
        log "Disabling doxygen support and documentation for fltk..."
        # 1. Disable Doxygen in CMake
        RAW_CONTENT=$(echo "$RAW_CONTENT" | sed 's/cmake -D/cmake -D CMAKE_DISABLE_FIND_PACKAGE_Doxygen=TRUE -D/g')
        # 2. Strip out documentation installation lines
        RAW_CONTENT=$(echo "$RAW_CONTENT" | grep -vEi "documentation/html|/usr/share/doc/fltk|ninja documentation")
        # 3. Clean up any empty blocks that might have been created
        RAW_CONTENT=$(echo "$RAW_CONTENT" | perl -0777 -pe 's/___BLOCK_START_(ROOT|USER)___\n___BLOCK_END___//gs')
    fi

    # Process blocks: Parallel make and Test filtering
CRITICAL_PKGS="gcc binutils glibc"
is_critical=false

# 1. Hardcoded critical packages
for c in $CRITICAL_PKGS; do
    if [[ "$PACKAGE" == "$c" || "$PACKAGE" == "$c-"* ]]; then
        # GCC tests are only critical in LFS, not BLFS
        if [[ "$PACKAGE" == "gcc"* && "$SEARCH_BLFS" == "true" ]]; then
            log "GCC build from BLFS detected: treating tests as non-critical."
            is_critical=false
        else
            is_critical=true
        fi
        break
    fi
done

# 2. Dynamic detection: Search Page for "test suite" and "critical" on same line
if [[ "$is_critical" == "false" ]]; then
    if echo "$HTML_CONTENT" | sed 's/<[^>]*>//g' | grep -iE "test suite.*critical|critical.*test suite" >/dev/null; then
        log "Dynamic detection: Test suite for $PACKAGE is marked as critical on its book page."
        is_critical=true
    fi
fi

COMMANDS=""
CURRENT_BLOCK=""
CURRENT_BLOCK_TYPE="user"
configure_seen=false
while IFS= read -r line; do
    if [[ "$line" == "___BLOCK_START_ROOT___" ]]; then
        CURRENT_BLOCK=""
        CURRENT_BLOCK_TYPE="root"
        continue
    elif [[ "$line" == "___BLOCK_START_USER___" ]]; then
        CURRENT_BLOCK=""
        CURRENT_BLOCK_TYPE="user"
        continue
    elif [[ "$line" == "___BLOCK_END___" ]]; then
        [[ -z "$CURRENT_BLOCK" ]] && continue

        _eff_type="$CURRENT_BLOCK_TYPE"
        if [[ "$_eff_type" == "user" ]]; then
            if grep -qE '^[[:space:]]*(make[[:space:]]+.*install|ninja[[:space:]]+.*install|meson[[:space:]].*install|cmake[[:space:]]+--install|(install|ln|rm|cp|mv|touch|chmod|chown|chgrp|sed|patch|awk|cat|tee|echo|wget|update-desktop-database|glib-compile-schemas)[[:space:]].*(/usr|/boot|/etc|/lib|/var|/opt|/sbin|/bin)|rm[[:space:]]+.*info/dir|(pwconv|grpconv|pwunconv|grpunconv|passwd|useradd|groupadd|userdel|groupdel|usermod|groupmod|mkinitramfs|grub-mkconfig|ldconfig|depmod|gtk-update-icon-cache))' <<< "$CURRENT_BLOCK"; then
                _eff_type="root"
            fi
        fi
        
        # 1. Block Blacklist (mainly for glibc)
        if [[ "$PACKAGE" == "glibc" ]]; then
            # Relaxed skipping: only skip blocks that are PURELY configuration without build commands
            if grep -qiE "(nscd|gcc[[:space:]]+-print-libgcc-file-name|localedef|localedata/install-locales|nsswitch\.conf|ZONEINFO|tzselect|localtime|ld\.so\.conf)" <<< "$CURRENT_BLOCK" && ! grep -qiE "(\.\./configure|make)" <<< "$CURRENT_BLOCK"; then
                log "Skipping unnecessary glibc configuration/maintenance block." >&2
                continue
            fi
        fi

        if [[ "$PACKAGE" == "shadow" ]]; then
            if grep -qiE "^(pwconv|grpconv|pwunconv|grpunconv|passwd|useradd|groupadd|userdel|groupdel|usermod|groupmod)" <<< "$CURRENT_BLOCK"; then
                log "Skipping unnecessary shadow configuration/maintenance block." >&2
                continue
            fi
        fi

        # Skip literal placeholder alternatives like `ABI=32 ./configure ...`
        if grep -q "configure \.\.\." <<< "$CURRENT_BLOCK"; then
            log "Skipping placeholder configure block." >&2
            continue
        fi
        
        # 2. Skip duplicate configure blocks (BLFS shows alternatives)
        if [[ "$CURRENT_BLOCK" =~ [[:space:]]*(\./|\.\./)configure ]]; then
            if [[ "$configure_seen" == "true" ]] && [[ "${PACKAGE,,}" != "sassc" ]]; then
                log "Skipping duplicate configure block (alternative build method)." >&2
                continue
            fi
            configure_seen="true"
        fi

        # 3. Skip kernel configuration blocks from BLFS 'Kernel Configuration' sections
        # These contain <*/M> notation for kconfig options and are NOT shell commands
        if grep -qE '<\*/M>|<\*>|<M>[[:space:]]+[A-Z_]+$|\[USB_|USB_PRINTER\]|\[PARPORT|\[DRM\]' <<< "$CURRENT_BLOCK"; then
            log "Skipping kernel configuration block." >&2
            continue
        fi

        # 3b. Skip system configuration and service management blocks
        if grep -qE "(groupadd|useradd|usermod|systemctl)" <<< "$CURRENT_BLOCK"; then
            log "Skipping system configuration/service management block." >&2
            continue
        fi


        # 4. Skip blfs-systemd-units / configuration install commands
        if [[ "$CURRENT_BLOCK" =~ make[[:space:]]+install-(dhcpcd|rsyncd|gpm) ]]; then
            log "Skipping service/configuration install command." >&2
            continue
        fi

        # 5. Skip OpenSSH configuration blocks
        if [[ "$PACKAGE" == "openssh" ]]; then
            if [[ ! "$CURRENT_BLOCK" =~ "make install" ]] && grep -qE "(sshd_config|ssh-keygen|ssh-copy-id)" <<< "$CURRENT_BLOCK"; then
                log "Skipping OpenSSH configuration block." >&2
                continue
            fi
            if [[ "$CURRENT_BLOCK" =~ "make install-sshd" ]]; then
                log "Skipping OpenSSH install-sshd block." >&2
                continue
            fi
        fi

        # 6. Skip post-installation configuration blocks
        # Match: bare `cat`, `as_root cat`, `sudo ... cat`, indented `cat` writing to /etc/ or /var/
        if [[ "$INCLUDE_CONFIG" == "false" ]] && grep -qE "(^|[[:space:]])(sudo[[:space:]]+(-[^ ]+[[:space:]]+)*)?cat[[:space:]]*>>?[[:space:]]*/etc/|(^|[[:space:]])(sudo[[:space:]]+(-[^ ]+[[:space:]]+)*)?cat[[:space:]]*>>?[[:space:]]*/var/" <<< "$CURRENT_BLOCK"; then
            # Never skip critical PAM/Shadow configurations
            if ! grep -qE "/etc/pam\.d/|/etc/login\.defs|/etc/security/|/etc/shadow|/etc/sddm" <<< "$CURRENT_BLOCK" && \
               [[ "${PACKAGE,,}" != "linux-pam" ]] && [[ "${PACKAGE,,}" != "shadow" ]]; then
                log "Skipping post-installation configuration block." >&2
                continue
            fi
        fi

        # 7. Determine if this block is a test suite or related setup

        if [[ "$XORG_MULTI_MODE" == "false" ]] && \
           ! grep -qE '^[[:space:]]*(cmake|mkdir[[:space:]]+build)' <<< "$(echo "$CURRENT_BLOCK" | grep -vE "BUILD_(TESTS|TESTING)=ON")" && \
           [[ "$CURRENT_BLOCK" =~ (make[[:space:]][^$'\n']*(check|test|tests|jstest|jit-test|all-headless)|ninja[[:space:]]+(test|check)|meson[[:space:]]+test|x\.py[[:space:]]+test|grep[^$'\n']*testlog|grep[^$'\n']*test\ result:|awk[^$'\n']*passed[^$'\n']*failed|spawn[^$'\n']*make|\<expect\>|([[:space:]]|^)tester([[:space:]]|$)|su[^$'\n']*tester|groupadd[^$'\n']*dummy|groupdel[^$'\n']*dummy|gnulib-tests|(^|[[:space:]])testdir([[:space:]]|$)|test_summary|cd[[:space:]]+tests|all\.sh|tests/run\.sh|tar[^$'\n']*xmlts|xmlts) ]]; then
            # util-linux special case: ensure tests are compiled before running
            if [[ "$PACKAGE" == "util-linux" ]] && [[ ! "$CURRENT_BLOCK" =~ "check-programs" ]]; then
                log "Prepending 'make check-programs' to util-linux test block."
                CURRENT_BLOCK="make check-programs
$CURRENT_BLOCK"
            fi

            if [[ "$is_critical" == "true" ]]; then
                CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
                COMMANDS+="
# __BEGIN_ROOT__
if ! (
$CURRENT_BLOCK
); then
    echo '[WARNING] Test suite for $PACKAGE failed.'
    if [[ \"\$YES\" == \"true\" ]]; then
        echo '[INFO] Proceeding anyway (--yes enabled).'
    else
        read -p 'Build failed tests. Proceed to installation anyway? [y/N] ' -n 1 -r < /dev/tty
        echo
        if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi
# __END_ROOT__
"
            else
                log "Skipping non-critical test block." >&2
            fi
        elif [[ "$CURRENT_BLOCK" =~ "patch" ]]; then
            CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
            # Make patch non-interactive so it doesn't hang the build
            # Protect against filenames containing "patch" by matching only at start of line or after separators
            CURRENT_BLOCK=$(echo "$CURRENT_BLOCK" | sed -E 's/(^|[|;&(][[:space:]]*)patch\b/\1patch -N -f /g')
            COMMANDS+="# __BEGIN_ROOT__
"
            COMMANDS+="echo \"Attempting to apply patch...\"
"
            COMMANDS+="( $CURRENT_BLOCK ) || echo \"[WARNING] Patch application failed, continuing build...\"
"
            COMMANDS+="# __END_ROOT__
"
        else
            # Not a test or patch block - annotate with privilege type
            [[ "$_eff_type" == "root" ]] && COMMANDS+="# __BEGIN_ROOT__"$'\n'
            [[ "$_eff_type" == "user" ]] && COMMANDS+="# __BEGIN_USER__"$'\n'
            while IFS= read -r bline; do
                if [[ "$bline" =~ ^(make([[:space:]]|$)|\./configure[[:space:]]&&[[:space:]]make([[:space:]]|$)) ]] && \
                   [[ ! "$bline" =~ "install" ]] && \
                   [[ ! "$bline" =~ "headers" ]] && \
                   [[ ! "$bline" =~ "-j" ]]; then
                    bline=$(echo "$bline" | sed -E 's/\bmake\b/make -j$(nproc)/g')
                elif [[ "$bline" =~ ^ninja([[:space:]]|$) ]] && [[ ! "$bline" =~ "-j" ]]; then
                    bline=$(echo "$bline" | sed -E 's/\bninja\b/ninja -j$(nproc)/g')
                fi
                # Global fix for libdir in CMake builds
                if [[ "$bline" =~ "-D CMAKE_INSTALL_PREFIX=" ]] && [[ ! "$bline" =~ "CMAKE_INSTALL_LIBDIR" ]]; then
                    bline=$(echo "$bline" | sed "s/-D CMAKE_INSTALL_PREFIX=/-D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_INSTALL_PREFIX=/g")
                fi
                # Strip placeholder commands like /path/to/web/app
                if [[ "$bline" =~ "/path/to/web/app" ]]; then
                    log "Stripping placeholder command: $bline"
                    continue
                fi
                # Strip time-consuming PGO optimizations (tests) from Python
                if [[ "$PACKAGE" == "python"* ]] && [[ "$bline" =~ "--enable-optimizations" ]]; then
                    log "Stripping non-critical --enable-optimizations from Python." >&2
                    bline=$(echo "$bline" | sed 's/--enable-optimizations//g; s/[[:space:]]\+/ /g')
                fi
                COMMANDS+="$bline"$'\n'
            done <<< "$CURRENT_BLOCK"
            [[ "$_eff_type" == "root" ]] && COMMANDS+="# __END_ROOT__"$'\n'
            [[ "$_eff_type" == "user" ]] && COMMANDS+="# __END_USER__"$'\n'
        fi
        continue
    fi
    CURRENT_BLOCK+="$line"$'\n'
done <<< "$RAW_CONTENT"

# (Linux kernel specific headers block removed from here as it is now integrated into RAW_CONTENT above)

log "Extracted commands: $COMMANDS"
if [[ -z "$COMMANDS" ]]; then
    error "Could not extract build commands for '$PACKAGE'"
fi

# Package-specific source fixes after command processing
# 2.4.5 Convert pushd/popd to cd for better block compatibility
COMMANDS=$(echo "$COMMANDS" | sed -E 's/\bpushd[[:space:]]+(\.\.|doc)\b/cd \1/g; s/\bpopd\b/cd .. /g')
# Protect against other pushd calls if they are part of a library build (like libsass in sassc)
COMMANDS=$(echo "$COMMANDS" | sed -E 's/\bpushd[[:space:]]+([^[:space:];&|]+)\b/cd \1/g')

# 2.4.6 Add autoreconf fallback: if ./configure or ../configure is called but the
# configure script may not exist in the unpacked source tree (package uses autotools
# but doesn't pre-generate configure), prepend an autoreconf guard so the build
# doesn't fail with './configure: No such file or directory'.
if echo "$COMMANDS" | grep -qE '^[[:space:]]*(\./|\.\./)configure'; then
    COMMANDS=$(echo "$COMMANDS" | sed -E \
        's@^([[:space:]]*)(\./configure)@\1[ -f configure ] || autoreconf -fiv\n\1\2@g')
    COMMANDS=$(echo "$COMMANDS" | sed -E \
        's@^([[:space:]]*)(\.\./configure)@\1[ -f ../configure ] || (cd .. \&\& autoreconf -fiv)\n\1\2@g')
fi

# Package-specific source fixes after command processing
if [[ "${PACKAGE,,}" == "sassc" ]]; then
    # libsass and sassc archives contain manual Makefiles that interfere with Autotools
    # and have broken relative paths in their install targets.
    # We force the use of Autotools-generated Makefiles by removing the manual ones
    # and setting environment variables to ensure shared builds.
    log "Applying sassc/libsass source fix: removing interfering manual Makefiles and setting environment..."
    SETUP_COMMANDS+="export BUILD=shared
export SASS_LIBSASS_PATH=\$(pwd)/libsass-3.6.6
"
    COMMANDS=$(echo "$COMMANDS" | sed 's/cd libsass/rm -f libsass-3.6.6\/{Makefile,GNUmakefile} \&\& cd libsass/')
    COMMANDS=$(echo "$COMMANDS" | sed 's/cd \.\. /rm -f Makefile \&\& cd .. /')
fi

if [[ "${PACKAGE}" == "shared-mime-info" ]]; then
    COMMANDS=$(echo "$COMMANDS" | sed '/mv shared-mime-info/d' | sed '/cd shared-mime-info/d' | sed '0,/cd ../{/cd ../d'})
fi

# Rewrite relative ../pkg.tar.* references in tar commands to absolute /sources/archives/ paths
# Generalized to handle various flags like -xf, -xvf, -xfv and deeper paths like ../..
COMMANDS=$(echo "$COMMANDS" | sed -E 's|tar ([^|&;]*)-x?v?f[[:space:]]+\.\./(\.\./)?(([a-zA-Z0-9_+.-]+)\.tar\.[a-z0-9.]+)|tar \1-xf /sources/archives/\3|g')

# 2.5 Auto-detect Rust dependency
if echo "$HTML_CONTENT" | grep -qiE "rust|rustc|cargo"; then
    log "Rust dependency detected (rust/rustc/cargo found in page content)."
    SETUP_COMMANDS+="export PATH=\$PATH:/opt/rustc/bin
"
fi

# 2.6 Auto-detect TeXLive and set TEXLIVE_PREFIX
if echo "$HTML_CONTENT" | grep -qiE "texlive"; then
    # Extract year from the texlive source archive URL (e.g. texlive-20250308-source.tar.xz -> 2025)
    TEXLIVE_YEAR=$(printf '%s\n' "${DOWNLOAD_URLS[@]}" | perl -nle 'while (m{(?i)texlive-\K[0-9]{4}}g) { print $& }' | head -n 1)
    if [[ -z "$TEXLIVE_YEAR" ]]; then
        # Fallback: try to extract from already-identified main filename
        TEXLIVE_YEAR=$(echo "$MAIN_FILENAME" | perl -nle 'while (m{texlive-\K[0-9]{4}}g) { print $& }')
    fi
    if [[ -n "$TEXLIVE_YEAR" ]]; then
        log "TeXLive detected: setting TEXLIVE_PREFIX=/opt/texlive/$TEXLIVE_YEAR"
        SETUP_COMMANDS+="export TEXLIVE_PREFIX=/opt/texlive/$TEXLIVE_YEAR
"
    else
        log "TeXLive detected but could not determine year from source filenames."
    fi
fi

# 2.7 Auto-detect Qt6/KF6/KDE dependency
if echo "$HTML_CONTENT" | grep -qiE "qt-6|qt6|qt 6|kf6|frameworks 6|frameworks6|plasma 6|plasma6" || [[ "${PACKAGE,,}" =~ ^(qt6|frameworks6|plasma-all|plasma)$ ]] || [[ "$COMMANDS" =~ "KF6" ]]; then
    log "Qt6/KF6/KDE detected: setting environment variables."
    if [[ ! "$SETUP_COMMANDS" =~ "export KF6_PREFIX=" ]]; then
        SETUP_COMMANDS+="export KF6_PREFIX=/usr
"
    fi
    if [[ ! "$SETUP_COMMANDS" =~ "export QT6DIR=" ]]; then
        SETUP_COMMANDS+="export QT6DIR=/opt/qt6
export QT6PREFIX=/opt/qt6
export PATH=\$PATH:\$QT6DIR/bin
export CMAKE_PREFIX_PATH=\$QT6PREFIX:\$KF6_PREFIX:\$CMAKE_PREFIX_PATH
"
        # Only add to LD_LIBRARY_PATH if we are NOT building qt6 itself to avoid version mismatches during upgrades
        if [[ "${PACKAGE,,}" != "qt6" ]]; then
            SETUP_COMMANDS+="export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$QT6DIR/lib
"
        else
            # When building qt6 itself, prepend the build-tree library path to ensure tools like rcc use newly built libs
            # We also ensure the system path is NOT included to avoid version shadowing from ld.so.conf
            SETUP_COMMANDS+="export LD_LIBRARY_PATH=\$(pwd)/qtbase/lib:\$LD_LIBRARY_PATH
"
        fi
    fi
fi


# 2.8 Respect existing Fortran support for GCC
if [[ "$PACKAGE" == "gcc" ]] && [[ "$COMMANDS" == *"--enable-languages=c,c++"* ]]; then
    if target_run "command -v gfortran" &>/dev/null; then
        log "gfortran detected on target system. Adding Fortran support to GCC build."
        COMMANDS="${COMMANDS/--enable-languages=c,c++/--enable-languages=c,c++,fortran}"
    fi
fi

if [[ "$PACKAGE" == "gcc" ]]; then
    log "Applying gcc: strip post-install chown (non-root context)..."
    # LFS/BLFS book runs 'chown -v root:root ...' after make install.
    # These fail without CAP_CHOWN. Ownership is already correct from make install via as_root.
    COMMANDS=$(echo "$COMMANDS" | grep -vE '^[[:space:]]*(as_root[[:space:]]+)?chown[[:space:]]')
    # Fix the symlink to avoid "File exists" error
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/\bln -sv\b/ln -sfv/g; s/\bln -s\b/ln -sf/g')
    # GCC's own Makefile creates /usr/lib/cpp with plain 'ln' (not ln -f), so it fails if
    # a prior GCC install already created the symlink.  Remove it before make install.
    log "Applying gcc: pre-remove /usr/lib/cpp before make install to avoid 'File exists'..."
    COMMANDS=$(echo "$COMMANDS" | sed 's|^make install$|rm -f /usr/lib/cpp \&\& make install|g; s|^make install |rm -f /usr/lib/cpp \&\& make install |g')
fi

if [[ "$PACKAGE" == "tcl" ]]; then
    log "Applying tcl: ensure build runs from the unix/ subdirectory..."
    COMMANDS=$(echo "$COMMANDS" | sed "s/\[ -f configure \] || autoreconf -fiv//g")
    # The LFS book already includes 'cd unix', but in case our directory tracking gets confused,
    # we explicitly strip other 'cd' commands to the tcl dir and ensure we enter unix/ before configure.
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^cd tcl")
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^cd unix")
    COMMANDS=$(echo "$COMMANDS" | sed 's|\./configure|cd unix; ./configure|g')
fi

if [[ "$PACKAGE" == "iptables" ]]; then
    log "Applying iptables: strip post-install firewall example scripts from BLFS page..."
    # Strip out any iptables commands that manipulate rules (like WAN1, LAN1)
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^[[:space:]]*(sudo |as_root )?(iptables|ip6tables|iptables-restore|ip6tables-restore)[[:space:]]")
    # The BLFS iptables page embeds rc.iptables example scripts referencing
    # placeholder interface names like WAN1/LAN1, causing 'Bad argument WAN1' failures.
    # Strip everything from the first 'cat > /etc/rc.d/rc.iptables' heredoc onwards.
    COMMANDS=$(echo "$COMMANDS" | awk '
        /cat > \/etc\/rc\.d\/rc\.iptables/ { found=1 }
        !found { print }
    ')
    # The BLFS page also includes a 'make install-iptables' blfs-bootscripts command
    # (for the /etc/rc.d/init.d/iptables init script) which has no target in the
    # iptables source Makefile.  Strip it to prevent a fatal build failure.
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^[[:space:]]*(as_root[[:space:]]+|sudo[[:space:]]+)?make[[:space:]]+(install-iptables|install-ip6tables)([[:space:]]|$)")
fi

if [[ "$PACKAGE" == "libtiff" ]]; then
    log "Applying libtiff: guard doc-dir rename against missing directory..."
    COMMANDS=$(echo "$COMMANDS" | sed 's|mv -v /usr/share/doc/tiff{|[ -d /usr/share/doc/tiff ] \&\& mv -v /usr/share/doc/tiff{|g')
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's|(\[ -d /usr/share/doc/tiff \] && mv -v /usr/share/doc/tiff\{[^}]+\})|$1 \|\| true|g')
fi

if [[ "$PACKAGE" == "kdsoap-ws-discovery-client" ]]; then
    log "Applying kdsoap-ws-discovery-client: guard doc-dir rename against missing directory..."
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's|^mv (.*KDSoap.*)$|[ -d /usr/share/doc/KDSoapWSDiscoveryClient ] \&\& mv $1 \|\| true|g')
fi

if [[ "${PACKAGE,,}" == "webkitgtk" ]]; then
    log "Applying webkitgtk: disabling GStreamer GL support due to missing OpenGL in gst-plugins-base..."
    # The BLFS book specifies adding -DUSE_GSTREAMER_GL=OFF if gst-plugins-base was built without OpenGL
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/-DCMAKE_BUILD_TYPE=Release/-DCMAKE_BUILD_TYPE=Release -DUSE_GSTREAMER_GL=OFF/g')
fi

# 2.8 Ensure LLVM is built with WebAssembly support (required by Firefox / wasm32-wasi)
if [[ "$PACKAGE" == "llvm" ]] && [[ "$COMMANDS" == *"LLVM_TARGETS_TO_BUILD"* ]]; then
    if [[ "$COMMANDS" != *"WebAssembly"* ]]; then
        log "Adding WebAssembly to LLVM_TARGETS_TO_BUILD."
        COMMANDS=$(echo "$COMMANDS" | sed 's/-D LLVM_TARGETS_TO_BUILD="\([^"]*\)"/-D LLVM_TARGETS_TO_BUILD="\1;WebAssembly"/')
    fi
fi

if [[ "${PACKAGE,,}" == "firefox" ]]; then
    log "Applying firefox: patch cbindgen COUNT issue and webrender_bindings lifetime elision (Rust 1.80+)..."
    # Fix cbindgen issue with COUNT in texture_cache.rs by removing pub visibility from
    # constants starting with C, V, or P (like COUNT). This prevents cbindgen from emitting
    # bare C++ identifiers that cause compilation errors.
    COMMANDS=$(echo "$COMMANDS" | sed -E 's@(\./mach build)@sed -i "/const [CVP]/s/pub //" gfx/wr/webrender/src/texture_cache.rs 2>/dev/null || true\n\1@g')
    # Build the python patch script and base64-encode it so it can be safely injected into COMMANDS
    # and decoded/written on the VM at build time — avoids all quoting/escaping issues.
    _FF_PY_SCRIPT=$(cat << 'PYEOF'
import re
path = "gfx/webrender_bindings/src/lib.rs"
try:
    with open(path) as f:
        c = f.read()
    c = re.sub(r'#!\[deny\(warnings\)\]\n?', '', c)
    with open(path, 'w') as f:
        f.write(c)
    print("Patched " + path)
except Exception as e:
    print("Warning: could not patch " + path + ": " + str(e))
PYEOF
)
    _FF_PY_B64=$(printf '%s' "$_FF_PY_SCRIPT" | base64 -w 0)
    COMMANDS=$(echo "$COMMANDS" | sed -E "s@(\./mach build)@echo '${_FF_PY_B64}' | base64 -d > /tmp/ff_patch_webrender.py \&\& python3 /tmp/ff_patch_webrender.py\n\1@g")
    unset _FF_PY_SCRIPT _FF_PY_B64
fi

if [[ "${PACKAGE,,}" == "glib2" ]]; then
    log "Applying glib2: updating gobject-introspection tarball path..."
    # The BLFS glib2 page instructs building gobject-introspection from a tarball placed two
    # directories above the build dir (../../gobject-introspection-*.tar.xz).
    # Since we download it to /sources/archives/, we must update the tar command.
    COMMANDS=$(echo "$COMMANDS" | sed -E "s|tar xf \.\./\.\./(gobject-introspection-[0-9.]+\.tar\.xz)|tar xf /sources/archives/\1|g")
fi


if [[ "${PACKAGE,,}" == "kdeplasma-addons" || "${METAPACKAGE_TARGET,,}" == "kdeplasma-addons" ]]; then
    log "Corrosion/Rust fix for kdeplasma-addons is handled in the KDE build loop awk template."
fi


if [[ "${PACKAGE,,}" == "webkitgtk" ]]; then
    log "Applying webkitgtk: disabling GStreamer GL support due to missing OpenGL in gst-plugins-base..."
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/-D[[:space:]]*CMAKE_BUILD_TYPE=Release/-D CMAKE_BUILD_TYPE=Release -D USE_GSTREAMER_GL=OFF/g')
fi

if [[ "${PACKAGE,,}" == "qt6" ]]; then
    log "Applying qt6: patch qsslsocket_openssl_symbols.cpp for duplicate const error with OpenSSL 3+"
    COMMANDS=$(echo "$COMMANDS" | sed -E 's@(\./configure)@sed -i "s/const const X509_EXTENSION/const X509_EXTENSION/g" qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp 2>/dev/null || true\n\1@g')
    
    log "Applying qt6: disabling GStreamer to fix missing gstglconfig.h (gst-plugins-base built without OpenGL)..."
    COMMANDS=$(echo "$COMMANDS" | sed -E 's@(\./configure)@\1 -no-gstreamer@g')
fi

# 2.9 Check for documentation tools and disable if missing (Always disable doxygen)
DOC_TOOLS="gi-docgen db2html xmlto xsltproc sphinx-build texlive asciidoc xmlto"
DOC_PATTERNS="-D (docs?|documentation)=(enabled|true)|--enable-(gtk-doc|doxygen-docs|docs)|make.*[[:space:]](html|man|ps|pdf|info|doxygen|docs)(\b|[[:space:]])"
ENABLE_DOC_BUILD=true
MISSING_DOC_TOOL=""
# Also check that docbook-xsl is registered in the XML catalog (xsltproc alone is not enough)
# This is informational only — systemd man-page generation is always disabled below.
DOCBOOK_XSL_IN_CATALOG=false
if target_run "command -v xsltproc" &>/dev/null; then
    # Check: can xmlcatalog resolve the docbook-xsl stylesheet to a local file, AND does that file exist?
    _docbook_resolved=$(target_run "xmlcatalog /etc/xml/catalog 'http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl' 2>/dev/null | grep -v '^No entry' | head -n1" 2>/dev/null | tr -d '\r\n[:space:]')
    if [[ -n "$_docbook_resolved" ]] && target_run "[ -f '${_docbook_resolved#file://}' ]" 2>/dev/null; then
        DOCBOOK_XSL_IN_CATALOG=true
    else
        log "[WARNING] xsltproc is present but docbook-xsl is NOT installed/registered in /etc/xml/catalog — xsltproc-based man-page generation will fail."
    fi
fi

# ALWAYS suppress doxygen, texlive, asciidoc, xmlto as requested
if [[ "$COMMANDS" =~ "doxygen" || "$COMMANDS" =~ "texlive" || "$COMMANDS" =~ "asciidoc" || "$COMMANDS" =~ "xmlto" ]] || \
   [[ "$HTML_CONTENT" =~ "doxygen" || "$HTML_CONTENT" =~ "texlive" || "$PACKAGE" == "git" || "$PACKAGE" == "gpm" ]]; then
    log "[INFO] Documentation building (doxygen/texlive/asciidoc) is explicitly suppressed."
    ENABLE_DOC_BUILD=false
    # Map to whichever tool was found (or both), doxygen takes precedence for the stripping logic
    if [[ "$COMMANDS" =~ "doxygen" || "$HTML_CONTENT" =~ "doxygen" ]]; then
        MISSING_DOC_TOOL="doxygen"
    else
        MISSING_DOC_TOOL="texlive"
    fi
    # Force common tools to true in the environment to avoid build failures when they are called
    SETUP_COMMANDS+="export DOXYGEN=true TEXI2HTML=true TEXI2PDF=true MAKEINFO=true
export ac_cv_path_DOXYGEN=true ac_cv_path_MAKEINFO=true ac_cv_path_TEXI2HTML=true ac_cv_path_TEXI2PDF=true PATH=/home/fusion809/.juliaup/bin:/usr/bin:/opt/rustc/bin:/opt/jdk/bin:/opt/qt6/bin:/opt/texlive/2025/bin/x86_64-linux:/sbin:/usr/sbin
"
fi

if [[ "$ENABLE_DOC_BUILD" == "true" ]]; then
    # ONLY suppress documentation if specific, missing tools are mentioned on the build page (texlive or others)
    if [[ "$COMMANDS" =~ $DOC_PATTERNS ]] || [[ "$PACKAGE" == "libxml2" ]] || [[ "$PACKAGE" == "git" ]]; then
        for tool in $DOC_TOOLS; do
            # If the tool is referenced in commands OR specifically if it is texlive AND mentioned on the page
            if [[ "$COMMANDS" =~ $tool ]] || \
               ([[ "$tool" =~ texlive ]] && echo "$HTML_CONTENT" | grep -qi "$tool"); then
                if ! target_run "command -v $tool" &>/dev/null; then
                    # Special case: 'texlive' command might be one of its components like 'pdflatex' or 'xelatex'
                    if [[ "$tool" == "texlive" ]]; then
                        if target_run "command -v pdflatex" || target_run "command -v xelatex" &>/dev/null; then
                            continue
                        fi
                    fi
                    log "[WARNING] Documentation tool '$tool' not found on target. Disabling documentation building requiring it."
                    ENABLE_DOC_BUILD=false
                    MISSING_DOC_TOOL="$tool"
                    
                    # Force disabled tools in environment
                    if [[ "$tool" == "texlive" ]]; then
                        SETUP_COMMANDS+="export TEXI2HTML=false TEXI2PDF=false MAKEINFO=false
"
                    elif [[ "$tool" == "doxygen" ]]; then
                        SETUP_COMMANDS+="export DOXYGEN=false
"
                    fi
                    break
                fi
            fi
        done
    fi
fi

# SYSTEM-WIDE MOCK: If doc build is disabled, prepend a mock tool directory to PATH to neutralize any direct calls
if [[ "$ENABLE_DOC_BUILD" == "false" ]]; then
    SETUP_COMMANDS+="
MOCK_DOC_DIR=\"/tmp/mock_docs_\$\$\"
TEXLIVE_PREFIX=\"/opt/texlive/2025\"
mkdir -p \"\$MOCK_DOC_DIR\"
for m in makeinfo asciidoc xmlto asciidoctor xmlproc docbook2x pdflatex xelatex lualatex texi2html texi2pdf texi2dvi dvips sphinx-build; do
    ln -sf /bin/true \"\$MOCK_DOC_DIR/\$m\"
done
export PATH=\"\$MOCK_DOC_DIR:\$PATH\"
"
fi

if [[ "$PACKAGE" == "svt-av1" ]]; then
    log "Applying SVT-AV1 LTO=OFF and test suppression fix"
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/(cmake.*?\.\.)/$1 -DSVT_AV1_LTO=OFF/g')
    # Filter out the extremely long test phase that downloads huge files
    COMMANDS=$(echo "$COMMANDS" | grep -vE "TestVectors|ctest")
fi


if [[ "$PACKAGE" == "qt6" ]]; then
    log "Fixing Qt6 BLFS book patch path (../ to ../../) due to -d qtbase/"
    COMMANDS=$(echo "$COMMANDS" | sed 's|-i ../qt-everywhere|-i ../../qt-everywhere|g')

    log "Fixing unterminated find -exec in qt6 BLFS commands..."
    # BLFS qt6 page has: find /opt/qt6 ... -exec ... {} without \; or +
    # Add \; to any -exec that ends the line without a terminator.
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/(-exec\s+\S+.*?\{\}\s*)$/\1 \\;/g')

    log "Skipping qtopcua submodule in qt6 to bypass OpenSSL ASN1_TIME opaque compatibility compilation error..."
    COMMANDS=$(echo "$COMMANDS" | sed 's/rm -rf qtwebengine qt3d qtquick3dphysics/rm -rf qtwebengine qt3d qtquick3dphysics qtopcua/g')
    if [[ ! "$COMMANDS" =~ "qtopcua" ]]; then
        COMMANDS=$(echo "$COMMANDS" | sed 's|\./configure |rm -rf qtopcua \&\& \./configure |g')
    fi
    log "Applying qsslsocket_openssl_symbols.cpp OpenSSL 4.0 const-return type patches..."
    PATCH_CMD='perl -0777 -pi -e '\''s/reinterpret_cast<const char \*>\(auth_key->keyid->data\),\s*auth_key->keyid->length/reinterpret_cast<const char *>(q_ASN1_STRING_get0_data(auth_key->keyid)), q_ASN1_STRING_length(auth_key->keyid)/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/\*reinterpret_cast<quint32 \*>\(genName->d\.iPAddress->data\)/*reinterpret_cast<const quint32 *>(q_ASN1_STRING_get0_data(genName->d.iPAddress))/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/reinterpret_cast<quint8 \*>\(genName->d\.iPAddress->data\)/reinterpret_cast<const quint8 *>(q_ASN1_STRING_get0_data(genName->d.iPAddress))/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/hexString\.reserve\(serialNumber->length \* 3\);/const int len = q_ASN1_STRING_length(serialNumber); const unsigned char *data = q_ASN1_STRING_get0_data(serialNumber); hexString.reserve(len * 3);/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/for \(int a = 0; a < serialNumber->length; \+\+a\)/for (int a = 0; a < len; ++a)/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/serialNumber->data\[a\]/data[a]/g'\'' qtbase/src/plugins/tls/openssl/qx509_openssl.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC2\(X509_NAME_ENTRY \*, X509_NAME_get_entry, X509_NAME \*a, a, int b, b, return nullptr, return\)\s*\n\s*DEFINEFUNC\(ASN1_STRING \*, X509_NAME_ENTRY_get_data, X509_NAME_ENTRY \*a, a, return nullptr, return\)\s*\n\s*DEFINEFUNC\(ASN1_OBJECT \*, X509_NAME_ENTRY_get_object, X509_NAME_ENTRY \*a, a, return nullptr, return\)/#if !defined\(QT_LINKED_OPENSSL\)\ntypedef const X509_NAME_ENTRY *(*_q_PTR_X509_NAME_get_entry)(const X509_NAME *a, int b);\nstatic _q_PTR_X509_NAME_get_entry _q_X509_NAME_get_entry = nullptr;\nQT_OPENSSL4_CONST X509_NAME_ENTRY *q_X509_NAME_get_entry(const X509_NAME *a, int b) {\n    if (Q_UNLIKELY(!_q_X509_NAME_get_entry)) {\n        qsslSocketUnresolvedSymbolWarning("X509_NAME_get_entry");\n        return nullptr;\n    }\n    return const_cast<X509_NAME_ENTRY *>(_q_X509_NAME_get_entry(a, b));\n}\n\ntypedef const ASN1_STRING *(*_q_PTR_X509_NAME_ENTRY_get_data)(const X509_NAME_ENTRY *a);\nstatic _q_PTR_X509_NAME_ENTRY_get_data _q_X509_NAME_ENTRY_get_data = nullptr;\nQT_OPENSSL4_CONST ASN1_STRING *q_X509_NAME_ENTRY_get_data(const X509_NAME_ENTRY *a) {\n    if (Q_UNLIKELY(!_q_X509_NAME_ENTRY_get_data)) {\n        qsslSocketUnresolvedSymbolWarning("X509_NAME_ENTRY_get_data");\n        return nullptr;\n    }\n    return const_cast<ASN1_STRING *>(_q_X509_NAME_ENTRY_get_data(a));\n}\n\ntypedef const ASN1_OBJECT *(*_q_PTR_X509_NAME_ENTRY_get_object)(const X509_NAME_ENTRY *a);\nstatic _q_PTR_X509_NAME_ENTRY_get_object _q_X509_NAME_ENTRY_get_object = nullptr;\nQT_OPENSSL4_CONST ASN1_OBJECT *q_X509_NAME_ENTRY_get_object(const X509_NAME_ENTRY *a) {\n    if (Q_UNLIKELY(!_q_X509_NAME_ENTRY_get_object)) {\n        qsslSocketUnresolvedSymbolWarning("X509_NAME_ENTRY_get_object");\n        return nullptr;\n    }\n    return const_cast<ASN1_OBJECT *>(_q_X509_NAME_ENTRY_get_object(a));\n}\n#else\nQT_OPENSSL4_CONST X509_NAME_ENTRY *q_X509_NAME_get_entry(const X509_NAME *a, int b) {\n    return const_cast<X509_NAME_ENTRY *>(X509_NAME_get_entry(a, b));\n}\nQT_OPENSSL4_CONST ASN1_STRING *q_X509_NAME_ENTRY_get_data(const X509_NAME_ENTRY *a) {\n    return const_cast<ASN1_STRING *>(X509_NAME_ENTRY_get_data(a));\n}\nQT_OPENSSL4_CONST ASN1_OBJECT *q_X509_NAME_ENTRY_get_object(const X509_NAME_ENTRY *a) {\n    return const_cast<ASN1_OBJECT *>(X509_NAME_ENTRY_get_object(a));\n}\n#endif/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -pi -e '\''s/\{ funcret func\(([^)]*)\); \}/{ funcret (ret)func($1); }/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC2\(X509_EXTENSION \*, X509_get_ext, X509 \*a, a, int b, b, return nullptr, return\)/DEFINEFUNC2(const X509_EXTENSION *, X509_get_ext, X509 *a, a, int b, b, return nullptr, return)/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(X509_NAME \*, X509_get_issuer_name, X509 \*a, a, return nullptr, return\)/DEFINEFUNC(const X509_NAME *, X509_get_issuer_name, X509 *a, a, return nullptr, return)/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(X509_NAME \*, X509_get_subject_name, X509 \*a, a, return nullptr, return\)/DEFINEFUNC(const X509_NAME *, X509_get_subject_name, X509 *a, a, return nullptr, return)/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(int, X509_NAME_entry_count, X509_NAME \*a, a,/DEFINEFUNC(int, X509_NAME_entry_count, const X509_NAME *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(int, X509_NAME_entry_count, X509_NAME \*a, a,/DEFINEFUNC(int, X509_NAME_entry_count, const X509_NAME *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC\(ASN1_OBJECT \*, X509_EXTENSION_get_object, X509_EXTENSION \*a, a,/DEFINEFUNC(const ASN1_OBJECT *, X509_EXTENSION_get_object, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(ASN1_OBJECT \*, X509_EXTENSION_get_object, X509_EXTENSION \*a, a,/DEFINEFUNC(const ASN1_OBJECT *, X509_EXTENSION_get_object, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC\(int, X509_EXTENSION_get_critical, X509_EXTENSION \*a, a,/DEFINEFUNC(int, X509_EXTENSION_get_critical, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(int, X509_EXTENSION_get_critical, X509_EXTENSION \*a, a,/DEFINEFUNC(int, X509_EXTENSION_get_critical, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC\(ASN1_OCTET_STRING \*, X509_EXTENSION_get_data, X509_EXTENSION \*a, a,/DEFINEFUNC(const ASN1_OCTET_STRING *, X509_EXTENSION_get_data, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(ASN1_OCTET_STRING \*, X509_EXTENSION_get_data, X509_EXTENSION \*a, a,/DEFINEFUNC(const ASN1_OCTET_STRING *, X509_EXTENSION_get_data, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC\(const X509V3_EXT_METHOD \*, X509V3_EXT_get, X509_EXTENSION \*a, a,/DEFINEFUNC(const X509V3_EXT_METHOD *, X509V3_EXT_get, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(const X509V3_EXT_METHOD \*, X509V3_EXT_get, X509_EXTENSION \*a, a,/DEFINEFUNC(const X509V3_EXT_METHOD *, X509V3_EXT_get, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h
perl -0777 -pi -e '\''s/DEFINEFUNC\(void \*, X509V3_EXT_d2i, X509_EXTENSION \*a, a,/DEFINEFUNC(void *, X509V3_EXT_d2i, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp
perl -0777 -pi -e '\''s/DEFINEFUNC\(void \*, X509V3_EXT_d2i, X509_EXTENSION \*a, a,/DEFINEFUNC(void *, X509V3_EXT_d2i, const X509_EXTENSION *a, a,/g'\'' qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols_p.h'
    COMMANDS="${PATCH_CMD}
${COMMANDS}"
fi

# Force any xmlcatalog commands that write to /etc/xml/ into a root block.
# The docbook-xsl-nons BLFS page puts the final xmlcatalog registration commands in
# a <userinput> (user) block, but /etc/xml/catalog is root-owned.  Re-annotate those
# lines as root so the build script wraps them in 'as_root bash << ROOTEOF'.
if [[ "${PACKAGE,,}" == "docbook-xsl-nons" || "${PACKAGE,,}" == "docbook-xsl" || "${PACKAGE,,}" == "docbook-xml" ]]; then
    log "Applying docbook: forcing xmlcatalog /etc/xml writes to run as root..."
    # Replace any user-block xmlcatalog call touching /etc/xml with a root-wrapped equivalent.
    COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{(# __BEGIN_USER__\n)((?:(?!# __END_USER__|# __BEGIN_USER__).)*)(# __END_USER__\n)}{my ($open,$body,$close) = ($1,$2,$3); my @lines = split /\n/, $body; my @root_lines; my @user_lines; for my $l (@lines) { if ($l =~ /xmlcatalog/ && $l =~ m{/etc/xml}) { push @root_lines, $l; } else { push @user_lines, $l; } } my $result = ""; if (@user_lines) { $result .= "# __BEGIN_USER__\n" . join("\n", @user_lines) . "\n# __END_USER__\n"; } if (@root_lines) { $result .= "# __BEGIN_ROOT__\n" . join("\n", @root_lines) . "\n# __END_ROOT__\n"; } $result}gse')
fi

if [[ "$PACKAGE" == "appstream" ]]; then
    log "Enabling Qt6 support in appstream (required for KDE Discover / AppStreamQt)..."
    COMMANDS=$(echo "$COMMANDS" | sed 's/meson setup /meson setup -D qt=true /g')
    log "Patching appstream docs to use docbook-xsl-nons instead of docbook-xsl-ns..."
    COMMANDS=$(echo "$COMMANDS" | sed -E 's@(meson setup)@sed -i "s|xsl-ns/current|xsl/current|g" docs/meson.build 2>/dev/null || true\n\1@g')
fi

if [[ "$PACKAGE" == "glycin" ]]; then
    log "Enabling GTK4 support in glycin (required for Nautilus 50.0+)..."
    COMMANDS=$(echo "$COMMANDS" | sed 's/-D libglycin-gtk4=false/-D libglycin-gtk4=true/g')
fi

if [[ "$PACKAGE" == "nautilus" ]]; then
    log "Disabling SELinux support in nautilus (fix missing dependency)..."
    COMMANDS=$(echo "$COMMANDS" | sed 's/meson setup /meson setup -D selinux=false /g; s/meson setup \.\./meson setup -D selinux=false \.\./g')
fi

if [[ "$PACKAGE" == "pango" ]]; then
    log "Applying pango upstream fix: removing obsolete man-pages and documentation options..."
    # The upstream version of Pango has altered/removed 'man-pages' option causing meson configure to fail.
    # We will safely strip out the separate meson configure doc-building steps altogether.
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/meson configure -D (man-pages|documentation)=(true|enabled)[[:space:]]*&&?//g')
    COMMANDS=$(echo "$COMMANDS" | sed '/docs_dir =/d')
fi

if [[ "$PACKAGE" == "mesa" ]]; then
    log "Filtering out erroneous 'Force probe' kernel config text from Mesa build commands..."
    COMMANDS=$(echo "$COMMANDS" | grep -vE "Force probe")
fi

if [[ "$PACKAGE" == "gjs" ]]; then
    log "Applying gjs gi/info.h patch: fixing gi_callable_info_get_closure_native_address return type (void** -> void*)..."
    # In newer gobject-introspection, gi_callable_info_get_closure_native_address() returns void* (not void**).
    # gjs 1.86 still declares its wrapper returning void**, causing a -fpermissive error at compile time.
    # Fix: change the declared return type of closure_native_address() in gi/info.h to void*.
    COMMANDS="sed -i 's/void\\*\\* closure_native_address/void* closure_native_address/g' gi/info.h
${COMMANDS}"
fi

if [[ "$PACKAGE" == "libpng" ]]; then
    log "Enabling APNG support for libpng (required by Firefox)..."
    # Dynamically extract the APNG patch URL from the page to ensure version alignment
    APNG_PATCH_URL=$(echo "$HTML_CONTENT" | perl -nle 'print $1 if /href="(https?:\/\/[^"]+apng\.patch\.gz)"/i' | head -n 1)
    if [[ -n "$APNG_PATCH_URL" ]]; then
        DOWNLOAD_URLS+=("$APNG_PATCH_URL")
        APNG_PATCH_FILE=$(basename "$APNG_PATCH_URL")
        # Ensure the patch command is present in the build script and non-interactive
        if [[ ! "$COMMANDS" =~ "apng.patch.gz" ]]; then
            COMMANDS="as_root bash -c \"zcat /sources/archives/${APNG_PATCH_FILE} | patch -p1 -N -f || true\"
${COMMANDS}"
        fi
    fi
fi

if [[ "$PACKAGE" == "colord" ]] || [[ "$PACKAGE" == "colord-gtk" ]]; then
    COMMANDS=$(echo "$COMMANDS" | sed 's/man=true/man=false/g')
fi

# systemd uses xsltproc + docbook-xsl to generate man pages via ninja.
# This is unreliable without a perfectly configured XML catalog, so we
# unconditionally disable man-page generation to ensure build stability.
if [[ "${PACKAGE,,}" == "systemd" ]]; then
    log "[INFO] Unconditionally disabling systemd man-page generation (-Dman=false) to prevent xsltproc/docbook-xsl failures."
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/-D[[:space:]]*man=(auto|true|enabled)/-Dman=false/g')
    # If there was no man= flag at all, inject it after 'meson setup'
    if ! echo "$COMMANDS" | grep -q -- "-Dman=false"; then
        COMMANDS=$(echo "$COMMANDS" | sed 's/meson setup /meson setup -Dman=false /g')
    fi
    # Also strip any standalone 'ninja man' or 'make man' targets just in case
    COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{^(as_root[[:space:]]+)?(ninja|make)[[:space:]]+man\b.*?(\n|&&)}{}gm')
fi

if [[ "$PACKAGE" == "rustc" ]]; then
    log "Applying rustc post-install fix: creating /etc/profile.d/rustc.sh and removing 'source' call."
    # The BLFS book has a heredoc that creates /etc/profile.d/rustc.sh, but we skip
    # heredoc config blocks. Create it explicitly so the 'source' call doesn't fail.
    # Note: we use 'export PATH=' instead of 'pathprepend' (LFS-specific function not
    # available in plain shell environments).
    SETUP_COMMANDS+='
as_root bash -c "mkdir -p /etc/profile.d && printf '"'"'# Begin /etc/profile.d/rustc.sh\nexport PATH=/opt/rustc/bin:$PATH\n# End /etc/profile.d/rustc.sh\n'"'"' > /etc/profile.d/rustc.sh"
'
    # Strip the 'source /etc/profile.d/rustc.sh' line — it updates PATH for the interactive
    # user session but is irrelevant (and breaks) during an automated build script.
    COMMANDS=$(echo "$COMMANDS" | grep -v "source /etc/profile.d/rustc.sh")

    # Patch vendored openssl-sys to accept OpenSSL 4.x.
    # openssl-sys <=0.9.111 hard-errors if it detects OpenSSL >= 4.0 (version_number >= 0x40000000).
    # The system has OpenSSL 4.0 installed, so we patch the version check in the vendored crate
    # to extend the acceptable range.  We inject these commands just before ./x.py build.
    OPENSSL_SYS_PATCH='
# Patch vendored openssl-sys to accept OpenSSL 4.x (system has 4.0, openssl-sys 0.9.x caps at 3.x)
# The relevant check in build/main.rs (openssl-sys 0.9.111) is:
#   if openssl_version >= 0x4_00_00_00_0 {
#       version_error()
#   } else if openssl_version >= 0x3_00_00_00_0 {
#       Version::Openssl3xx
# We patch it to treat 4.x the same as 3.x by changing the panic branch to return Openssl3xx.
# Patch every copy of openssl-sys/build/main.rs on the system:
# - vendor/ inside the source tree (used by cargo --frozen)
# - /rust/deps/ (cargo pre-populated registry used by the bootstrap compiler)
# - any other cargo registries on the machine
for _search_root in . /rust/deps /rust/registry /root/.cargo/registry /home/fusion809/.cargo/registry; do
    find "$_search_root" -path "*/openssl-sys*/build/main.rs" 2>/dev/null
done | sort -u | while read -r OSSL_SYS_MAIN; do
    echo "[LFS-AUTOBUILD] Patching $OSSL_SYS_MAIN to accept OpenSSL 4.x..."
    # Patch the OpenSSL 4.x rejection gate — handle any underscore layout the crate may use
    sed -i "s/openssl_version >= 0x4_00_00_00_0/openssl_version >= 0x5_00_00_00_0/g" "$OSSL_SYS_MAIN"
    sed -i "s/openssl_version >= 0x4000_0000/openssl_version >= 0x5000_0000/g" "$OSSL_SYS_MAIN"
    sed -i "s/openssl_version >= 0x4_0000_0000/openssl_version >= 0x5_0000_0000/g" "$OSSL_SYS_MAIN"
    # Fallback: use sed to catch any remaining hex literal >= 0x4... pattern near version_error
    sed -i -E "s/openssl_version[[:space:]]*>=[[:space:]]*0x4[0-9a-fA-F_]+/openssl_version >= 0x5_00_00_00_0/g" "$OSSL_SYS_MAIN"
    # Add ossl400/ossl410 cfg gates so code guarded by those cfgs compiles cleanly
    sed -i "/rustc-check-cfg=cfg(ossl350)/a\\    println!(\"cargo:rustc-check-cfg=cfg(ossl400)\");\n    println!(\"cargo:rustc-check-cfg=cfg(ossl410)\");" "$OSSL_SYS_MAIN"
    # Also handle variant where ossl400 cfg is declared differently in 0.9.112
    if ! grep -q 'ossl400' "$OSSL_SYS_MAIN"; then
        sed -i "/rustc-check-cfg=cfg(ossl3[0-9][0-9])/a\\    println!(\"cargo:rustc-check-cfg=cfg(ossl400)\");\n    println!(\"cargo:rustc-check-cfg=cfg(ossl410)\");" "$OSSL_SYS_MAIN" 2>/dev/null || true
    fi

    # Update cargo checksum for patched main.rs so cargo does not fail the build
    _checksum=$(sha256sum "$OSSL_SYS_MAIN" | cut -d " " -f 1)
    _checksum_file="$(dirname "$(dirname "$OSSL_SYS_MAIN")")/.cargo-checksum.json"
    if [ -f "$_checksum_file" ]; then
        sed -i "s|\"build/main.rs\":\"[0-9a-f]*\"|\"build/main.rs\":\"$_checksum\"|" "$_checksum_file"
        echo "[LFS-AUTOBUILD] Updated cargo checksum in $_checksum_file"
    fi

    echo "[LFS-AUTOBUILD] openssl-sys patch applied to $OSSL_SYS_MAIN."
done
'
    SETUP_COMMANDS+="$OPENSSL_SYS_PATCH"
fi

if [[ "$PACKAGE" == "qca" ]]; then
    log "Applying qca OpenSSL 4.x compatibility patch: replacing removed SSLv3_client_method..."
    # SETUP_COMMANDS runs from the source root (before mkdir build && cd build),
    # so find . correctly locates plugins/qca-ossl/qca-ossl.cpp.
    # The COMMANDS injection ran from inside build/ where the file doesn't exist.
    SETUP_COMMANDS+="
export LC_ALL=en_US.utf8
echo '[LFS-AUTOBUILD] Patching qca-ossl.cpp for OpenSSL 4.x...'
find . -name 'qca-ossl.cpp' | xargs -r sed -i \\
    -e 's/SSLv3_client_method()/TLS_client_method()/g' \\
    -e 's/SSLv3_server_method()/TLS_server_method()/g' \\
    -e 's/SSLv3_method()/TLS_method()/g' \\
    -e 's/.*X509_EXTENSION \*ex = X509_CRL_get_ext/            const X509_EXTENSION *ex = X509_CRL_get_ext/g'
echo '[LFS-AUTOBUILD] qca-ossl.cpp patch done.'
"
    # QCA's cmake uses execute_process to query Qt6/qmake for install dirs; those
    # calls return values with trailing newlines which corrupt the generated flags.make
    # (cmake warns 'Value of QCA_*_INSTALL_DIR contained a newline; truncating').
    # Fix: explicitly supply all QCA install path variables so cmake never queries qmake.
    log "Injecting explicit QCA cmake install-dir overrides to prevent newline corruption in flags.make."
    COMMANDS=$(echo "$COMMANDS" | sed 's|cmake |cmake -D QCA_FEATURE_INSTALL_DIR=/usr/lib/cmake/Qca-Qt6 -D QCA_INCLUDE_INSTALL_DIR=/usr/include -D QCA_LIBRARY_INSTALL_DIR=/usr/lib -D QCA_PLUGINS_INSTALL_DIR=/usr/lib/qca-qt6 -D QCA_PREFIX_INSTALL_DIR=/usr -D QCA_PRIVATE_INCLUDE_INSTALL_DIR=/usr/include/Qca-Qt6 |g')
fi

if [[ "$PACKAGE" == "qt6" ]]; then
    log "Applying Qt6 OpenSSL 4.0 compatibility patch: force QT_OPENSSL4_CONST empty..."
    # Qt6 defines QT_OPENSSL4_CONST=const when OPENSSL_VERSION_MAJOR>=4 in qopenssl_p.h.
    # The DEFINEFUNC macro bodies in the .cpp file use non-const signatures, causing
    # 'ambiguating new declaration' errors. Force QT_OPENSSL4_CONST to empty so all
    # declarations match the non-const definitions.
    # Inject before the cmake configure step (Qt6 uses cmake, not ./configure).
    COMMANDS=$(echo "$COMMANDS" | sed 's|cmake |sed -i "s/#define QT_OPENSSL4_CONST const/#define QT_OPENSSL4_CONST/g" qtbase/src/plugins/tls/openssl/qopenssl_p.h \&\& rm -f qtbase/src/plugins/tls/openssl/qsslsocket_openssl_symbols.cpp.rej \&\& cmake |g')

    log "Applying Qt6: fix broken 'find -exec' syntax from BLFS page scraping..."
    # The BLFS page has a find command to strip build dirs from .prl files.
    # The scraper sometimes mangles the escaped semicolon — use perl for robust replacement
    # to avoid \* triggering sed's 'unknown option to s' error.
    COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's@find (\$QT6PREFIX|/opt/qt6)/ -name \Q\*.prl\E(?:\s*\\\n)?\s*-exec .*?\{\}(?: \\;| \\)?@find \$QT6PREFIX/ -name '"'"'*.prl'"'"' -exec sed -i -e '"'"'/^QMAKE_PRL_BUILD_DIR/d'"'"' {} \\; \|\| true@gs')
fi

if [[ "$PACKAGE" == "gnome-shell" || "$PACKAGE" == "gnome-session" || "$PACKAGE" == "mutter" ]]; then
    log "Applying GCC 14/15 incompatible-pointer-types fix..."
    SETUP_COMMANDS+="export CFLAGS=\"\${CFLAGS} -Wno-error=incompatible-pointer-types\"
export CXXFLAGS=\"\${CXXFLAGS} -Wno-error=incompatible-pointer-types\"
"
fi

if [[ "$PACKAGE" == "mutter" ]]; then
    log "Stripping dummy session launch commands from Mutter..."
    # Remove all mutter session launch lines (both variants from the BLFS page):
    #   mutter --wayland -- vte-2.91
    #   MUTTER_DEBUG_DUMMY_MODE_SPECS=... dbus-run-session mutter --wayland --devkit -- vte-2.91
    COMMANDS=$(echo "$COMMANDS" | grep -vE '(mutter --wayland|dbus-run-session mutter|MUTTER_DEBUG_DUMMY_MODE_SPECS)')
fi

if [[ "$PACKAGE" == "gnome-session" ]]; then
    log "Applying gnome-session doc-dir mv guard (docs may not be installed)..."
    # BLFS book has: mv -v /usr/share/doc/gnome-session{,-VERSION}
    # When docs are disabled the directory won't exist and mv fails hard.
    COMMANDS=$(echo "$COMMANDS" | sed 's|mv -v /usr/share/doc/gnome-session{|[ -d /usr/share/doc/gnome-session ] \&\& mv -v /usr/share/doc/gnome-session{|g')
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's|(\[ -d /usr/share/doc/gnome-session \] && mv -v /usr/share/doc/gnome-session\{[^}]+\})|$1 \|\| true|g')

    COMMANDS+="
    # Create wrapper to prevent 'A graphical session is already running' crash on Wayland
    as_root bash -c \"cat > /usr/bin/gnome-session-sddm-wrapper << 'EOF'
#!/bin/bash
systemctl --user stop graphical-session.target graphical-session-pre.target 2>/dev/null || true
systemctl --user reset-failed 2>/dev/null || true
exec /usr/bin/gnome-session \\\"\\\$@\\\"
EOF\"
    as_root chmod +x /usr/bin/gnome-session-sddm-wrapper
    as_root sed -i 's|^Exec=/usr/bin/gnome-session|Exec=/usr/bin/gnome-session-sddm-wrapper|g' /usr/share/wayland-sessions/gnome.desktop /usr/share/wayland-sessions/gnome-wayland.desktop 2>/dev/null || true
    "
fi

if [[ "$PACKAGE" == "gdm" ]]; then
    log "Applying gdm install patches for symlink conflicts and terminal-less su execution..."
    # 1. ln -s fails if 61-gdm.rules exists, change to ln -sf
    COMMANDS=$(echo "$COMMANDS" | sed 's|ln -s /dev/null /etc/udev/rules.d/61-gdm.rules|ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules|g')
    # 2. su gdm fails with 'must be run from a terminal' when inside the su -c "..." user block.
    # We replace it with 'sudo -u gdm' to bypass the password prompt securely.
    COMMANDS=$(echo "$COMMANDS" | sed 's|su gdm -s /bin/bash|sudo -u gdm bash|g')
fi

if [[ "$PACKAGE" == "gpm" ]]; then
    log "Applying GPM-specific build fixes (skipping documentation)..."
    # Ensure make only runs in src to avoid documentation failures
    COMMANDS=$(echo "$COMMANDS" | sed 's/\bmake\b/make -C src/g')
    # Remove lines related to documentation formats we are skipping
    COMMANDS=$(echo "$COMMANDS" | sed -E '/(INPUT|dvipdfm)/d')
fi


if [[ "$PACKAGE" == "krb5" || "$PACKAGE" == "mitkrb" || "$PACKAGE" == "elfutils" ]]; then
    log "Applying GCC 15 compatibility fix for $PACKAGE"
    # Create a GCC wrapper to strip -Werror flags on the fly
    MOCK_GCC_DIR="/tmp/mock_gcc"
    SETUP_COMMANDS+="
as_root mkdir -p \"$MOCK_GCC_DIR\"
as_root bash -c \"echo '#!/bin/bash' > $MOCK_GCC_DIR/gcc\"
as_root bash -c \"echo 'REAL_GCC=\\\$(which -a gcc | grep -v mock_gcc | head -n 1)' >> $MOCK_GCC_DIR/gcc\"
as_root bash -c \"echo '[ -z \\\"\\\$REAL_GCC\\\" ] && REAL_GCC=/usr/bin/gcc' >> $MOCK_GCC_DIR/gcc\"
as_root bash -c \"echo 'ARGS=()' >> $MOCK_GCC_DIR/gcc\"
as_root bash -c \"echo 'for arg in \\\"\\\$@\\\"; do [[ \\\"\\\$arg\\\" == -Werror* ]] && continue; ARGS+=(\\\"\\\$arg\\\"); done' >> $MOCK_GCC_DIR/gcc\"
as_root bash -c \"echo 'exec \\\"\\\$REAL_GCC\\\" \\\"\\\${ARGS[@]}\\\"' >> $MOCK_GCC_DIR/gcc\"
as_root chmod +x \"$MOCK_GCC_DIR/gcc\"
export PATH=\"$MOCK_GCC_DIR:\$PATH\"
"
fi

if [[ "${PACKAGE,,}" == "libqalculate" ]]; then
    log "Applying libqalculate documentation install fix: neutralizing docs directory..."
    # Neutralize the docs directory in the top-level Makefile to prevent install failures
    COMMANDS=$(echo "$COMMANDS" | sed '/^\.\/configure/a sed -i "s/docs//g" Makefile')
fi

if [[ "$PACKAGE" == "groff" ]]; then
    log "Fixing groff paper size redirect bug and X11 link loop"
    # 1. Replace <paper_size> with A4
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/<paper_size>/A4/g')
    # 2. Add pre-install fix to break symlink loop for /usr/lib/X11
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/(make install)/[ -L \/usr\/lib\/X11 ] \&\& as_root rm -vf \/usr\/lib\/X11; $1/g')
fi

if [[ "$ENABLE_DOC_BUILD" == "false" ]]; then
    # 1. Flip existing meson/configure flags
    # 1. Flip existing meson/configure/cmake flags
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/-D (docs?|documentation|gtk_doc|BUILD_DOCS|ENABLE_DOCS|BUILD_DOCUMENTATION)=(enabled|true|ON)/-D $1=disabled/g; s/--enable-(docs|gtk-doc|doxygen-docs)/--disable-$1/g')
    
    # 2. Universal injection for Autotools (Safe flags only)
    if [[ "$COMMANDS" == *"./configure"* || "$COMMANDS" == *"../configure"* ]]; then
        # Use --disable-doc and --disable-docs to cover more packages.
        # ffmpeg is the exception that fails on unknown flags; it only supports --disable-doc.
        if [[ "$PACKAGE" == "ffmpeg" ]]; then
            COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's/(\.\/?\.\/configure\b)/$1 --disable-doc/g')
        else
            COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's/(\.\/?\.\/configure\b)/$1 --disable-doc --disable-docs/g')
        fi
    fi
    
    if [[ "$ENABLE_DOC_BUILD" == "false" ]]; then
        # 1. Strip pushd doc / popd blocks entirely
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{pushd[[:space:]]+(\.\.\/|doc).*?popd([[:space:]]*&&[[:space:]]*)?}{}gs')
        
        # 2. Strip standalone targets for make/ninja
        # PROTECT: Use lookbehind to avoid variables like $docdir
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{^(as_root[[:space:]]+)?(make|ninja)[[:space:]]+.*(?<!\$)\b(pdf|ps|dvi|html|info|manual|doc|docs|man|doxygen)\b.*?(\n|&&)}{}gm')
        
        # 3. Strip direct calls to doc tools
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{^(as_root[[:space:]]+)?((.*\/)?(doxygen|makeinfo|asciidoc|xmlto|texi2[a-z]+|pdf2[a-z]+))([[:space:]]|$).*?(\n|&&)}{}gm')
        
        # 4. Strip manual copies/installs of doc files
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's{^(?!.*?(make install|tools\/))[[:space:]]*(cp|install|chmod|find).*?(doc\/|api\/|doxy\/|HTML\/|/usr/share/doc/).*?(\n|&&)}{}gm')
    fi
    # Also catch and neutralize specific doc building tools and python scripts in doc/
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/(^|[;|&])[[:space:]]*(doxygen|texi2html|texi2pdf|texi2dvi|makeinfo|pdflatex|xelatex|lualatex|asciidoc|xmlto|asciidoctor|xmlproc|docbook2x)([^a-zA-Z0-9_-]|$)/\1true \3/g')
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/\bpython3?[[:space:]]+doc\/[a-zA-Z0-9_-]+\.py\b/true /g')
    # Optional: neutralize test commands that might fail and kill the build
    if [[ "$SKIP_TESTS" == "true" ]]; then
        # Remove make check/test, ninja test, meson test, pytest
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/^(as_root[[:space:]]+)?(make|ninja)[[:space:]]+(check|test).*$//gm')
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/^(as_root[[:space:]]+)?meson[[:space:]]+test.*$//gm')
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/^(as_root[[:space:]]+)?python3?[[:space:]]+-m[[:space:]]+pytest.*$//gm')
    elif [[ "$IGNORE_TEST_FAILURES" == "true" ]] || [[ "${PACKAGE,,}" == "glibc" ]]; then
        # Always ignore test failures for glibc, or when explicitly requested
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/\b(make|ninja)[[:space:]]+(check|test)\b/& || true/g')
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/\bmeson[[:space:]]+test\b/& || true/g')
        COMMANDS=$(echo "$COMMANDS" | sed -E 's/python3?[[:space:]]+-m[[:space:]]+pytest/& || true/g')
    elif [[ "${PACKAGE,,}" != "glibc" ]]; then
        # By default, do nothing (tests will run and fail the build if they fail)
        # Note: Previous default was to remove tests. To keep the old default behavior, 
        # you would uncomment the removal logic here. But since the user asked for an option 
        # to ignore test failures, it implies they expect tests to run by default now.
        :
    fi
fi

# 2.9.5 Final cleanup of dangling separators before markers or EOF
# This ensures that stripping docs doesn't leave trailing && at the end of a heredoc block
COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe '
    # Remove trailing && (and optional line continuations) from all lines to enforce sequential execution
    # This prevents failures in left-side commands of an AND-list from being ignored by set -e.
    s/[ \t]*&&[ \t]*\\?[ \t]*$//mg;
    s/\s*(&&|\|\||;)\s*(\n\s*?#?\s*?(__END_(ROOT|USER)__|___BLOCK_END___))/\n$2/gs;
    s/\s*(&&|\|\||;)\s*(\n\s*?#?\s*?(__BEGIN_(ROOT|USER)__|___BLOCK_START_))/\n$2/gs;
    s/\s*(&&|\|\||;)\s*$//gs;
    # 2. Remove empty blocks or blocks only containing stripped pushd fragments
    s/\s*___BLOCK_START_(USER|ROOT)___\s*(pushd\s+\.\.)?\s*___BLOCK_END___//gs;
')

# 2.9.6 Universal DESTDIR inventory tracking for make/ninja/pip install (non-loop)
# This ensures "Up-to-date" files are captured. If DESTDIR is present, we ALSO capture from it.
COMMANDS=$(echo "$COMMANDS" | awk -v PKG="$PACKAGE" '
    # Guard against function definitions (e.g. do_install() { ... })
    /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ { print; next }
    /^[[:space:]]*([A-Z_]+=.*[[:space:]]+)*(make|ninja|pip3).*install/ {
        if (!($0 ~ /book-packages/)) {
            print "echo \"[LFS-AUTOBUILD] Staging installation for full inventory...\""
            print "DDIR=\"/tmp/destdir_" PKG "\""
            print "rm -rf \"$DDIR\" && mkdir -p \"$DDIR\""
            
            # 1. Run staging install (our own DESTDIR)
            if ($0 ~ /make.*install/) {
                cmd = $0; sub(/DESTDIR=[^ ]+ /, "", cmd); sub(/ --root=[^ ]+ /, "", cmd);
                gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                print cmd " DESTDIR=\"$DDIR\" || true"
            } else if ($0 ~ /ninja.*install/) {
                cmd = $0; sub(/DESTDIR=[^ ]+ /, "", cmd);
                gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                print "DESTDIR=\"$DDIR\" " cmd " || true"
            } else if ($0 ~ /pip3.*install/) {
                cmd = $0; sub(/--root=[^ ]+ /, "", cmd);
                gsub(/ *([|][|]|&&|;).*$/, "", cmd);
                print cmd " --root=\"$DDIR\" --ignore-installed --no-deps || true"
            }
            
            # 2. Run the original command as intended
            real_cmd = $0;
            if (real_cmd ~ /pip3.*install/ && real_cmd !~ /ignore-installed/) {
                sub(/pip3[[:space:]]+install/, "pip3 install --ignore-installed", real_cmd);
            }
            print real_cmd

            # 3. Record from our staging
            print "if [ -d \"$DDIR\" ] && [ \"$(ls -A \"$DDIR\" 2>/dev/null)\" ]; then"
            print "  sudo mkdir -p \"/var/lib/book-packages\" \"/var/lib/custom-packages\""
            print "  find \"$DDIR\" -mindepth 1 -printf \"/%P\\n\" | sudo tee -a \"/var/lib/book-packages/" PKG "\" > /dev/null"
            print "  sudo rm -rf \"$DDIR\""
            print "fi"
            
            # 4. If the ORIGINAL command had its own DESTDIR/root, also capture from there!
            if ($0 ~ /DESTDIR=/ || $0 ~ /--root=/) {
                # Extract value safely using awk instead of fragile echo
                split($0, parts, "DESTDIR=");
                if (length(parts) < 2) split($0, parts, "--root=");
                if (length(parts) >= 2) {
                    split(parts[2], val_parts, " ");
                    destdir = val_parts[1];
                    # Remove surrounding quotes and trailing operators
                    gsub(/^["\x27]|["\x27]$|[&|;]+$/, "", destdir);
                    if (destdir != "") {
                        print "echo \"[LFS-AUTOBUILD] Detected existing DESTDIR/root: " destdir ". Capturing files...\""
                        print "if [ -d \"" destdir "\" ]; then"
                        print "  find \"" destdir "\" -type f -o -type l | sed \"s|^" destdir "||\" | sudo tee -a \"/var/lib/book-packages/" PKG "\" > /dev/null"
                        print "fi"
                    }
                }
            }
            next
        }
    }
    { print }
')

# 2.10 ensure XORG_PREFIX and XORG_CONFIG are set if referenced in commands (case-insensitive to catch patch names)
shopt -s nocasematch
if [[ "$COMMANDS" =~ "xorg_prefix" || "$COMMANDS" =~ "xorg_config" || "$COMMANDS" =~ "XORG_PREFIX" || "$COMMANDS" =~ "XORG_CONFIG" ]]; then
    if [[ ! "$COMMANDS" =~ "export XORG_PREFIX=/usr" ]]; then
        SETUP_COMMANDS+="export XORG_PREFIX=/usr
export XORG_CONFIG=\"--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static\"
"
    fi
    # AESTHETIC FIX: Prevent recursive symlink loops if XORG_PREFIX is /usr
    # Strips commands like: ln -sv $XORG_PREFIX/lib/X11 /usr/lib/X11
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/^[[:space:]]*ln -sv? \$XORG_PREFIX\/(lib|include)\/X11 \/usr\/\1\/X11.*$//g')
fi
shopt -u nocasematch

# Special handling for Xorg multi-package targets (libs, apps, fonts, drivers)
if [[ "$XORG_MULTI_MODE" == "true" ]]; then
    log "Enabling Xorg multi-package loop mode."

    # Pre-fix relative MD5 paths for Xorg as well
    COMMANDS=$(echo "$COMMANDS" | sed -E 's|\.\./[a-z0-9.-]+\.md5|/sources/archives/&|g; s|/sources/archives/\.\./|/sources/archives/|g')    # Fix the bash subshell and execution for Xorg loops
    echo "$COMMANDS" > /tmp/cmds_pre_awk.log
    log "Converting Xorg build loop into a standalone script..."
    XORG_AWK_SCRIPT="$HOME/.lfs_scripts/xorg_loop.awk"
    if [ ! -f "$XORG_AWK_SCRIPT" ]; then
        XORG_AWK_SCRIPT="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/xorg_loop.awk"
    fi
    COMMANDS=$(echo "$COMMANDS" | awk -f "$XORG_AWK_SCRIPT")
fi

# 2.11 Special handling for KDE frameworks6 and plasma-all
FRAMEWORKS_MODE=false
PLASMA_MODE=false
if [[ "${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks" || "${METAPACKAGE_TARGET,,}" == "frameworks6" ]]; then
    FRAMEWORKS_MODE=true
    log "Enabling special KDE frameworks loop mode."
elif [[ "${PACKAGE,,}" == "plasma-all" || "${PACKAGE,,}" == "plasma" || "${METAPACKAGE_TARGET,,}" == "plasma-all" ]]; then
    PLASMA_MODE=true
    log "Enabling special KDE plasma loop mode."
elif [[ "$COMMANDS" == *"while read line"* || "$COMMANDS" == *"while read -r line"* ]]; then
    # Fallback: identify by content if metapackage target not yet known
    if [[ "$COMMANDS" == *"download.kde.org/stable/frameworks"* ]]; then
        FRAMEWORKS_MODE=true
        log "Enabling special KDE frameworks loop mode (detected from commands)."
    elif [[ "$COMMANDS" == *"download.kde.org/stable/plasma"* ]]; then
        PLASMA_MODE=true
        log "Enabling special KDE plasma loop mode (detected from commands)."
    else
        # Default to frameworks if indeterminate but has the loop pattern
        FRAMEWORKS_MODE=true
        log "Enabling special KDE frameworks loop mode (fallback)."
    fi
fi

if [[ "$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true" ]]; then
    
    # Remove the descriptive text for wget options that gets erroneously extracted
    COMMANDS=$(echo "$COMMANDS" | awk '
        /^The options used here are:/ { skip=1; next }
        skip && /^-/ { next }
        skip && !/^-/ { skip=0 }
        { print }
    ')

    # Remove the /opt/kf6 installation commands as user installs to /usr
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^mv .* /opt/kf6")
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^ln -s.* /opt/kf6")

    # NOTE: Version substitution for KDE Frameworks upstream happens later (after
    # UPSTREAM_VERSION is set by the curl fetch at ~line 993).

    # Remove ALL ln commands that create self-symlinks when KF6_PREFIX=/usr.
    # These appear as: ln -sfv /usr/share/foo $KF6_PREFIX/share (same dir),
    # or: ln -sfv /usr/share/xsessions/foo.desktop ./foo.desktop (relative same file).
    # Strip any ln where the source starts with /usr/ and destination is $KF6_PREFIX/...
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^ln -sfv /usr/(share|lib|etc)/")
    # Also remove literal commands linking $KF6_PREFIX/share/... into /usr/share/...
    # Avoid sed N which breaks on large multi-line COMMANDS strings containing heredocs
    COMMANDS=$(echo "$COMMANDS" | grep -v '\[ -e plasma.*\.desktop \] ||')
    COMMANDS=$(echo "$COMMANDS" | grep -v 'ln -sfv .*plasma.*\.desktop')
    COMMANDS=$(echo "$COMMANDS" | grep -v '\[ -e kde-portals\.conf \] ||')
    COMMANDS=$(echo "$COMMANDS" | grep -v 'ln -sfv \$KF6_PREFIX/share/xdg-desktop-portal/kde-portals\.conf')
    COMMANDS=$(echo "$COMMANDS" | grep -v '\[ -e kde\.portal \] ||')
    COMMANDS=$(echo "$COMMANDS" | grep -v 'ln -sfv \$KF6_PREFIX/share/xdg-desktop-portal/portals/kde\.portal')
    COMMANDS=$(echo "$COMMANDS" | grep -v "^dbus-launch")
    
    # Strip the xinit/startx instructions that get extracted from the bottom of the plasma-all BLFS page
    COMMANDS=$(echo "$COMMANDS" | sed '/cat > ~\/.xinitrc << "EOF"/,/EOF/d')
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^[[:space:]]*startx")
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^[[:space:]]*exit[[:space:]]*$")

    # Clean up any trailing && left on lines directly preceding the stripped lines
    if [[ "$COMMANDS" == *"&&"* ]]; then
        # Remove trailing && that precede marker lines or empty lines
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe '
            s/&&\s*?\n(?=\s*#\s*__[A-Z_]+__)/\n/gs;
            s/&&\s*?\n(?=\n)/\n/gs;
            s/&&\s*?\n(?:#.*?\n)*\s*?$/\n/gs;
        ')
    fi
    if [[ "$INCLUDE_CONFIG" == "true" && ("${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks") ]]; then
        log "Adding kf6-intro.html configuration for /usr installation..."
        # Note: Depending on BLFS book URL, it could be in /kde/
        KF6_INTRO_URL=$(echo "$PAGE_URL" | sed 's/frameworks6\.html/kf6-intro.html/')
        INTRO_HTML=$(curl -s "$KF6_INTRO_URL")
        
        # We want the commands under "Installing in /usr"
        INTRO_CMDS=$(get_commands "$INTRO_HTML" | awk '
            BEGIN { p=0 }
            /export KF6_PREFIX=\/usr/ { p=1 }
            /export KF6_PREFIX=\/opt\/kf6/ { p=0 }
            p { print }
        ' | grep -v "^___BLOCK_")
        
        COMMANDS="${INTRO_CMDS}
${COMMANDS}"
    fi

    # Fix internal script paths for MD5 files (Xorg/KDE) before awk processing
    COMMANDS=$(echo "$COMMANDS" | sed -E 's|\.\./[a-z0-9.-]+\.md5|/sources/archives/&|g; s|/sources/archives/\.\./|/sources/archives/|g')
    # Fix invalid syntax on BLFS KDE pages: if $(echo $line | grep -q ...)
    COMMANDS=$(echo "$COMMANDS" | perl -pe 's/if \$\(echo \$line \| grep -E -q ([^)]*)\) ; then/if echo \$line | grep -E -q $1 ; then/g; s/if \$\(echo \$line \| grep -E -q ([^)]*)\); then/if echo \$line | grep -E -q $1; then/g')

fi

if [[ "$SKIP_HTML_EXTRACTION" == "true" ]]; then
    # Already set by special case
    :
elif [[ "$XORG_MULTI_MODE" == "true" ]]; then
        # Extract md5 file content and base URL to populate DOWNLOAD_URLS
        BASE_URL=$(echo "$COMMANDS" | perl -nle 'if (/ -B\s+(https?:\/\/\S+)/) { print $1; exit }')
        if [[ -z "$BASE_URL" ]]; then
            case "$PACKAGE" in
                xorg-lib|x7lib)       BASE_URL="https://xorg.freedesktop.org/archive/individual/lib/" ;;
                xorg-app|x7app)       BASE_URL="https://xorg.freedesktop.org/archive/individual/app/" ;;
                xorg-font|x7font)     BASE_URL="https://xorg.freedesktop.org/archive/individual/font/" ;;
                xorg-driver|x7driver) BASE_URL="https://xorg.freedesktop.org/archive/individual/driver/" ;;
            esac
        fi
        
        # Extract filenames from the md5 block
        # Look for the cat > ...md5 block (robustly)
        FILENAMES=$(echo "$COMMANDS" | perl -0777 -ne 'if (/cat > \S+\.md5 << "EOF"\s*\n(.*?)\nEOF/s) { my $block = $1; while ($block =~ /\s(\S+\.tar\.[a-z2]+)/g) { print "$1\n" } }')
        
        if [[ -z "$FILENAMES" ]]; then
            # Second attempt: maybe there are leading spaces in the filenames
            FILENAMES=$(echo "$COMMANDS" | perl -0777 -ne 'if (/cat > \S+\.md5 << "EOF"\s*\n(.*?)\nEOF/s) { my $block = $1; while ($block =~ /^.*\s(\S+\.tar\.[a-z2]+)/gm) { print "$1\n" } }')
        fi
        
        for f in $FILENAMES; do
            if [[ -n "$METAPACKAGE_TARGET" ]]; then
                [[ "$f" =~ ^${METAPACKAGE_TARGET}[-_][0-9] ]] && DOWNLOAD_URLS+=("${BASE_URL}${f}")
            else
                DOWNLOAD_URLS+=("${BASE_URL}${f}")
            fi
        done
        MAIN_DOWNLOAD_URL="${DOWNLOAD_URLS[0]}"
else

if [[ "$UPSTREAM" == "true" ]]; then
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Fetching latest mainline Linux kernel version..."
        KERNEL_VER=$(curl -s https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | perl -nle 'while (m{[0-9.]+}g) { print $& }' | sort -Vr | head -n 1)
        if [[ -n "$KERNEL_VER" ]]; then
            MAJOR=$(echo "$KERNEL_VER" | cut -d. -f1)
            # Use 2-part version for download (7.0) but 3-part for identification (7.0.0)
            DOWNLOAD_VER="$KERNEL_VER"
            if [[ $(echo "$KERNEL_VER" | grep -o '\.' | wc -l) -eq 1 ]]; then
                UPSTREAM_VERSION="${KERNEL_VER}.0"
            else
                UPSTREAM_VERSION="$KERNEL_VER"
            fi
            DOWNLOAD_URLS+=("https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${DOWNLOAD_VER}.tar.xz")
        fi
    elif [[ "${PACKAGE,,}" == "oxygen-icons" ]]; then
        log "Fetching latest upstream oxygen-icons version from KDE Frameworks..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+(\.[0-9]+)?}g) { my $v=$&; $v.=".0" if $v =~ /^\d+\.\d+$/; print $v }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream oxygen-icons version: $UPSTREAM_VERSION"
            UPSTREAM_MM=$(echo "$UPSTREAM_VERSION" | cut -d. -f1,2)
            DOWNLOAD_URLS=("https://download.kde.org/stable/frameworks/${UPSTREAM_MM}/oxygen-icons-${UPSTREAM_VERSION}.tar.xz")
        fi
    elif [[ "${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "breeze-icons" || "${PACKAGE,,}" == "extra-cmake-modules" || "$(basename "${METAPACKAGE_TARGET,,}")" == "frameworks6" || "$(basename "${METAPACKAGE_TARGET,,}")" == "frameworks" ]]; then
        log "Fetching latest upstream KDE Frameworks version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+(\.[0-9]+)?}g) { my $v=$&; $v.=".0" if $v =~ /^\d+\.\d+$/; print $v }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE Frameworks version: $UPSTREAM_VERSION"
        fi
    elif [[ "${PACKAGE,,}" == "plasma-all" || "${PACKAGE,,}" == "plasma" || "${PACKAGE,,}" == "libkscreen" || "$(basename "${METAPACKAGE_TARGET,,}")" == "plasma-all" || "$(basename "${METAPACKAGE_TARGET,,}")" == "plasma" ]]; then
        log "Fetching latest upstream KDE Plasma version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/plasma/ | perl -nle 'while (m{href="([0-9]+\.[0-9]+\.[0-9]+)/?"}g) { print $1 }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE Plasma version: $UPSTREAM_VERSION"
        fi
    elif [[ "${PACKAGE,,}" =~ ^(konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)$ ]]; then
        log "Fetching latest upstream KDE Application (Gear) version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/release-service/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE App version: $UPSTREAM_VERSION"
            DOWNLOAD_URLS+=("https://download.kde.org/stable/release-service/${UPSTREAM_VERSION}/src/${PACKAGE}-${UPSTREAM_VERSION}.tar.xz")
        fi
    elif [[ "$PACKAGE" == "rustc" ]]; then
        log "Fetching latest upstream Rust version..."
        RUST_TOML=$(curl -s https://static.rust-lang.org/dist/channel-rust-stable.toml)
        UPSTREAM_VERSION=$(echo "$RUST_TOML" | perl -ne 'if (/^\[pkg\.rust\]/) { $in=1 } elsif ($in && /^version\s*=\s*"([0-9.]+)/) { print $1; exit }')
        UPSTREAM_DATE=$(echo "$RUST_TOML" | grep "^date =" | cut -d '"' -f 2)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream Rust version: $UPSTREAM_VERSION (date: $UPSTREAM_DATE)"
            DOWNLOAD_URLS+=("https://static.rust-lang.org/dist/rustc-${UPSTREAM_VERSION}-src.tar.xz")
            # Rust releases occur every 6 weeks (42 days).
            PREV_MINOR_VERSION="${UPSTREAM_VERSION%%.*}.$(($(echo "$UPSTREAM_VERSION" | cut -d. -f2) - 1))"
            FALLBACK_VERSION="${PREV_MINOR_VERSION}.0"
            FALLBACK_DATE=$(date -d "${UPSTREAM_DATE} - 42 days" +%Y-%m-%d 2>/dev/null || date -d "${UPSTREAM_DATE} 42 days ago" +%Y-%m-%d)
            
            # Prioritize same-version binaries if already available (avoids confusing rolled-back downloads)
            # Check availability with a quick HEAD request
            if curl -sfI "https://static.rust-lang.org/dist/${UPSTREAM_DATE}/rustc-${UPSTREAM_VERSION}-x86_64-unknown-linux-gnu.tar.xz" -o /dev/null; then
                BOOTSTRAP_VERSION="$UPSTREAM_VERSION"
                BOOTSTRAP_DATE="$UPSTREAM_DATE"
                log "Using same-version bootstrap binaries: $BOOTSTRAP_VERSION (date: $BOOTSTRAP_DATE)"
            else
                BOOTSTRAP_VERSION="$FALLBACK_VERSION"
                BOOTSTRAP_DATE="$FALLBACK_DATE"
                log "Primary target binaries not found; falling back to bootstrap version $BOOTSTRAP_VERSION (date: $BOOTSTRAP_DATE)"
            fi
            # Use these variables for addition to DOWNLOAD_URLS later
            PREV_VERSION="$BOOTSTRAP_VERSION"
            PREV_DATE="$BOOTSTRAP_DATE"
        fi
    elif [[ "$PACKAGE" == "llvm" ]]; then
        log "Fetching latest upstream LLVM version from GitHub..."
        UPSTREAM_VERSION=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for rel in data:
        tag = rel.get("tag_name", "")
        if tag.startswith("llvmorg-"):
            ver = tag.split("-")[1]
            if any(a.get("name") == f"llvm-project-{ver}.src.tar.xz" for a in rel.get("assets", [])):
                print(ver)
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
' 2>/dev/null)
        if [[ -z "$UPSTREAM_VERSION" ]]; then
            UPSTREAM_VERSION=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases/latest | perl -nle 'while (m{"tag_name":\s*"llvmorg-([0-9.]+)"}g) { print $1 }' | head -n 1)
            [[ -z "$UPSTREAM_VERSION" || "$UPSTREAM_VERSION" == "22.1.6" ]] && UPSTREAM_VERSION="22.1.5"
        fi
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream LLVM version: $UPSTREAM_VERSION"
            # Prefer monorepo as it simplifies the build structure for newer versions
            DOWNLOAD_URLS+=("https://github.com/llvm/llvm-project/releases/download/llvmorg-${UPSTREAM_VERSION}/llvm-project-${UPSTREAM_VERSION}.src.tar.xz")
        fi
    elif [[ "$PACKAGE" == "libuv" ]]; then
        log "Fetching latest upstream libuv version from GitHub..."
        UPSTREAM_VERSION=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/libuv/libuv/releases/latest | perl -nle 'while (m{"tag_name":\s*"v([0-9.]+)"}g) { print $1 }' | head -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream libuv version: $UPSTREAM_VERSION"
            DOWNLOAD_URLS+=("https://dist.libuv.org/dist/v${UPSTREAM_VERSION}/libuv-v${UPSTREAM_VERSION}.tar.gz")
        fi
    elif [[ "$PACKAGE" =~ ^(gnome-.*|gsettings-desktop-schemas|yelp|mutter|nautilus|gnome-terminal|vte|glycin|gjs|tecla|gvfs|gexiv2|dconf|baobab|evince|gedit|epiphany|totem|tracker.*|grilo.*|folks|evolution.*|gtksourceview.*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|glib2?|glib-networking|glibmm|gmime|gnome-online-accounts|gnome-video-effects|graphene|gsound|gtk-doc|gtkmm.*|harfbuzz|json-glib|libadwaita|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|libpeas|librsvg|libsecret|libsoup|mm-common|pango|pangomm|phodav|pygobject|rest|xdg-desktop-portal-gnome|tinysparql|localsearch|dconf-editor|polkit-gnome|geocode-glib|libshumate)$ ]]; then
        GNOME_PKG="$PACKAGE"
        [[ "$GNOME_PKG" == "glib2" ]] && GNOME_PKG="glib"
        log "Fetching latest upstream GNOME version for $GNOME_PKG from download.gnome.org..."
        # Use helper from 21-lfs.sh if available
        if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
            source "$NIXCFG/shell/user/21-lfs.sh" 2>/dev/null
        elif [ -f ~/.lfs_scripts/21-lfs.sh ]; then
            source ~/.lfs_scripts/21-lfs.sh 2>/dev/null
        fi
        
        if declare -f lfs_get_upstream_version >/dev/null; then
            UPSTREAM_VERSION=$(lfs_get_upstream_version "$GNOME_PKG")
        else
            if [[ "$GNOME_PKG" == "libpeas" ]]; then
                UPSTREAM_VERSION=$(curl -sL "https://gitlab.gnome.org/api/v4/projects/GNOME%2Flibpeas/repository/tags" | perl -nle 'while (m{"name":"libpeas-([0-9.]+)"}g) { print $1 }' | sort -V | tail -n 1)
            else
                base_url="https://download.gnome.org/sources/$GNOME_PKG"
                local gn_ver=$(curl -sL "$base_url/cache.json" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    versions = data[1].get("'"$GNOME_PKG"'", [])
    stable_versions = [v for v in versions if all(p.isdigit() for p in v.split("."))]
    if stable_versions:
        stable_versions.sort(key=lambda x: [int(p) for p in x.split(".")])
        print(stable_versions[-1])
except Exception:
    pass
' 2>/dev/null)
                if [[ -n "$gn_ver" ]]; then
                    UPSTREAM_VERSION="$gn_ver"
                else
                    major=$(curl -sL "$base_url/" | perl -nle 'while (m{href="\K[0-9]+(\.[0-9]+)*(?=/?")}sg) { print $& }' | sort -V | tail -n 1)
                    [ -n "$major" ] && UPSTREAM_VERSION=$(curl -sL "$base_url/$major/" | perl -nle 'while (m{href="\K'"$GNOME_PKG"'-([0-9.]+)\.tar}sg) { print $1 }' | sort -V | tail -n 1)
                fi
            fi
        fi

        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream GNOME version for $GNOME_PKG: $UPSTREAM_VERSION"
                major_v=${UPSTREAM_VERSION%%.*}
            if [[ "$major_v" =~ ^[0-9]+$ ]] && [ "$major_v" -lt 40 ]; then
                major_v=$(echo "$UPSTREAM_VERSION" | cut -d. -f1,2)
            fi
            # Clear existing URLs from book to prioritize upstream GNOME
            DOWNLOAD_URLS=()
            # Detect extension (prefer .tar.xz, fallback to .tar.gz)
            # Use -L to follow redirects; check for any 2xx status
            _xz_url="https://download.gnome.org/sources/$GNOME_PKG/$major_v/$GNOME_PKG-$UPSTREAM_VERSION.tar.xz"
            _gz_url="https://download.gnome.org/sources/$GNOME_PKG/$major_v/$GNOME_PKG-$UPSTREAM_VERSION.tar.gz"
            if curl -sIL "$_xz_url" | grep -qE "^HTTP.*2[0-9][0-9]"; then
                DOWNLOAD_URLS+=("$_xz_url")
            elif curl -sIL "$_gz_url" | grep -qE "^HTTP.*2[0-9][0-9]"; then
                DOWNLOAD_URLS+=("$_gz_url")
            else
                log "WARNING: Could not find a valid archive for $GNOME_PKG-$UPSTREAM_VERSION on download.gnome.org (tried .tar.xz and .tar.gz)"
                DOWNLOAD_URLS+=("$_xz_url")  # fallback attempt anyway
            fi
        fi
    else
        log "Checking for generic upstream resolution via lfs_get_upstream_version..."
        if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
            source "$NIXCFG/shell/user/21-lfs.sh" 2>/dev/null
        elif [ -f ~/.lfs_scripts/21-lfs.sh ]; then
            source ~/.lfs_scripts/21-lfs.sh 2>/dev/null
        fi
        
        if declare -f lfs_get_upstream_version >/dev/null; then
            UPSTREAM_VERSION=$(lfs_get_upstream_version "$PACKAGE")
        fi
        
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream version for $PACKAGE: $UPSTREAM_VERSION via generic fallback"
            UPSTREAM_FULL="$UPSTREAM_VERSION"
        else
            log "Upstream flag ignored for package '$PACKAGE' (no upstream fetching logic defined)"
            UPSTREAM="false"
        fi
    fi
fi

# Identify LFS version from COMMANDS for KDE/Plasma/Metapackage substitution
# This must happen before DOWNLOAD_URLS population to ensure correct versions are fetched
LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules|kdecoration|libkscreen)-\K[0-9]+(\.[0-9]+)+}g) { print $& }' | sort -V | tail -n 1)
if [[ -z "$LFS_VERSION" ]]; then
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{/archives/(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules|kdecoration|libkscreen)-\K[0-9]+(\.[0-9]+)+}g) { print $& }' | sort -V | tail -n 1)
fi
[[ -z "$LFS_VERSION" ]] && LFS_VERSION=$(echo "$COMMANDS" | grep -oE -- '-(6\.[0-9]+\.[0-9]+)\.tar' | head -n 1 | sed 's/-//; s/\.tar//')
LFS_MM=$(echo "$LFS_VERSION" | cut -d. -f1,2)

if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" && -n "$LFS_VERSION" ]]; then
    UPSTREAM_FULL="${UPSTREAM_VERSION}"
    if [[ $(echo "$UPSTREAM_FULL" | grep -o '\.' | wc -l) -eq 1 ]]; then
        UPSTREAM_FULL="${UPSTREAM_FULL}.0"
    fi
    UPSTREAM_MM=$(echo "$UPSTREAM_FULL" | cut -d. -f1,2)
fi

# Populate DOWNLOAD_URLS from MD5 file for metapackages (Xorg/KDE) to ensure all sub-packages are available
if [[ "$XORG_MULTI_MODE" == "true" || "$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true" ]]; then
    if [[ "$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true" ]]; then
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            MM=$(echo "$UPSTREAM_VERSION" | cut -d. -f1,2)
            if [[ "$PLASMA_MODE" == "true" ]]; then
                BASE_URL="https://download.kde.org/stable/plasma/${UPSTREAM_VERSION}/"
            else
                BASE_URL="https://download.kde.org/stable/frameworks/${MM}/"
            fi
        else
            BASE_URL=$(echo "$COMMANDS" | perl -nle 'if (/url=(https?:\/\/\S+)/) { print $1; exit }')
        fi
        
        if [[ -z "$BASE_URL" ]]; then
            if [[ "$PLASMA_MODE" == "true" ]]; then
                BASE_URL="https://download.kde.org/stable/plasma/${LFS_VERSION}/"
            else
                BASE_URL="https://download.kde.org/stable/frameworks/$(echo "$LFS_VERSION" | cut -d. -f1,2)/"
            fi
        fi
    else
        # Extract base URL for Xorg
        BASE_URL=$(echo "$COMMANDS" | perl -nle 'if (/ -B\s+(https?:\/\/\S+)/) { print $1; exit }')
        if [[ -z "$BASE_URL" ]]; then
            case "$PACKAGE" in
                xorg-lib|x7lib)       BASE_URL="https://xorg.freedesktop.org/archive/individual/lib/" ;;
                xorg-app|x7app)       BASE_URL="https://xorg.freedesktop.org/archive/individual/app/" ;;
                xorg-font|x7font)     BASE_URL="https://xorg.freedesktop.org/archive/individual/font/" ;;
                xorg-driver|x7driver) BASE_URL="https://xorg.freedesktop.org/archive/individual/driver/" ;;
            esac
        fi
    fi
    
    # Extract filenames from the MD5 block in COMMANDS (skip commented-out lines)
    FILENAMES=$(echo "$COMMANDS" | perl -0777 -ne 'if (/cat > \S+\.md5 << "EOF"\s*\n(.*?)\nEOF/s) { my $block = $1; while ($block =~ /^(?!\s*#).*?\s(\S+\.tar\.[a-z2]+)/gm) { print "$1\n" } }')
    if [[ -z "$FILENAMES" ]]; then
        FILENAMES=$(echo "$COMMANDS" | perl -0777 -ne 'if (/cat > \S+\.md5 << "EOF"\s*\n(.*?)\nEOF/s) { my $block = $1; while ($block =~ /^(?!#).*\s(\S+\.tar\.[a-z2]+)/gm) { print "$1\n" } }')
    fi

    if [[ -n "$METAPACKAGE_TARGET" && ("$PLASMA_MODE" == "true" || "$FRAMEWORKS_MODE" == "true") ]]; then
        # When building a specific component, explicitly set the tarball. 
        # This bypasses the md5 extraction, resolving issues where components like plasma-sdk 
        # are commented out in the upstream md5 block and would otherwise be skipped.
        ver="${UPSTREAM_FULL:-$LFS_VERSION}"
        [[ -z "$ver" && -n "$TARGET_VER" ]] && ver="$TARGET_VER"
        target_name="${METAPACKAGE_TARGET:-$PACKAGE}"
        if [[ -n "$ver" ]]; then
            FILENAMES="${target_name}-${ver}.tar.xz"
            log "Metapackage target mode: forcing download of ${target_name} component: $FILENAMES"
        fi
    elif [[ -z "$FILENAMES" ]] && [[ "$PACKAGE" != "frameworks6" && "$PACKAGE" != "plasma-all" && "$PACKAGE" != "xorg-lib" && "$PACKAGE" != "xorg-app" && "$PACKAGE" != "xorg-font" && "$PACKAGE" != "xorg-driver" ]]; then
        # Fallback: construct the filename for the target package if extraction failed
        if [[ "$PLASMA_MODE" == "true" || "$FRAMEWORKS_MODE" == "true" ]]; then
             ver="${UPSTREAM_FULL:-$LFS_VERSION}"
             [[ -z "$ver" && -n "$TARGET_VER" ]] && ver="$TARGET_VER"
             target_name="${METAPACKAGE_TARGET:-$PACKAGE}"
             if [[ -n "$ver" ]]; then
                 FILENAMES="${target_name}-${ver}.tar.xz"
                 log "Constructed fallback KDE filename: $FILENAMES"
             fi
        fi
    fi
    
    if [[ -n "$FILENAMES" ]]; then
        # Apply version substitution to FILENAMES if we are in upstream mode
        if [[ -n "$UPSTREAM_FULL" && -n "$LFS_VERSION" ]]; then
            FILENAMES=$(echo "$FILENAMES" | sed "s/$LFS_VERSION/$UPSTREAM_FULL/g; s/$LFS_MM/$UPSTREAM_MM/g")
        fi
        for f in $FILENAMES; do
            # Only add if it's the target package OR if we are in full metapackage mode
            if [[ -n "$METAPACKAGE_TARGET" ]]; then
                [[ "$f" =~ ^${METAPACKAGE_TARGET}[-_][0-9] ]] && [[ -n "$f" ]] && DOWNLOAD_URLS+=("${BASE_URL}${f}")
            elif [[ -z "$PACKAGE" || "$PACKAGE" == "frameworks6" || "$PACKAGE" == "plasma-all" || "$PACKAGE" == "xorg-lib" || "$PACKAGE" == "xorg-app" || "$PACKAGE" == "xorg-font" || "$PACKAGE" == "xorg-driver" || "$f" =~ ^${PACKAGE}[-_][0-9] ]]; then
                [[ -n "$f" ]] && DOWNLOAD_URLS+=("${BASE_URL}${f}")
            fi
        done
    fi
fi
fi

# Strip trailing digits only for certain known versioned names (python3, lua5)
if [[ "${PACKAGE,,}" == "liba52" ]]; then
    # Special case: liba52's archive is named a52dec
    PKG_BASE="a52dec"
elif [[ "$PACKAGE" == "libclc" ]]; then
    # libclc download archive is named llvm-project
    PKG_BASE="(libclc|llvm-project)"
elif [[ "$PACKAGE" =~ ^[a-zA-Z]+[0-9]$ ]]; then
    PKG_BASE="$PACKAGE"
elif [[ "$PACKAGE" == "rustc" ]]; then
    PKG_BASE="(rustc|rust-std|cargo)"
elif [[ "$PACKAGE" =~ ^xorg-.*-driver$ ]]; then
    driver_name=$(echo "$PACKAGE" | sed 's/^xorg-//; s/-driver$//')
    PKG_BASE="(xf86-input-${driver_name}|${driver_name})"
else
    PKG_BASE=$(echo "$PACKAGE" | sed 's/[0-9]*$//')
fi
log "Package base name for search: $PKG_BASE"

search_content="${HTML_CONTENT:-$FULL_HTML_CONTENT}"

if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]] || { [[ "$UPSTREAM" == "true" ]] && [[ -z "$UPSTREAM_VERSION" ]]; }; then
    # 0. Primary Links from Page (Robust Extraction)
    # Extract all "Download (HTTP)" and "Download:" links explicitly labeled on the page
    # Use HTML_CONTENT (sliced) if available to avoid picking up links from other packages
    mapfile -t PRIMARY_DOWNLOADS < <(printf '%s' "$search_content" | perl -0777 -ne 'while (/Download(?:\s*\(HTTP\))?:\s*<a[^>]+href=\s*"([^"]+)"/igs) { print "$1\n" }')
    DOWNLOAD_URLS+=("${PRIMARY_DOWNLOADS[@]}")
fi

# ALWAYS extract "Additional Downloads" or "Optional Downloads" links (e.g. UCD.zip for ibus, gobject-introspection for glib2)
# We must do this even if the primary URL was fetched upstream, because the build may still require these BLFS-specific files.
mapfile -t ADDITIONAL_DOWNLOADS < <(printf '%s' "$search_content" | perl -0777 -nle 'while (/<h3[^>]*>\s*(?:Additional|Optional)\s*Downloads\s*<\/h3>(.*?)<(?:h[23])/igs) { my $b=$1; while ($b =~ /href=\s*"([^"]+\.(?:tar\.[a-z2]+|zip|patch|tgz|gz|bz2|xz))"/igs) { print "$1\n"; } }')
DOWNLOAD_URLS+=("${ADDITIONAL_DOWNLOADS[@]}")

if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]] || { [[ "$UPSTREAM" == "true" ]] && [[ -z "$UPSTREAM_VERSION" ]]; }; then
    # 1. Main Page Links (for both LFS and BLFS)
    # Extract all archive and patch links
    mapfile -t PAGE_LINKS < <(printf '%s' "$FULL_HTML_CONTENT" | perl -nle 'while (m{(?i)https?://[^\s"]*(\.tar\.[a-z2]+|\.zip|\.patch|\.tgz)}g) { print $& }' | sort -u)
    
    # 2. LFS Patches Page (for LFS packages)
    if [[ "$PAGE_URL" == *"/lfs/"* ]]; then
        log "Searching LFS Chapter 3 for packages and patches..."
        # Get ALL matching files from chapter 3 packages (including docs, sources, etc)
        # Match patterns like: sqlite-autoconf-3510300, sqlite-doc-3510300, python-3.9.1, etc
        mapfile -t LFS_PKG_URLS < <(curl -s "$LFS_BOOK/chapter03/packages.html" | perl -nle "while (m{(?i)https?://[^\\s\"]*/${PKG_BASE}[^\\s/]*[0-9][^\\s\"]*(\\.tar\\.[a-z2]+|\\.zip)}g) { print $& }" | sort -u)
        DOWNLOAD_URLS+=("${LFS_PKG_URLS[@]}")
        
        # Add patches from chapter 3
        mapfile -t LFS_PATCH_URLS < <(curl -s "$LFS_BOOK/chapter03/patches.html" | perl -nle "while (m{(?i)https?://[^\\s\"]*/${PKG_BASE}-[^\\s\"]*\\.patch}g) { print $& }" | sort -u)
        DOWNLOAD_URLS+=("${LFS_PATCH_URLS[@]}")
    fi

    # Filter page links for relevance
    for link in "${PAGE_LINKS[@]}"; do
        # For Rust upstream, only fetch the source, skip binaries
        # EXCEPT for the bootstrap binaries we manually added
        if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "rustc" ]] && ! [[ "$(basename "$link")" =~ -src\.tar\. ]]; then
             # Check if it's one of the bootstrap binaries we added (contains a full date in path or version)
             # Actually, if it's from PAGE_LINKS, it's NOT one we added manually.
             # PAGE_LINKS are from the BLFS page.
             continue
        fi
        # For LLVM upstream, if we already have the monorepo, skip individual components from the page
        if [[ "$PACKAGE" == "llvm" ]] && [[ "$UPSTREAM" == "true" ]] && [[ "$(basename "$link")" =~ (llvm-|clang-|cmake-|third-party-|compiler-rt-)[0-9] ]]; then
            continue
        fi
        # Include if it matches package base name (case insensitive)
        # or if it's explicitly a patch on a package page
        # Special case: spidermonkey often uses firefox source
        link_base=$(basename "$link")
        match_pattern="${PKG_BASE}"
        # For versioned names like glib2, match 'glib' as well
        if [[ "$PKG_BASE" =~ [0-9]$ ]]; then
            match_pattern="${PKG_BASE}|${PKG_BASE%[0-9]}"
        fi

        if (grep -Eiq "^(${match_pattern})[-_]?[0-9]" <<< "$link_base" || \
           ([[ "$PACKAGE" == "spidermonkey" ]] && grep -qi "^firefox[-_]?[0-9]" <<< "$link_base")) && \
           [[ "$link_base" =~ (\.tar\.[a-z2]+|\.zip|\.patch|\.tgz|\.gz|\.sig)$ ]]; then
            DOWNLOAD_URLS+=("$link")
        fi
    done
fi

# Final deduplication and prioritization
if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]] && [[ "$FRAMEWORKS_MODE" == "false" ]] && [[ "$XORG_MULTI_MODE" == "false" ]]; then
    error "Could not find any download URLs for '$PACKAGE'"
fi

# Remove duplicates while preserving order
DOWNLOAD_URLS=($(printf "%s\n" "${DOWNLOAD_URLS[@]}" | awk '!x[$0]++'))

# Filter out directory URLs (ending in /) and apply upstream version substitution
NEW_URLS=()
for url in "${DOWNLOAD_URLS[@]}"; do
    # Skip directories (ending in / or appearing to be an index page or version-only path)
    [[ "$url" =~ /$ ]] && continue
    [[ "$url" =~ /index\.html$ ]] && continue
    [[ "$url" =~ /[0-9]+(\.[0-9]+)*$ ]] && continue
    if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_FULL" && -n "$LFS_VERSION" ]]; then
        url=$(echo "$url" | sed "s/$LFS_VERSION/$UPSTREAM_FULL/g")
        if [[ -n "$LFS_MM" && -n "$UPSTREAM_MM" ]]; then
            url=$(echo "$url" | sed "s/$LFS_MM/$UPSTREAM_MM/g")
        fi
    fi
    # Rewrite X.org pub URLs to xorg.freedesktop.org archive URLs as X.org is throwing 404s
    url=$(echo "$url" | sed 's|https://www.x.org/pub/|https://xorg.freedesktop.org/archive/|g')
    url=$(echo "$url" | sed 's|https://www.x.org/archive/|https://xorg.freedesktop.org/archive/|g')
    NEW_URLS+=("$url")
done
DOWNLOAD_URLS=("${NEW_URLS[@]}")

# Special case: Fix ghostscript GitHub releases (BLFS often has wrong tag)
# The BLFS page may have gs10060 tag for 10.07.0, but need gs10070
if [[ "$PACKAGE" == "ghostscript" ]]; then
    for i in "${!DOWNLOAD_URLS[@]}"; do
        url="${DOWNLOAD_URLS[$i]}"
        if [[ "$url" == *"github.com/ArtifexSoftware/ghostpdl-downloads"* ]]; then
            # Extract version from filename
            gs_version=$(basename "$url" | sed -n 's/.*ghostscript-\([0-9.]*\).*/\1/p')
            if [[ -n "$gs_version" ]]; then
                # Convert version to tag format: 10.07.0 -> gs10070
                gs_tag="gs$(echo "$gs_version" | tr -d '.')"
                # Replace incorrect tag in URL with correct one
                DOWNLOAD_URLS[$i]="${url//\/gs[0-9]*\//\/${gs_tag}\/}"
                log "Fixed ghostscript URL tag: $gs_tag"
            fi
        fi
    done
# Fix NSS Mozilla archive URLs (often mismatch between version and RTM directory)
elif [[ "$PACKAGE" == "nss" ]]; then
    for i in "${!DOWNLOAD_URLS[@]}"; do
        url="${DOWNLOAD_URLS[$i]}"
        if [[ "$url" == *"archive.mozilla.org/pub/security/nss/releases/NSS_"* ]]; then
            # Extract version from filename (e.g. nss-3.123.1.tar.gz -> 3.123.1)
            nss_version=$(basename "$url" | sed -E 's/nss-([0-9.]+)\.tar\..*/\1/')
            if [[ -n "$nss_version" ]]; then
                # Convert version to tag format: 3.123.1 -> 3_123_1 (ensure no space/newline)
                nss_tag=$(echo "$nss_version" | tr '.' '_' | tr -d '[:space:]')
                # Replace incorrect tag in URL with correct one (e.g. /NSS_3_123_RTM/ -> /NSS_3_123_1_RTM/)
                old_url="${DOWNLOAD_URLS[$i]}"
                DOWNLOAD_URLS[$i]=$(echo "$url" | sed -E "s|/NSS_[0-9_]+_RTM/|/NSS_${nss_tag}_RTM/|")
                if [[ "$old_url" != "${DOWNLOAD_URLS[$i]}" ]]; then
                    log "Fixed NSS URL directory tag to match version: $nss_tag"
                fi
            fi
        fi
    done
# Generic fix for other GitHub releases where the tag in the path does not match the filename version
else
    for i in "${!DOWNLOAD_URLS[@]}"; do
        url="${DOWNLOAD_URLS[$i]}"
        if [[ "$url" == *"github.com/"*"/releases/download/"* ]]; then
            # Extract version from filename using the same heuristic as LFS_VERSION
            fname=$(basename "$url")
            fv=$(echo "$fname" | perl -nle 'while (m{[-_]\K[0-9][a-z0-9.-]*(?:\.[0-9]+[a-z0-9.-]*)*[a-z0-9]}g) { print $& }' | head -n 1 | sed -E 's/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//; s/-(source|src|linux|x86_64|noarch|bin|static|shared)$//g')
            
            if [[ -n "$fv" ]]; then
                # Extract current tag (directory before filename)
                tag=$(echo "$url" | sed -E 's|.*/releases/download/([^/]+)/.*|\1|')
                if [[ -n "$tag" && "$tag" != "$fv" && "$tag" != "v$fv" ]]; then
                     # If the tag looks like a version of the same package (numeric-ish), treat as mismatched and attempt fix
                     if [[ "$tag" =~ ^v?[0-9][0-9.-]*[a-z0-9]$ ]]; then
                         log "Mismatched GitHub tag detected for $(basename "$url") ($tag vs $fv). Fixing path tag..."
                         DOWNLOAD_URLS[$i]="${url/\/download\/$tag\//\/download\/$fv\/}"
                     fi
                fi
            fi
        fi
    done
fi

if [[ "$FRAMEWORKS_MODE" == "false" && "$PLASMA_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
    # Identify MAIN_DOWNLOAD_URL (the one that looks most like the source archive)
    MAIN_DOWNLOAD_URL=""
    for url in "${DOWNLOAD_URLS[@]}"; do
        fname=$(basename "$url")
        # High Priority: For TeX Live, we MUST use the -source tarball as primary
        if [[ "$PACKAGE" == "texlive" ]] && [[ "$fname" == *"texlive-"*"-source"* ]]; then
            MAIN_DOWNLOAD_URL="$url"
            break
        fi
    done

    if [[ -z "$MAIN_DOWNLOAD_URL" ]]; then
        for url in "${DOWNLOAD_URLS[@]}"; do
            fname=$(basename "$url")
            # For LLVM, prefer the monorepo if available
            if [[ "$PACKAGE" == "llvm" ]] && [[ "$fname" == *"llvm-project-"* ]]; then
                MAIN_DOWNLOAD_URL="$url"
                break
            fi
            # Priority 1: matches package-version.tar.* (handles sqlite-autoconf-3510300, etc)
            if [[ "$fname" =~ ^${PKG_BASE}[^-]*-?[0-9].*\.tar\. ]] && [[ ! "$fname" =~ (-html\.|\.html\.|-doc(s)?(-|\.)|-documentation) ]]; then
                MAIN_DOWNLOAD_URL="$url"
                break
            fi
        done
    fi

    # Fallback: first one that isn't a patch or documentation
    if [[ -z "$MAIN_DOWNLOAD_URL" ]]; then
        for url in "${DOWNLOAD_URLS[@]}"; do
            fname=$(basename "$url")
            # Exclude patches and documentation files (doc, docs, documentation, html, etc)
            if [[ ! "$fname" =~ \.patch$ ]] && [[ ! "$fname" =~ (-html\.|\.html\.|-doc(s)?(-|\.)|-documentation) ]]; then
                MAIN_DOWNLOAD_URL="$url"
                break
            fi
        done
    fi

    # Final fallback: first one
    [[ -z "$MAIN_DOWNLOAD_URL" ]] && MAIN_DOWNLOAD_URL="${DOWNLOAD_URLS[0]}"

    log "Identified main archive: $MAIN_DOWNLOAD_URL"
        # Heuristic: extract version from MAIN_DOWNLOAD_URL filename
        # Pattern: - or _ followed by a digit and then version-like characters
        LFS_VERSION=$(basename "$MAIN_DOWNLOAD_URL" | perl -nle 'while (m{[-_]\K[0-9][a-z0-9.-]*(?:\.[0-9]+[a-z0-9.-]*)*[a-z0-9]}g) { print $& }' | head -n 1 | sed -E 's/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//; s/-(source|src|linux|x86_64|noarch|bin|static|shared)$//g')
        if [[ -z "$LFS_VERSION" ]] && [[ -n "$HTML_CONTENT" ]]; then
            # Fallback for BLFS: extract from <h1> header if possible (e.g. LVM2-2.03.39)
            LFS_VERSION=$(echo "$HTML_CONTENT" | perl -0777 -ne 'if (m{<h1[^>]*?>.*?[- ]\K([0-9][0-9.-]*[a-z0-9])}is) { print $1; exit }')
            [[ -n "$LFS_VERSION" ]] && log "Extracted version from HTML header: $LFS_VERSION"
        fi
        [[ -n "$LFS_VERSION" ]] && log "Extracted version from URL: $LFS_VERSION"
        # TZDATA special case: extract version from filename (e.g. 2026a)
        if [[ "$PACKAGE" == "tzdata" ]]; then
            LFS_VERSION=$(basename "$MAIN_DOWNLOAD_URL" | sed -E 's/^tzdata//; s/\.tar\..*$//')
            log "Tzdata version override from filename: $LFS_VERSION"
        fi
    log "Total files to download: ${#DOWNLOAD_URLS[@]}"
else
    log "KDE Loop mode: skipping MAIN_DOWNLOAD_URL identification."
fi

# Fix move command for xorgproto doc in single package mode if it exists
if [[ "$PACKAGE" == "xorgproto" ]]; then
    COMMANDS=$(echo "$COMMANDS" | sed -E 's|mv -v \$XORG_PREFIX/share/doc/xorgproto\{,-(.*)\}|sudo rm -rf $XORG_PREFIX/share/doc/xorgproto-\1 \&\& sudo mv -v $XORG_PREFIX/share/doc/xorgproto $XORG_PREFIX/share/doc/xorgproto-\1|g')
fi

# Replace hardcoded Linux kernel versions and fix build commands when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "linux" && -n "$UPSTREAM_VERSION" ]]; then
    # Fetch LFS release version (e.g., "r12.4-84")
    log "Fetching LFS release version from systemd manual..."
    LFS_RELEASE=$(curl -s https://www.linuxfromscratch.org/lfs/view/systemd/chapter10/kernel.html | \
                  grep "systemd" | head -n 1 | cut -d '"' -f 4 | \
                  sed 's/lfs-//g' | sed 's/-systemd//g')
    
    # Extract LFS kernel version from commands
    LFS_KERNEL_VER=$(echo "$COMMANDS" | perl -nle 'while (m{linux-\K[0-9]+\.[0-9]+(\.[0-9]+)?}g) { print $& }' | head -n 1)
    
    if [[ -n "$LFS_KERNEL_VER" ]]; then
        log "Processing Linux kernel commands..."
        log "Replacing LFS kernel version $LFS_KERNEL_VER with upstream version $UPSTREAM_VERSION"
        if [[ -n "$LFS_RELEASE" ]]; then
            log "Using LFS release version: $LFS_RELEASE"
        fi
        
        # Replace kernel version strings
        COMMANDS="${COMMANDS//$LFS_KERNEL_VER/$UPSTREAM_VERSION}"
        
        # If we standardized to x.y.0, filenames and directories in commands 
        # must still use the x.y naming since that's how they are archived/extracted.
        if [[ "$UPSTREAM_VERSION" =~ \.0$ ]]; then
            SHORT_VER="${UPSTREAM_VERSION%.0}"
            log "Adjusting filenames/directories in commands to use $SHORT_VER..."
            COMMANDS="${COMMANDS//linux-$UPSTREAM_VERSION/linux-$SHORT_VER}"
        fi
        
        # Replace LFS release version in vmlinuz path (e.g., r12.4-84)
        if [[ -n "$LFS_RELEASE" ]]; then
            # Extract old LFS release from commands (pattern: lfs-rX.Y.Z-NN)
            OLD_LFS_RELEASE=$(echo "$COMMANDS" | perl -nle 'while (m{lfs-r[0-9]+\.[0-9]+-[0-9]+}g) { print $& }' | head -n 1 | sed 's/lfs-//g')
            if [[ -n "$OLD_LFS_RELEASE" ]]; then
                COMMANDS="${COMMANDS//$OLD_LFS_RELEASE/$LFS_RELEASE}"
            fi
        fi
        
        # Remove duplicate make mrproper (keep only first occurrence)
        # Add config copy after first make mrproper
        # Remove make menuconfig commands
        # Remove mount /boot command
        COMMANDS=$(echo "$COMMANDS" | awk '
            BEGIN { mrproper_seen=0 }
            /^make.*mrproper/ {
                if (mrproper_seen == 0) {
                    print "make mrproper"
                    print "cat /boot/config-$(uname -r) > .config"
                    print "make olddefconfig"
                    mrproper_seen=1
                }
                next
            }
            /^make.*menuconfig/ { next }
            /^mount \/boot/ { next }
            { print }
        ')
        
        # Add initramfs generation after make modules_install
        # Add grub-mkconfig after vmlinuz copy
        COMMANDS=$(echo "$COMMANDS" | awk -v ver="$UPSTREAM_VERSION" -v lfs_rel="$LFS_RELEASE" '
            /^[[:space:]]*make modules_install[[:space:]]*$/ {
                print
                print ""
                print "mkinitramfs " ver
                print "mv initrd.img-" ver " /boot/initramfs-" ver "-lfs-" lfs_rel "-systemd.img"
                next
            }
            /^cp -iv arch\/x86\/boot\/bzImage \/boot\/vmlinuz-/ {
                sub(/-iv/, "-v")
                print
                print ""
                print "grub-mkconfig -o /boot/grub/grub.cfg"
                next
            }
            { 
                if ($0 ~ /^cp -iv/) sub(/-iv/, "-v")
                print 
            }
        ')
    fi
fi

# Replace hardcoded Firefox versions when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "firefox" && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (e.g., "140.7.1esr")
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{firefox-\K[0-9.]+esr}g) { print $& }' | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{firefox-\K[0-9.]+}g) { print $& }' | head -n 1)
    fi

    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS version $LFS_VERSION with upstream version $UPSTREAM_VERSION in commands..."
        COMMANDS="${COMMANDS//firefox-$LFS_VERSION/firefox-$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_FILENAME="${MAIN_FILENAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//$LFS_VERSION/$UPSTREAM_VERSION}"
        DIRNAME="${DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        GEN_DIRNAME="${GEN_DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

if [[ "$UPSTREAM" == "true" && "${PACKAGE,,}" =~ ^(konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)$ && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from the identified main download URL (e.g. konsole-24.12.2.tar.xz)
    LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle "while (m{${PKG_BASE}-\K[0-9]+(?:\.[0-9]+)+}g) { print $& }" | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle 'while (m{[0-9]+(?:\.[0-9]+)+}g) { print $& }' | head -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        # Fallback
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{[0-9]+(?:\.[0-9]+)+}g) { print $& }' | head -n 1)
    fi

    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS KDE App version $LFS_VERSION with $UPSTREAM_VERSION in commands and URLs..."
        COMMANDS="${COMMANDS//release-service\/$LFS_VERSION/release-service\/$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//${PACKAGE}-$LFS_VERSION/${PACKAGE}-$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        
        # Manually update the download URLs as well since they were parsed before this step
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_VERSION/$UPSTREAM_VERSION}"
        done
        MAIN_FILENAME="${MAIN_FILENAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//$LFS_VERSION/$UPSTREAM_VERSION}"
        DIRNAME="${DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        GEN_DIRNAME="${GEN_DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

if [[ "$UPSTREAM" == "true" && "${PACKAGE,,}" =~ ^(gnome-.*|gsettings-desktop-schemas|yelp|mutter|nautilus|vte|gnome-terminal|tecla|gvfs|gexiv2|dconf|baobab|evince|gedit|epiphany|totem|tracker.*|grilo.*|gjs|glycin|folks|evolution.*|gtksourceview.*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|gjs|glib|glib-networking|glibmm|gmime|graphene|gsound|gtk-doc|gtkmm.*|harfbuzz|json-glib|libadwaita|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|libpeas|librsvg|libsecret|libsoup|mm-common|pango|pangomm|phodav|pygobject|rest|vte|xdg-desktop-portal-gnome)$ && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from the identified main download URL (e.g. gnome-shell-47.0.tar.xz)
    # GNOME versions might be major.minor or just major for some meta-packages, but mostly major.minor
    LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -F/ -nlae '$_=$F[$#F]; /'"${PACKAGE,,}"'-([0-9]+(?:\.[0-9]+)+)/ and print $1')
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{'"${PACKAGE,,}"'-\K[0-9]+(?:\.[0-9]+)+}ig) { print $& }' | sort -V | tail -n 1)
    fi

    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS GNOME version $LFS_VERSION with $UPSTREAM_VERSION in commands and URLs..."
        LFS_MAJOR=${LFS_VERSION%%.*}
        UP_MAJOR=${UPSTREAM_VERSION%%.*}
        
        # Replace major version directory in URLs (e.g. /47/ -> /50/)
        COMMANDS="${COMMANDS//\/$LFS_MAJOR\//\/$UP_MAJOR\/}"
        # Replace full version string
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        
        # Manually update the download URLs and metadata
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_MAJOR/$UP_MAJOR}"
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_VERSION/$UPSTREAM_VERSION}"
        done
        MAIN_FILENAME="${MAIN_FILENAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//\/$LFS_MAJOR\//\/$UP_MAJOR\/}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//$LFS_VERSION/$UPSTREAM_VERSION}"
        DIRNAME="${DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        GEN_DIRNAME="${GEN_DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "libuv" && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from HTML content (before it gets overwritten or supplemented)
    LFS_VERSION=$(echo "$HTML_CONTENT" | perl -nle 'while (m{libuv-v\K[0-9]+(?:\.[0-9]+)+}g) { print $& }' | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{libuv-v\K[0-9]+(?:\.[0-9]+)+}g) { print $& }' | head -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{v\K[0-9]+(?:\.[0-9]+)+}g) { print $& }' | head -n 1)
    fi
    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS libuv version $LFS_VERSION with $UPSTREAM_VERSION in commands and URLs..."
        COMMANDS="${COMMANDS//v$LFS_VERSION/v$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_VERSION/$UPSTREAM_VERSION}"
        done
        MAIN_FILENAME="${MAIN_FILENAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//$LFS_VERSION/$UPSTREAM_VERSION}"
        DIRNAME="${DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        GEN_DIRNAME="${GEN_DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

# Replace hardcoded Rust versions and dates when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "rustc" && -n "$UPSTREAM_VERSION" ]]; then
    # 1. Replace dates
    # Find the LFS date in commands or URLs
    LFS_DATE=$(echo "$COMMANDS" | perl -nle 'if (/([0-9]{4}-[0-9]{2}-[0-9]{2})/) { print $1; exit }')
    if [[ -z "$LFS_DATE" ]]; then
         LFS_DATE=$(printf "%s\n" "${DOWNLOAD_URLS[@]}" | perl -nle 'if (/([0-9]{4}-[0-9]{2}-[0-9]{2})/) { print $1; exit }')
    fi
    if [[ -n "$LFS_DATE" && -n "$UPSTREAM_DATE" ]]; then
        log "Replacing LFS Rust date $LFS_DATE with $UPSTREAM_DATE..."
        COMMANDS=$(echo "$COMMANDS" | sed "s|$LFS_DATE|$UPSTREAM_DATE|g")
        for i in "${!DOWNLOAD_URLS[@]}"; do
            # Protect bootstrap URLs (if they were already there, though they shouldn't be yet)
            if [[ "${DOWNLOAD_URLS[$i]}" =~ /dist/[0-9]{4}-[0-9]{2}-[0-9]{2}/ ]]; then
                 continue
            fi
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_DATE/$UPSTREAM_DATE}"
        done
    fi

    # 2. Replace all versions (global replacement)
    # Find all versions appearing in rust-related contexts (e.g. 1.93.1, 1.93.0)
    # We use perl to extract anything that looks like 1.X.Y
    mapfile -t FOUND_VERSIONS < <(echo "$COMMANDS ${DOWNLOAD_URLS[*]}" | perl -nle 'while (m{1\.[0-9]+\.[0-9]+}g) { print "$&\n" }' | sort -u)
    for v in "${FOUND_VERSIONS[@]}"; do
        [[ -z "$v" ]] && continue
        if [[ "$v" != "$UPSTREAM_VERSION" ]]; then
            log "Replacing LFS Rust-related version $v with $UPSTREAM_VERSION in commands..."
            COMMANDS=$(echo "$COMMANDS" | sed "s|$v|$UPSTREAM_VERSION|g")
            for i in "${!DOWNLOAD_URLS[@]}"; do
                # Protect bootstrap URLs from being modified
                if [[ "${DOWNLOAD_URLS[$i]}" =~ /dist/[0-9]{4}-[0-9]{2}-[0-9]{2}/ ]]; then
                     continue
                fi
                DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$v/$UPSTREAM_VERSION}"
            done
        fi
    done
fi

# Finally add Rust bootstrap binaries AFTER replacements are complete
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "rustc" && -n "$PREV_VERSION" && -n "$PREV_DATE" ]]; then
    log "Found bootstrap version $PREV_VERSION (date: $PREV_DATE). Adding to downloads."
    DOWNLOAD_URLS+=("https://static.rust-lang.org/dist/${PREV_DATE}/rustc-${PREV_VERSION}-x86_64-unknown-linux-gnu.tar.xz")
    DOWNLOAD_URLS+=("https://static.rust-lang.org/dist/${PREV_DATE}/rust-std-${PREV_VERSION}-x86_64-unknown-linux-gnu.tar.xz")
    DOWNLOAD_URLS+=("https://static.rust-lang.org/dist/${PREV_DATE}/cargo-${PREV_VERSION}-x86_64-unknown-linux-gnu.tar.xz")
fi

# Generic version replacement for any package that successfully resolved UPSTREAM_VERSION via fallback
if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" && -n "$MAIN_DOWNLOAD_URL" && ! "${PACKAGE,,}" =~ ^(linux|firefox|rustc|libuv)$ && ! "${PACKAGE,,}" =~ ^(konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)$ && ! "${PACKAGE,,}" =~ ^(gnome-.*|gsettings-desktop-schemas|yelp|mutter|nautilus|vte|gnome-terminal|tecla|gvfs|gexiv2|dconf|baobab|evince|gedit|epiphany|totem|tracker.*|grilo.*|gjs|glycin|folks|evolution.*|gtksourceview.*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|glib|glib-networking|glibmm|gmime|graphene|gsound|gtk-doc|gtkmm.*|harfbuzz|json-glib|libadwaita|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|libpeas|librsvg|libsecret|libsoup|mm-common|pango|pangomm|phodav|pygobject|rest|xdg-desktop-portal-gnome)$ ]]; then
    # Extract LFS version from the identified main download URL
    LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle "while (m{${PACKAGE}-\K[0-9]+(?:\.[0-9]+)+[a-zA-Z0-9_-]*}g) { print \$& }" | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle 'while (m{/v?\K[0-9]+(?:\.[0-9]+)+[a-zA-Z0-9_-]*(?=/)}g) { print $& }' | head -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle 'while (m{[0-9]+(?:\.[0-9]+)+[a-zA-Z0-9_-]*}g) { print $& }' | head -n 1)
    fi

    if [[ -n "$LFS_VERSION" && "$LFS_VERSION" != "$UPSTREAM_VERSION" ]]; then
        log "Replacing LFS version $LFS_VERSION with $UPSTREAM_VERSION generically in commands and URLs..."
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_VERSION/$UPSTREAM_VERSION}"
        done
        MAIN_FILENAME="${MAIN_FILENAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        MAIN_DOWNLOAD_URL="${MAIN_DOWNLOAD_URL//$LFS_VERSION/$UPSTREAM_VERSION}"
        DIRNAME="${DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
        GEN_DIRNAME="${GEN_DIRNAME//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

# Pre-download Rust bootstrap binaries caching logic (Dynamic Detection on Guest)
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "rustc" ]]; then
    log "Injecting dynamic Rust bootstrap detection and caching logic..."
    
    # We inject a shell block that will run on the guest AFTER extraction.
    # It parses src/stage0.json to find the EXACT version and date x.py expects.
    CACHE_CMDS="
# Dynamic Rust Bootstrap Helper
if [ -f \"src/stage0.json\" ]; then
    # Try parsing with python3 (reliable) or grep/sed (fallback)
    BT_VER=\$(python3 -c \"import json; print(json.load(open('src/stage0.json'))['compiler']['version'])\" 2>/dev/null || \
             grep -A 5 '\"compiler\":' src/stage0.json | grep '\"version\":' | cut -d'\"' -f4 | head -n 1)
    BT_DATE=\$(python3 -c \"import json; print(json.load(open('src/stage0.json'))['compiler']['date'])\" 2>/dev/null || \
              grep -A 5 '\"compiler\":' src/stage0.json | grep '\"date\":' | cut -d'\"' -f4 | head -n 1)
    
    if [ -n \"\$BT_VER\" ] && [ -n \"\$BT_DATE\" ]; then
        echo \"[LFS-AUTOBUILD] Detected required bootstrap: \$BT_VER (\$BT_DATE)\"
        CACHE_DIR=\"build/cache/\$BT_DATE\"
        mkdir -pv \"\$CACHE_DIR\"
        for comp in rustc rust-std cargo; do
            fname=\"\${comp}-\${BT_VER}-x86_64-unknown-linux-gnu.tar.xz\"
            if [ ! -f \"/sources/\$fname\" ]; then
                echo \"[LFS-AUTOBUILD] Downloading missing bootstrap component: \$fname\"
                wget -nc \"https://static.rust-lang.org/dist/\${BT_DATE}/\${fname}\" -P /sources/
            fi
            ln -sf \"/sources/\$fname\" \"\$CACHE_DIR/\"
        done
    else
        echo \"[WARNING] Could not detect bootstrap version from src/stage0.json\"
    fi
fi"

    # Inject before ./x.py build
    if [[ "$COMMANDS" == *"./x.py build"* ]]; then
        # Escape ampersands in replacement string to prevent bash's ${var//pat/repl} from mangling them
        CACHE_CMDS_ESC="${CACHE_CMDS//&/\\&}"
        COMMANDS="${COMMANDS//.\/x.py build/$CACHE_CMDS_ESC
./x.py build}"
    else
        # Fallback: prepend to COMMANDS
        COMMANDS="$CACHE_CMDS
$COMMANDS"
    fi
fi

# Fix missing LINGUAS file in glycin upstream tarball
if [[ "$PACKAGE" == "glycin" ]]; then
    log "Injecting LINGUAS file workaround for glycin..."
    COMMANDS="${COMMANDS//mkdir build &&/mkdir -p po \&\& touch po\/LINGUAS \&\& mkdir build \&\&}"
fi

# Replace hardcoded LLVM versions when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "llvm" && -n "$UPSTREAM_VERSION" ]]; then
    # 1. Broad version replacement
    FOUND_VERSIONS=()
    while IFS= read -r v; do
        [[ -n "$v" ]] && FOUND_VERSIONS+=("$v")
    done < <(echo "$COMMANDS ${DOWNLOAD_URLS[*]}" | perl -nle 'while (m{[0-9]+(?:\.[0-9]+)+}g) { print "$&\n" }' | sort -u)
    for v in "${FOUND_VERSIONS[@]}"; do
        [[ -z "$v" ]] && continue
        if [[ "$v" != "$UPSTREAM_VERSION" ]]; then
            log "Replacing LFS LLVM-related version $v with $UPSTREAM_VERSION in commands..."
            COMMANDS=$(echo "$COMMANDS" | sed "s|$v|$UPSTREAM_VERSION|g")
            for i in "${!DOWNLOAD_URLS[@]}"; do
                DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$v/$UPSTREAM_VERSION}"
            done
        fi
    done

    # 2. Adjust for monorepo structure
    if [[ "$UPSTREAM" == "true" ]] && (printf "%s\n" "${DOWNLOAD_URLS[@]}" | grep -q "llvm-project-"); then
        log "LLVM monorepo detected. Sterilizing build commands for monorepo structure..."
        
        # Neutralize redundant extraction/installation/patching steps that are already in the monorepo
        # We replace them with 'true ' to keep the '&&' command chain intact and valid.
        # We use perl for multi-line matching and broad pattern recognition.
        COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe '
            s/tar -xf \.\.\/[^ \n]*?(llvm-cmake|llvm-third-party|clang-|compiler-rt-|clang-tools-extra-)[^ \n]*.*?(?=\s*&&|\n|\$)/true /gs;
            s/mv (tools|projects)\/(clang|compiler-rt)-[^ \n]* (tools|projects)\/(clang|compiler-rt)(?=\s*&&|\n|\$)/true /gs;
            # Catch multi-line sed with backslashes specifically for LLVM path adjustments
            # Matches '\''sed'\'' followed by anything containing '\''../cmake'\'' or '\''../third-party'\'' up to '\''-i [file]'\''
            s/sed .*?(\.\.\/cmake|\.\.\/third-party|LLVM_COMMON_CMAKE_UTILS|LLVM_THIRD_PARTY_DIR).*?-i [^ \n]+(?=\s*&&|\n|\$)/true /gs;
            # Fix component paths for monorepo: e.g. ../projects/compiler-rt -> ../../compiler-rt (since we build in llvm/build)
            s/\.\.\/(projects|tools)\/(compiler-rt|clang|lld|polly|openmp|libcxx|libcxxabi|libunwind|clang-tools-extra)/..\/..\/\2/g;
            # Strip llvm/ prefix from paths since we already cd into llvm/
            s/\bllvm\/(utils|include|lib|cmake|projects|tools|runtimes|test|docs|examples|benchmarks|unittests|build)(?=\/|\s|$)/$1/g;
            # Enable projects in cmake if not already present
            s/cmake (?!.*LLVM_ENABLE_PROJECTS)/cmake -D LLVM_ENABLE_PROJECTS="clang;compiler-rt" /g;
            # Add -j$(nproc) to ninja commands if not already present
            s/ninja(?!.*-j)/ninja -j\$(nproc)/g;
        ')

        # Filter out 404-prone individual component URLs if we have the monorepo
        log "Filtering redundant LLVM component URLs..."
        NEW_URLS=()
        for url in "${DOWNLOAD_URLS[@]}"; do
            # Keep monorepo and patches
            if [[ "$url" == *"llvm-project-"* ]] || [[ "$url" == *".patch" ]]; then
                NEW_URLS+=("$url")
            # Skip individual component tarballs
            elif [[ "$(basename "$url")" =~ ^(llvm-|clang-|cmake-|third-party-|compiler-rt-|clang-tools-extra-)[0-9] ]]; then
                continue
            else
                NEW_URLS+=("$url")
            fi
        done
        DOWNLOAD_URLS=("${NEW_URLS[@]}")
    fi
fi

# Skip logic for official packages
if [[ "$FORCE" != "true" ]]; then
    # Identify target version for comparison
    TARGET_VER="$LFS_VERSION"
    [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" ]] && TARGET_VER="$UPSTREAM_VERSION"

    # In Xorg multi-package mode, LFS_VERSION is never extracted from the URL block.
    # Try to recover it from DOWNLOAD_URLS by finding the URL that matches $PACKAGE.
    if [[ -z "$TARGET_VER" && "$XORG_MULTI_MODE" == "true" && ${#DOWNLOAD_URLS[@]} -gt 0 ]]; then
        pkg_lower="${PACKAGE,,}"
        for _url in "${DOWNLOAD_URLS[@]}"; do
            _fname=$(basename "$_url")
            # Match: libXpm-3.5.17.tar.xz  (case-insensitive on package name)
            if echo "$_fname" | grep -qi "^${pkg_lower}[-_][0-9]"; then
                TARGET_VER=$(echo "$_fname" | perl -nle 'while (m{[-_]\K[0-9][0-9a-z.]*(?:\.[0-9]+[a-z0-9.]*)*}g) { print $& }' | head -n 1 | sed -E 's/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2)$//')
                [[ -n "$TARGET_VER" ]] && log "Extracted Xorg multi-mode version for $PACKAGE from URL: $TARGET_VER" && break
            fi
        done
    fi

    # Identify installed version
    INSTALLED_VER=$(ssh_lfs "[ -f /var/lib/book-packages/$PACKAGE ] && head -n 1 /var/lib/book-packages/$PACKAGE" 2>/dev/null | tr -d '\r')
    
    if [[ -n "$INSTALLED_VER" && -n "$TARGET_VER" ]]; then
        if [[ "$INSTALLED_VER" == "$TARGET_VER" ]]; then
            log "[LFS-AUTOBUILD] Skipping already installed package: $PACKAGE (version $INSTALLED_VER, use -f to force rebuild)"
            continue
        fi
    elif [[ -n "$INSTALLED_VER" ]]; then
        # If we have it installed but couldn't determine target version from book/upstream,
        # we still skip by default unless forced.
        log "[LFS-AUTOBUILD] Skipping already installed package (target version unknown): $PACKAGE (use -f to force rebuild)"
        continue
    fi
fi

# Early URL rewriting for KDE single packages to prevent pruning
if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" ]] && [[ "${DOWNLOAD_URLS[*]}" == *"download.kde.org"* || "${DOWNLOAD_URLS[*]}" == *"invent.kde.org"* ]]; then
    log "Rewriting KDE download URLs for upstream version..."
    KDE_LFS_VER=$(printf "%s\n" "${DOWNLOAD_URLS[@]}" | perl -nle 'while (m{-(?:[a-zA-Z]+-)?\K[0-9]+(?:\.[0-9]+)+(?=\.tar)}ig) { print $& }' | sort -V | tail -n 1)
    if [[ -n "$KDE_LFS_VER" && "$KDE_LFS_VER" != "$UPSTREAM_VERSION" ]]; then
        KDE_UP_FULL="$UPSTREAM_VERSION"
        if [[ $(echo "$KDE_UP_FULL" | grep -o '\.' | wc -l) -eq 1 ]]; then
            KDE_UP_FULL="${KDE_UP_FULL}.0"
        fi
        KDE_LFS_MM=$(echo "$KDE_LFS_VER" | cut -d. -f1,2)
        KDE_UP_MM=$(echo "$UPSTREAM_VERSION" | cut -d. -f1,2)
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]=$(echo "${DOWNLOAD_URLS[$i]}" | sed "s/$KDE_LFS_VER/$KDE_UP_FULL/g; s|/$KDE_LFS_MM/|/$KDE_UP_MM/|g")
        done
        MAIN_DOWNLOAD_URL=$(echo "$MAIN_DOWNLOAD_URL" | sed "s/$KDE_LFS_VER/$KDE_UP_FULL/g; s|/$KDE_LFS_MM/|/$KDE_UP_MM/|g")
        # Also substitute versions inside COMMANDS
        if [[ "$PLASMA_MODE" == "true" ]]; then
            # For Plasma, we must also switch from frameworks to plasma path if the book used it as a template
            COMMANDS=$(echo "$COMMANDS" | sed "s|/frameworks/$KDE_LFS_MM/|/plasma/$KDE_UP_FULL/|g; s|/frameworks/|/plasma/|g; s/$KDE_LFS_VER/$KDE_UP_FULL/g")
        else
            COMMANDS=$(echo "$COMMANDS" | sed "s/$KDE_LFS_VER/$KDE_UP_FULL/g; s|/$KDE_LFS_MM/|/$KDE_UP_MM/|g")
        fi
    fi
fi

# Final filtering for Rust upstream to ensure NO redundant binaries are fetched
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "rustc" ]]; then
    log "Finalizing Rust download URLs (keeping only source and bootstrap)..."
    NEW_URLS=()
    for url in "${DOWNLOAD_URLS[@]}"; do
        fname=$(basename "$url")
        # Keep source, and keep the specific bootstrap binaries we added.
        # Upstream source has -src.tar. in name. Bootstraps are in /dist/YYYY-MM-DD/ paths.
        if [[ "$fname" =~ -src\.tar\. ]] || [[ "$url" =~ /dist/[0-9]{4}-[0-9]{2}-[0-9]{2}/ ]]; then
            NEW_URLS+=("$url")
        fi
    done
    DOWNLOAD_URLS=("${NEW_URLS[@]}")
fi

# Generic filtering for ALL upstream-enabled packages (except Rust which is handled above):
# Remove archives that do not match the UPSTREAM_VERSION if it is set.
if [[ "$UPSTREAM" == "true" && -n "$UPSTREAM_VERSION" && "$PACKAGE" != "rustc" ]]; then
    log "Filtering redundant stable archives (keeping version $UPSTREAM_VERSION)..."
    NEW_URLS=()
    for url in "${DOWNLOAD_URLS[@]}"; do
        fname=$(basename "$url")
        # If it is an archive for this package but has a different version, skip it.
        # We check for .tar.*, .zip, .tgz to avoid accidentally skipping patches.
        if [[ "$fname" =~ ^${PKG_BASE}[-_]?[0-9] ]] && [[ "$fname" =~ \.(tar\.[a-z2]+|zip|tgz)$ ]]; then
            if [[ "$fname" == *"$UPSTREAM_VERSION"* ]] || { [[ "$UPSTREAM_VERSION" =~ \.0$ ]] && [[ "$fname" == *"${UPSTREAM_VERSION%.0}"* ]]; }; then
                NEW_URLS+=("$url")
            else
                log "Pruning redundant stable version: $fname"
            fi
        else
            # Keep patches and anything else
            NEW_URLS+=("$url")
        fi
    done
    DOWNLOAD_URLS=("${NEW_URLS[@]}")
    
    # Synchronize filenames/dirnames with the chosen upstream version
    if [[ ${#DOWNLOAD_URLS[@]} -gt 0 ]]; then
        # Use the first archive found as the new MAIN_FILENAME
        for url in "${DOWNLOAD_URLS[@]}"; do
            fname=$(basename "$url")
            if [[ "$fname" =~ \.(tar\.[a-z2]+|zip|tgz)$ ]]; then
                MAIN_FILENAME="$fname"
                # Update DIRNAME/GEN_DIRNAME by stripping the extension
                DIRNAME=$(echo "$fname" | sed 's/\.tar.*//; s/\.zip$//; s/\.tgz$//')
                GEN_DIRNAME="$DIRNAME"
                break
            fi
        done
    fi
fi

# Deduplicate DOWNLOAD_URLS while preserving order as much as possible
if [[ ${#DOWNLOAD_URLS[@]} -gt 0 ]]; then
    mapfile -t DOWNLOAD_URLS < <(printf "%s\n" "${DOWNLOAD_URLS[@]}" | awk '!x[$0]++')
fi



# For plasma/frameworks, prevent wget -r from re-downloading already-fetched archives
# and avoid the "rejected" loop caused by -A and mirror redirects.
if [[ "${PACKAGE,,}" == "plasma" || "${PACKAGE,,}" == "plasma-all" || \
      "${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "frameworks6" || \
      "${METAPACKAGE_TARGET,,}" == "plasma-all" || "${METAPACKAGE_TARGET,,}" == "frameworks6" ]]; then
    # We don't need the recursive wget command from the book because we download files directly using DOWNLOAD_URLS
    COMMANDS=$(echo "$COMMANDS" | sed -E '/^url=https:\/\/download\.kde\.org/d; /^wget -r -nH/d')
    # Remove redundant wget index downloads for KDE if they were prepended
    COMMANDS=$(echo "$COMMANDS" | sed -E 's@^wget -nc https://download.kde.org/stable/(frameworks|plasma)/[0-9.]+/?\s*$@@g')
fi

if [[ "$PACKAGE" == "sddm" ]]; then
    log "Removing legacy /opt/xorg ServerPath modification for sddm..."
    COMMANDS=$(echo "$COMMANDS" | grep -v "sed -i.orig '/ServerPath/ s|usr|opt/xorg|' /etc/sddm.conf")
fi




# Populate ALL_FILENAMES from DOWNLOAD_URLS for all modes
ALL_FILENAMES=()
for url in "${DOWNLOAD_URLS[@]}"; do
    ALL_FILENAMES+=("$(basename "$url")")
done

if [[ "$FRAMEWORKS_MODE" == "true" || "$XORG_MULTI_MODE" == "true" ]]; then
    MAIN_FILENAME="$PACKAGE"
    DIRNAME="$PACKAGE"
else
    MAIN_FILENAME=$(basename "$MAIN_DOWNLOAD_URL")
    DIRNAME=$(echo "$MAIN_FILENAME" | sed 's/\.tar.*//; s/\.zip//')
fi

# Handle KDE metapackage version substitution after initial variable assignments
if [[ "$UPSTREAM" == "true" && ("${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "breeze-icons" || "${PACKAGE,,}" == "plasma-all" || "${PACKAGE,,}" == "plasma" || "${PACKAGE,,}" == "extra-cmake-modules" || "${METAPACKAGE_TARGET,,}" == "frameworks6" || "${METAPACKAGE_TARGET,,}" == "plasma-all") && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (now including absolute paths like /sources/archives/plasma-6.6.1.md5)
    # Match version string that ends with a digit to avoid eating the trailing dot
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{/archives/(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-\K[0-9]+(\.[0-9]+)+}g) { print $& }' | sort -V | tail -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-\K[0-9]+(\.[0-9]+)+}g) { print $& }' | sort -V | tail -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        # Last resort: extract from the package's tarball
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{'"${PACKAGE,,}"'-\K[0-9]+(?:\.[0-9]+)+(?=\.tar)}ig) { print $& }' | sort -V | tail -n 1)
    fi

    if [[ -n "$LFS_VERSION" ]]; then
        UPSTREAM_FULL="${UPSTREAM_VERSION}"
        if [[ $(echo "$UPSTREAM_FULL" | grep -o '\.' | wc -l) -eq 1 ]]; then
            UPSTREAM_FULL="${UPSTREAM_FULL}.0"
        fi
        
        # Define LFS_MM and UPSTREAM_MM (e.g. 6.23 from 6.23.0)
        LFS_MM=$(echo "$LFS_VERSION" | cut -d. -f1,2)
        UPSTREAM_MM=$(echo "$UPSTREAM_FULL" | cut -d. -f1,2)
        
        log "[DEBUG] KDE Version Substitution: LFS_VERSION='$LFS_VERSION', LFS_MM='$LFS_MM', UPSTREAM_FULL='$UPSTREAM_FULL', UPSTREAM_MM='$UPSTREAM_MM'"

        # Use perl for complex heredoc and regex substitution
        COMMANDS=$(echo "$COMMANDS" | LFS_VERSION="$LFS_VERSION" UPSTREAM_FULL="$UPSTREAM_FULL" LFS_MM="$LFS_MM" UPSTREAM_MM="$UPSTREAM_MM" perl -0777 -pe '
            my $lv = $ENV{LFS_VERSION};
            my $uf = $ENV{UPSTREAM_FULL};
            my $lmm = $ENV{LFS_MM};
            my $umm = $ENV{UPSTREAM_MM};

            # 1. Update the MD5 filename in the cat heredoc trigger (match frameworks, plasma, etc. dynamically)
            s!((?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;
            s!(\/sources\/archives\/(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;
            s!/stable/frameworks/$lmm/!/stable/frameworks/$umm/!g;
            s!/stable/plasma/$lmm/!/stable/plasma/$umm/!g;

            # 2. Process the MD5 file content: update all versions inside the heredoc
            s!((cat > (?:/sources/archives/)?(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)\Q$lv\E\.md5 << \"?EOF\"?\n)(.*?)(\nEOF)!
                do {
                    my $header = $1;
                    my $body = $3;
                    my $footer = $4;
                    $body =~ s/\Q$lv\E/$uf/g; # Replace LFS version with upstream
                    $body =~ s/6\.\d+(?:\.\d+){0,2}/$uf/og; # Fallback generic replacement
                    $header . $body . $footer
                }
            !gse;

            # 3. Update the done < redirection
            s!(done < (?:/sources/archives/)?(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;

            # 4. Global version string replacement (be careful not to break other things)
            # Replace full version
            s/\Q$lv\E/$uf/g;
            
            # Replace major.minor in URLs, e.g. /6.23/ to /6.26/
            s!/$lmm/!/$umm/!g;
        ')
        
        # Update core variables so they match the substituted commands
        VERSION="$UPSTREAM_FULL"
        packagedir="${PACKAGE}-${VERSION}"
        DIRNAME="${packagedir}"
        GEN_DIRNAME="${packagedir}"
        MAIN_FILENAME="${packagedir}.tar.xz"
        log "Updated build variables to match KDE upstream version $VERSION"
    fi
fi

# For KDE Plasma/Frameworks single-package builds: rewrite bare `tar -xf foo-X.Y.Z.tar.xz`
# commands in COMMANDS to use an absolute /sources/archives/ path so they work from any
# working directory.  Then add those archives to DOWNLOAD_URLS so they get fetched.
if [[ ("$PLASMA_MODE" == "true" || "$FRAMEWORKS_MODE" == "true") && "$PACKAGE" != "plasma-all" && "$PACKAGE" != "frameworks6" ]]; then
    _kde_ver="${UPSTREAM_FULL:-$LFS_VERSION}"
    if [[ "$PLASMA_MODE" == "true" ]]; then
        _kde_dep_base_url="https://download.kde.org/stable/plasma/${_kde_ver}/"
    else
        _kde_dep_mm=$(echo "$_kde_ver" | cut -d. -f1,2)
        _kde_dep_base_url="https://download.kde.org/stable/frameworks/${_kde_dep_mm}/"
    fi

    # Rewrite: `tar -xf foo-6.6.5.tar.xz` → `tar -xf /sources/archives/foo-6.6.5.tar.xz`
    # Handle variations like -xvf, -Jxf, etc. and various version patterns (6.6, 6.6.5, etc.)
    # Avoid variable-length lookbehind for compatibility
    COMMANDS=$(echo "$COMMANDS" | perl -pe '
        s{(tar\s+-[a-zA-Z]*x[a-zA-Z]*\s+)(?!/)([a-zA-Z0-9_-]+-[0-9]+(\.[0-9]+)*\.(tar\.[a-z0-9]+|zip|tgz|tbz2))}{$1/sources/archives/$2}g
    ')

    # Now find every /sources/archives/<name>.tar.xz reference and add missing ones to DOWNLOAD_URLS
    _existing_fnames=$(printf "%s\n" "${DOWNLOAD_URLS[@]}" | xargs -I{} basename {} 2>/dev/null)
    while IFS= read -r _tar_ref; do
        _tar_base=$(basename "$_tar_ref")
        if echo "$_existing_fnames" | grep -qxF "$_tar_base"; then
            continue
        fi
        _new_url="${_kde_dep_base_url}${_tar_base}"
        log "Auto-adding KDE dependency archive: $_tar_base"
        DOWNLOAD_URLS+=("$_new_url")
        ALL_FILENAMES+=("$_tar_base")
        _existing_fnames+=$'\n'"$_tar_base"
    done < <(echo "$COMMANDS" | grep -oE 'tar -[a-zA-Z]*x[a-zA-Z]* /sources/archives/[^ \t\n\r\f\v]+\.(tar\.[a-z0-9]+|zip|tgz|tbz2)' | awk '{print $NF}' | sort -u)

    # Note: We used to try to download the MD5 file here, but it's redundant because
    # the KDE build loop script (extracted from BLFS) already contains a heredoc
    # that generates the required MD5 file locally. Downloading from the mirror 
    # frequently 404s and is unnecessary.
    :
fi


# For LLVM monorepo, the actual build should happen in the llvm/ subdirectory
# to ensure all relative paths in BLFS instructions work correctly across all blocks.
# We adjust the DIRNAME variable used for build script generation specifically.
GEN_DIRNAME="$DIRNAME"
if [[ "$PACKAGE" == "llvm" && "$MAIN_FILENAME" == *"llvm-project-"* ]]; then
    GEN_DIRNAME="${DIRNAME}/llvm"
fi
# Generate BUILD_SCRIPT from annotated COMMANDS: user blocks run via su, root blocks run as root
# This runs on the HOST - generates the VM-side build script with privilege separation
_gen_build_script() {
    local dirname="$1"
    local normal_user="$2"
    local setup_cmds="$3"
    local lfs_version="$4"
    local in_section=""
    local block_n=0
    local user_lines=()
    local current_rel_dir="."
    local block_starting_rel_dir="."


    # Internal helper to flush accumulated user commands into an su block
    _flush_user() {
        if [[ ${#user_lines[@]} -gt 0 ]]; then
            ((block_n++))
            local sentinel="__LFS_USER_${block_n}__"
            echo "sudo -u '${normal_user}' /bin/bash << '${sentinel}'"
            echo "set -e"
            echo "export PATH=\"/usr/bin:/usr/sbin:/bin:/sbin:\$PATH\""
            # Redefine as_root inside the USER block: sudo -u strips BASH_FUNC_* env vars
            echo "as_root() {"
            echo "  if [ \${EUID:-\$(id -u)} = 0 ]; then"
            echo "    \"\$@\""
            echo "  elif [ -x /usr/bin/sudo ]; then"
            echo "    sudo \"\$@\""
            echo "  else"
            echo "    su -c \"\$*\""
            echo "  fi"
            echo "}"
            # Ensure each USER block starts with setup commands
            if [[ -n "$setup_cmds" ]]; then
                echo "$setup_cmds"
            fi
            # Ensure each USER block starts in the tracked directory
            echo "cd \"/sources/${dirname}/${block_starting_rel_dir}\" || cd \"/sources/${dirname}\""
            printf '%s\n' "${user_lines[@]}"
            echo "${sentinel}"
            user_lines=()
        fi
    }

    # Internal helper to track CWD changes across commands
    _update_cwd() {
        local line="$1"
        # 1. Strip carriage returns and leading/trailing whitespace
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 2. Split line into individual commands by separators (&&, ||, ;)
        local cmds
        cmds=$(echo "$line" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g')
        
        while read -r cmd; do
            [[ -z "$cmd" ]] && continue
            # Match 'cd' with various quoting styles. Avoiding \b which is not portable in bash [[ =~ ]].
            local target=""
            if [[ "$cmd" =~ (^|[[:space:]])(cd|pushd)[[:space:]]+\"([^\"]+)\" ]]; then
                target="${BASH_REMATCH[3]}"
            elif [[ "$cmd" =~ (^|[[:space:]])(cd|pushd)[[:space:]]+\'([^\']+)\' ]]; then
                target="${BASH_REMATCH[3]}"
            elif [[ "$cmd" =~ (^|[[:space:]])(cd|pushd)[[:space:]]+([^[:space:]&;\|]+) ]]; then
                target="${BASH_REMATCH[3]}"
            elif [[ "$cmd" =~ (^|[[:space:]])popd([[:space:]]|$) ]]; then
                target=".."
            fi

            if [[ -n "$target" ]]; then
                if [[ "$target" == /* ]]; then
                    # Absolute path
                    if [[ "$target" == "/sources/${dirname}" ]]; then
                        current_rel_dir="."
                    elif [[ "$target" == "/sources/${dirname}/"* ]]; then
                        current_rel_dir="${target#/sources/${dirname}/}"
                    else
                        current_rel_dir="."
                    fi
                else
                    # Relative path (could contain multiple levels or ..)
                    local IFS='/'
                    local parts
                    read -ra parts <<< "$target"
                    for p in "${parts[@]}"; do
                        [[ -z "$p" || "$p" == "." ]] && continue
                        if [[ "$p" == ".." ]]; then
                            current_rel_dir=$(dirname "$current_rel_dir")
                        else
                            [[ "$current_rel_dir" == "." ]] && current_rel_dir=""
                            current_rel_dir="${current_rel_dir}/${p}"
                        fi
                    done
                fi
            fi
        done <<< "$cmds"
        
        # 3. Final normalization
        current_rel_dir=$(echo "$current_rel_dir" | sed 's|//*|/|g; s|^/||; s|/$||')
        [[ -z "$current_rel_dir" || "$current_rel_dir" == "/" ]] && current_rel_dir="."
    }

    echo "#!/bin/bash"
    echo "set -e"

    # Always define as_root at the top of every generated script
    echo "as_root() {"
    echo "  if [ \${EUID:-\$(id -u)} = 0 ]; then"
    echo "    \"\$@\""
    echo "  elif command -v sudo >/dev/null 2>&1; then"
    echo "    sudo \"\$@\""
    echo "  else"
    echo "    su -c \"\$*\""
    echo "  fi"
    echo "}"
    echo "export -f as_root"
    echo "BUILD_DIR=\"/sources/${dirname}\""
    echo "# Grant regular user access to build directory for compilation"
    echo "chown -R '${normal_user}' \"/sources/${dirname}\" 2>/dev/null || true"
    echo "cd '/sources/${dirname}'"

    while IFS= read -r line; do
        if [[ "$line" == "# __BEGIN_ROOT__" ]]; then
            _flush_user
            in_section="root"
            # Start a single root shell for this block
            echo "as_root bash << 'ROOTEOF'"
            echo "set -e"
            # Redefine as_root inside the ROOT block for robustness
            echo "as_root() {"
            echo "  if [ \${EUID:-\$(id -u)} = 0 ]; then"
            echo "    \"\$@\""
            echo "  elif [ -x /usr/bin/sudo ]; then"
            echo "    sudo \"\$@\""
            echo "  else"
            echo "    su -c \"\$*\""
            echo "  fi"
            echo "}"
            # Ensure ROOT blocks start with setup commands
            if [[ -n "$setup_cmds" ]]; then
                echo "$setup_cmds"
            fi
            # Ensure ROOT blocks start in the tracked directory
            echo "cd \"/sources/${dirname}/${current_rel_dir}\" || cd \"/sources/${dirname}\""
        elif [[ "$line" == "# __END_ROOT__" ]]; then
            echo "ROOTEOF"
            in_section=""
            echo "chown -R '${normal_user}' \"/sources/${dirname}\" 2>/dev/null || true"
        elif [[ "$line" == "# __BEGIN_USER__" ]]; then
            in_section="user"
            block_starting_rel_dir="$current_rel_dir"
        elif [[ "$line" == "# __END_USER__" ]]; then
            _flush_user
            in_section=""
        elif [[ "$in_section" == "root" ]]; then
            echo "$line"
            _update_cwd "$line"
        else
            user_lines+=("$line")
            _update_cwd "$line"
        fi
    done <<< "$COMMANDS"
    # Ensure any final root block is closed (should have been handled by __END_ROOT__ but for safety)
    if [[ "$in_section" == "root" ]]; then
        echo "ROOTEOF"
    fi
    _flush_user
}

# Detect the normal (non-root) user on the VM for privilege dropping
# Use the SSH login user (the user who invoked ssh_lfs)
NORMAL_USER="${USER:-fusion809}"

# Final verification of download URLs and filename before syncing to VM
if [[ "$DRY_RUN" == "true" ]]; then
    echo "------------------------------------------------------------"
    echo "DRY RUN: Download URLs for $PACKAGE"
    echo "------------------------------------------------------------"
    for url in "${DOWNLOAD_URLS[@]}"; do echo "$url"; done
    echo "------------------------------------------------------------"
    echo "DRY RUN: Commands for $PACKAGE (annotated with privilege level)"
    echo "------------------------------------------------------------"
    if [[ -n "$SETUP_COMMANDS" ]]; then
        echo "[GLOBAL SETUP]"
        echo "$SETUP_COMMANDS" | sed 's/^/  /'
    fi
    _cur_priv="[USER]"
    while IFS= read -r _line; do
        case "$_line" in
            "# __BEGIN_ROOT__") _cur_priv="[ROOT]" ;;
            "# __END_ROOT__")   _cur_priv="[USER]" ;;
            "# __BEGIN_USER__") _cur_priv="[USER]" ;;
            "# __END_USER__")   _cur_priv="[USER]" ;;
            *) [[ -n "$_line" ]] && echo "${_cur_priv} ${_line}" ;;
        esac
    done <<< "$COMMANDS"
    echo "------------------------------------------------------------"
    if [[ "$STRIP" == "true" ]]; then
        if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
            source "$NIXCFG/shell/user/21-lfs.sh"
            lfs_strip --dry-run
        else
            echo "DRY RUN: STRIP skipped because 21-lfs.sh is not available locally."
        fi
    fi
    exit 0
fi

# 4. Remote Execution

    # Fix the bash subshell and execution
    if [[ "$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true" ]]; then
        log "Converting build loop into a standalone script..."
        # Substitute old LFS versions with upstream version inside the build script (fixes MD5 matching)
        if [[ -n "$UPSTREAM_FULL" && -n "$LFS_VERSION" && "$UPSTREAM_FULL" != "$LFS_VERSION" ]]; then
            COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_FULL}"
            COMMANDS="${COMMANDS//$LFS_MM/$UPSTREAM_MM}"
        fi
        
        # Preserve block markers for root identification
        # We use a temporary variable for the awk script to avoid replacing COMMANDS
        # until the very end, ensuring extractions (filenames, versions) use the full text.
        
        # If we are building a specific metapackage component, uncomment it in the md5 list
        # so the while-loop in the generated script does not skip it.
        if [[ -n "$METAPACKAGE_TARGET" ]]; then
            COMMANDS=$(echo "$COMMANDS" | perl -pe "s/^[ \t]*#[ \t]*([0-9a-fA-F]+[ \t]+${METAPACKAGE_TARGET}[-_])/\1/g")
        fi

        KDE_GENERATED_SCRIPT=$(echo "$COMMANDS" | awk -v pkg="$PACKAGE" -v force="$FORCE" -v ver="${UPSTREAM_FULL:-$LFS_VERSION}" -v mm="${UPSTREAM_MM:-$LFS_MM}" '
            BEGIN {
                in_loop = 0; in_as_root = 0; in_md5 = 0; in_root_block = 0;
                as_root_content = ""; other_cmds = "PACKAGE=\"" pkg "\"\nFORCE=\"" force "\""; loop_content = "";
            }
            /^# __BEGIN_ROOT__/ { 
                if (in_loop) { in_root_block = 1; next }
                other_cmds = other_cmds "\nas_root bash << \"ROOTEOF\"\n"; 
                in_root_block = 1; next 
            }
            /^# __BEGIN_USER__|^# __END_ROOT__|^# __END_USER__/ { 
                if (in_root_block && !in_loop) { other_cmds = other_cmds "\nROOTEOF\n" }
                in_root_block = 0; next 
            }
            /^as_root\(\)/ { in_as_root = 1; as_root_content = $0; next }
            /^bash -e/ { next }
            /^exit/ { next }
            /^#!/ || /^set -e/ || /^set \+e/ { next }
            /^cat > [a-z0-9.-]+\.md5 << "EOF"/ { 
                in_md5 = 1; 
                sub(/^cat > /, "cat > /sources/archives/", $0); 
                other_cmds = other_cmds "\n" $0; next 
            }
            /^cd \$packagedir/ {
                loop_content = loop_content "\n" $0
                loop_content = loop_content "\n    if [ \"$name\" = \"kauth\" ]; then"
                loop_content = loop_content "\n        perl -0777 -pi -e \x27s/string\\(REPLACE \\$\\{POLKITQT-1_INSTALL_DIR\\}[^)]+\\)/set(_KAUTH_POLICY_FILES_INSTALL_DIR \"\\${CMAKE_INSTALL_PREFIX}\\/share\\/polkit-1\\/actions\")/gs\x27 src/ConfigureChecks.cmake 2>/dev/null || true"
                loop_content = loop_content "\n    fi"
                next
            }
            /^[[:space:]]*while read( -r)? line; do/ { 
                in_loop = 1; 
                loop_content = "    while read -r line; do\n    set -e\n    cd /sources/archives\n    [[ -z \"$line\" || \"$line\" == [[:space:]]*#* ]] && continue";
                loop_content = loop_content "\n    DIRNAME=$(echo \"$line\" | awk \x27{print $2}\x27 | sed -E \"s/\\\\.tar\\\\.[a-z0-9.]+$//\")";
                loop_content = loop_content "\n    PKGNAME=$(echo \"$DIRNAME\" | sed -E \"s/[-_][0-9].*//\")";
                loop_content = loop_content "\n    PKGVER=$(echo \"$DIRNAME\" | sed \"s/^${PKGNAME}-//; s/^${PKGNAME}_//; s/[[:space:]]//g\")";
                loop_content = loop_content "\n    if [ -n \"${METAPACKAGE_TARGET}\" ]; then";
                loop_content = loop_content "\n        if [ \"$PKGNAME\" != \"${METAPACKAGE_TARGET}\" ] && [ \"$DIRNAME\" != \"${METAPACKAGE_TARGET}\" ]; then continue; fi";
                loop_content = loop_content "\n    elif [ -n \"${PACKAGE}\" ] && [ \"${PACKAGE}\" != \"frameworks6\" ] && [ \"${PACKAGE}\" != \"plasma-all\" ] && [ \"${PACKAGE}\" != \"xorg-lib\" ]; then";
                loop_content = loop_content "\n        if [ \"$PKGNAME\" != \"${PACKAGE}\" ] && [ \"$DIRNAME\" != \"${PACKAGE}\" ]; then continue; fi\n    fi";
                loop_content = loop_content "\n    echo \"[KDE-LOOP] Building component: $PKGNAME\"";
                loop_content = loop_content "\n    TARBALL=$(echo \"$line\" | awk \x27{print $2}\x27)";
                loop_content = loop_content "\n    if [ ! -f \"/sources/archives/${TARBALL}\" ] && { [ -z \"${METAPACKAGE_TARGET}\" ] && [ \"${PACKAGE}\" != \"frameworks6\" ] && [ \"${PACKAGE}\" != \"plasma-all\" ] && [ \"${PACKAGE}\" != \"xorg-lib\" ] || [ -n \"${METAPACKAGE_TARGET}\" ]; }; then continue; fi";
                loop_content = loop_content "\n    if [ -f \"/sources/archives/${DIRNAME}.installed\" ] && [ \"$FORCE\" != \"true\" ]; then continue; fi";
                loop_content = loop_content "\n    touch /tmp/build_start_${PKGNAME}";
                next;
            }
            /mkdir build/ { if (in_loop) { loop_content = loop_content "\n    if [ \"$name\" = \"kdeplasma-addons\" ]; then\n        sed -i \"/find_package(Corrosion/d\" CMakeLists.txt\n        sed -i \"/add_subdirectory(kdeds)/d\" CMakeLists.txt\n    fi\n    rm -rf build\n    " $0; next } }
            /-D CMAKE_INSTALL_PREFIX=/ { if (in_loop && !($0 ~ /CMAKE_INSTALL_LIBDIR/)) { sub(/-D CMAKE_INSTALL_PREFIX=/, "-D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_INSTALL_PREFIX=", $0) } }
            /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ { if (in_loop) { loop_content = loop_content "\n    " $0; next } }
            /make.*install|ninja.*install|pip3.*install/ {
                if (in_loop && !($0 ~ /book-packages/)) {
                    loop_content = loop_content "\n    DDIR=\"/tmp/destdir_${PKGNAME}\"\n    rm -rf \"$DDIR\" && mkdir -p \"$DDIR\"";
                    cmd = $0; gsub(/ *([|][|]|&&|;|[[:space:]]\}).*$/, "", cmd);
                    if ($0 ~ /make.*install/) loop_content = loop_content "\n    " cmd " DESTDIR=\"$DDIR\" || true";
                    else if ($0 ~ /ninja.*install/) loop_content = loop_content "\n    DESTDIR=\"$DDIR\" " cmd " || true";
                    else if ($0 ~ /pip3.*install/) {
                        sub(/--root=[^ ]+ /, "", cmd);
                        loop_content = loop_content "\n    " cmd " --root=\"$DDIR\" --ignore-installed --no-deps || true";
                    }
                    loop_content = loop_content "\n    sudo rm -f \"/tmp/pkg_${PKGNAME}\"";
                    loop_content = loop_content "\n    if [ -d \"$DDIR\" ] && [ \"$(ls -A \"$DDIR\" 2>/dev/null)\" ]; then\n        find \"$DDIR\" -mindepth 1 -printf \"/%P\\n\" | sudo tee -a \"/tmp/pkg_${PKGNAME}\" > /dev/null\n    fi";
                    real_cmd = $0; if (real_cmd ~ /pip3.*install/ && real_cmd !~ /ignore-installed/) sub(/pip3[[:space:]]+install/, "pip3 install --ignore-installed --no-deps", real_cmd);
                    loop_content = loop_content "\n    " real_cmd;
                    loop_content = loop_content "\n    find /usr /bin /sbin /lib /lib64 /etc /opt -xdev -newer /tmp/build_start/${PKGNAME} 2>/dev/null | sudo tee -a \"/tmp/pkg_${PKGNAME}\" > /dev/null";
                    loop_content = loop_content "\n    (echo \"${PKGVER}\"; cat \"/tmp/pkg_${PKGNAME}\" 2>/dev/null | grep -v -E \"^[0-9]+(\\.[0-9]+)+$|^[[:space:]]*$\" | sort -u) | sudo tee \"/var/lib/book-packages/${PKGNAME}\" > /dev/null";
                    loop_content = loop_content "\n    sudo chmod 755 \"/var/lib/book-packages/${PKGNAME}\"\n    as_root rm -rf \"$DDIR\"\n    touch \"/sources/archives/${DIRNAME}.installed\"";
                    next;
                }
            }
            /^[[:space:]]*do_install[[:space:]]*$/ {
                if (in_loop) {
                    loop_content = loop_content "\n    sudo rm -f \"/tmp/pkg_${PKGNAME}\"";
                    loop_content = loop_content "\n    if do_install; then";
                    loop_content = loop_content "\n        find /usr /bin /sbin /lib /lib64 /etc /opt -xdev -newer \"/tmp/build_start/${PKGNAME}\" 2>/dev/null | sudo tee -a \"/tmp/pkg_${PKGNAME}\" > /dev/null";
                    loop_content = loop_content "\n        (echo \"${PKGVER}\"; cat \"/tmp/pkg_${PKGNAME}\" 2>/dev/null | grep -v -E \"^[0-9]+(\\.[0-9]+)+$|^[[:space:]]*$\" | sort -u) | sudo tee \"/var/lib/book-packages/${PKGNAME}\" > /dev/null";
                    loop_content = loop_content "\n        touch \"/sources/archives/${DIRNAME}.installed\"";
                    loop_content = loop_content "\n    else\n        exit 1\n    fi";
                    next;
                }
            }
            {
                if (in_as_root) {
                    as_root_content = as_root_content "\n" $0;
                    if (/export -f as_root/) in_as_root = 0;
                } else if (in_loop) {
                    if ($0 ~ /^[[:space:]]*(grep|cat|tail|ls)[[:space:]].*\.log/) { loop_content = loop_content "\n    " $0 " 2>/dev/null || true"; next; }
                    if ($0 ~ /(make[[:space:]].*(check|test|tests|jstest|jit-test|all-headless)|ninja[[:space:]]+(test|check)|spawn.*make|<expect>|tester|su.*tester|(^|[[:space:]])testdir([[:space:]]|$)|test_summary|cd[[:space:]]+t$|tests\/run\.sh)/) { next; }
                    if ($0 ~ /done[[:space:]]+<.*\.md5/) { 
                        md5_file = $0; sub(/^[[:space:]]*done[[:space:]]+<[[:space:]]*/, "", md5_file);
                        sub(/done < /, "done < /sources/archives/", $0); 
                        if (md5_file ~ /plasma/) {
                            loop_content = "    if [ ! -f /sources/archives/" md5_file " ]; then as_root wget -qO /sources/archives/" md5_file " https://download.kde.org/stable/plasma/" ver "/" md5_file " || true; fi\n" loop_content;
                        } else if (md5_file ~ /frameworks/) {
                            loop_content = "    if [ ! -f /sources/archives/" md5_file " ]; then as_root wget -qO /sources/archives/" md5_file " https://download.kde.org/stable/frameworks/" mm "/" md5_file " || true; fi\n" loop_content;
                        }
                        loop_content = loop_content "\n    " $0; 
                        in_loop = 0; next; 
                    }
                    loop_content = loop_content "\n    " (in_root_block ? "as_root " : "") $0;
                } else if (in_md5) {
                    other_cmds = other_cmds "\n" $0;
                    if (/^EOF$/) in_md5 = 0;
                } else {
                    if ($0 ~ /^[[:space:]]*(grep|cat|tail|ls)[[:space:]].*\.log/) { other_cmds = other_cmds "\n" $0 " 2>/dev/null || true"; }
                    else { other_cmds = other_cmds "\n" $0; }
                }
            }
            END {
                if (in_root_block && !in_loop) { other_cmds = other_cmds "\nROOTEOF\n" }
                sub(/^\n/, "", other_cmds);
                tmpfile = "/tmp/kde_build_script_" pkg ".sh";
                print "#!/bin/bash\nset -e\nPACKAGE=\"" pkg "\"\nFORCE=\"" force "\"\ncd /sources/archives\nas_root() {\n  if [ ${EUID:-$(id -u)} = 0 ]; then \"$@\"; elif command -v sudo >/dev/null 2>&1; then sudo \"$@\"; else su -c \"$*\"; fi\n}\nexport -f as_root\n" > tmpfile;
                print other_cmds > tmpfile;
                print loop_content > tmpfile;
                if (in_loop) print "done" > tmpfile;
                close(tmpfile);
                print "# KDE frameworks build script generated in /tmp/kde_build_script_" pkg ".sh";
            }
        ')
        # Now that the file is generated, we have it ready in /tmp/kde_build_script_${PACKAGE}.sh

    fi

log "Starting remote build for $PACKAGE..."

# Generate the Privilege-Separated build script locally
# For KDE frameworks mode, use the pre-generated script from the awk block (bypasses
# _gen_build_script so we avoid nested-heredoc breakage from the build loop)
if [[ ("$FRAMEWORKS_MODE" == "true" || "$PLASMA_MODE" == "true") ]] && [[ -f "/tmp/kde_build_script_${PACKAGE}.sh" ]]; then
    # Apply version substitution (6.23 -> 6.26 etc) now that UPSTREAM_FULL is known
    if [[ -n "$UPSTREAM_FULL" && -n "$LFS_VERSION" ]]; then
        LFS_VERSION="$LFS_VERSION" UPSTREAM_FULL="$UPSTREAM_FULL" LFS_MM="$LFS_MM" UPSTREAM_MM="$UPSTREAM_MM" \
        perl -i -pe 's/\Q$ENV{LFS_VERSION}\E(\.[0-9]+)?/$ENV{UPSTREAM_FULL}/g; s/\Q$ENV{LFS_MM}\E\.[0-9]+/$ENV{UPSTREAM_FULL}/g; s/\Q$ENV{LFS_MM}\E/$ENV{UPSTREAM_MM}/g' \
            "/tmp/kde_build_script_${PACKAGE}.sh"
    fi
    # Prepend SETUP_COMMANDS (KF6/Qt6 env vars) so the build loop has the right env
    BUILD_SCRIPT_LOCAL=$(printf '#!/bin/bash\nset -e\n%s\n' "$SETUP_COMMANDS"; cat "/tmp/kde_build_script_${PACKAGE}.sh")
    rm -f "/tmp/kde_build_script_${PACKAGE}.sh"
else
    BUILD_SCRIPT_LOCAL=$(_gen_build_script "$GEN_DIRNAME" "$NORMAL_USER" "$SETUP_COMMANDS" "$LFS_VERSION")
fi

# Generate the Privilege-Separated build script locally by appending to the file directly for maximum robustness
RS_FILE="/tmp/remote_script_${PACKAGE}.sh"
rm -f "$RS_FILE"
{
  # 1. Inject static variables from host safely
  printf 'PACKAGE="%s"\n' "$PACKAGE"
  printf 'MAIN_FILENAME="%s"\n' "$MAIN_FILENAME"
  printf 'DIRNAME="%s"\n' "$DIRNAME"
  printf 'GEN_DIRNAME="%s"\n' "$GEN_DIRNAME"
  printf 'NORMAL_USER="%s"\n' "$NORMAL_USER"
  printf 'FRAMEWORKS_MODE="%s"\n' "$FRAMEWORKS_MODE"
  printf 'PLASMA_MODE="%s"\n' "$PLASMA_MODE"
  printf 'XORG_MULTI_MODE="%s"\n' "$XORG_MULTI_MODE"
  printf 'RM_LIBS="%s"\n' "$RM_LIBS"
  printf 'YES="%s"\n' "$YES"
  printf 'METAPACKAGE_TARGET="%s"\n' "$METAPACKAGE_TARGET"
  
  # Inject version information for inventory recording
  RECORDED_VERSION="$LFS_VERSION"
  if [[ "$UPSTREAM" == "true" ]]; then
      if [[ -n "$UPSTREAM_FULL" ]]; then RECORDED_VERSION="$UPSTREAM_FULL";
      elif [[ -n "$UPSTREAM_VERSION" ]]; then RECORDED_VERSION="$UPSTREAM_VERSION"; fi
  fi
  printf 'VERSION_TO_RECORD="%s"\n' "$RECORDED_VERSION"

  # Inject BS_B64 from a temporary file to avoid shell argument limits
  printf '%s' "$BUILD_SCRIPT_LOCAL" | base64 -w 0 > /tmp/bs_b64.txt
  printf 'BS_B64=\x22'
  cat /tmp/bs_b64.txt
  printf '\x22\n'
  rm -f /tmp/bs_b64.txt

  # 2. Inject arrays safely using declare -p
  declare -p DOWNLOAD_URLS ALL_FILENAMES

  # 3. Append the main logic using a quoted heredoc
  cat <<'REMOTE_EOF'
# Helper to run commands as root inside the remote script
as_root() {
  if [ ${EUID:-$(id -u)} = 0 ]; then
    "$@"
  else
    local cmd="$*"
    if [[ "$cmd" == *">"* ]] || [[ "$cmd" == *"<<"* ]] || [[ "$cmd" == *"|"* ]]; then
      if command -v sudo >/dev/null 2>&1; then
        sudo bash -c "$cmd"
      else
        su -c "$cmd"
      fi
    else
      if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
      else
        su -c "$cmd"
      fi
    fi
  fi
}
export -f as_root

REMOTE_EOF
  cat <<'REMOTE_EOF'
export PACKAGE VERSION_TO_RECORD MAIN_FILENAME DIRNAME GEN_DIRNAME NORMAL_USER FRAMEWORKS_MODE PLASMA_MODE XORG_MULTI_MODE RM_LIBS YES METAPACKAGE_TARGET

(
  flock -x 200 || { echo "Another build is in progress. Waiting for lock..."; flock -x 200; }
set -e

# Cleanup trap: always remove timestamp/state files on exit.
# On failure, also clear the inventory so the commit guard reliably detects the broken build.
_lfs_build_trap() {
    local exit_code=$?
    rm -f "/tmp/build_start_timestamp_${PACKAGE}" \
          "/tmp/build_state_before_${PACKAGE}" \
          "/tmp/build_state_after_${PACKAGE}"
    if [ $exit_code -ne 0 ]; then
        # Wipe the inventory file and write the error log so the commit guard reliably detects the broken build
        # but also preserves exactly what failed for the user.
        if [[ "$FRAMEWORKS_MODE" == "false" && "$PLASMA_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
            sudo bash -c "echo 'BUILD_FAILED' > '/var/lib/book-packages/${PACKAGE}' 2>/dev/null" || true
            if [ -f "/tmp/build_log_${PACKAGE}.txt" ]; then
                sudo bash -c "echo '--- ERROR LOG (Last 30 lines) ---' >> '/var/lib/book-packages/${PACKAGE}'" || true
                sudo tail -n 30 "/tmp/build_log_${PACKAGE}.txt" | sudo tee -a "/var/lib/book-packages/${PACKAGE}" >/dev/null || true
            fi
        fi
    fi
    exit $exit_code
}
trap '_lfs_build_trap' EXIT

# Record start time for file tracking
touch "/tmp/build_start_timestamp_${PACKAGE}"

mkdir -p /sources/archives
cd /sources/archives

# 1. Download all files
for url in "${DOWNLOAD_URLS[@]}"; do
    fname=$(basename "$url")
    if [[ "$fname" == *".patch"* ]]; then
        # Resilient download for patches
        if [ ! -s "$fname" ]; then 
            rm -f "$fname"
            echo "Downloading $fname..."
            wget -T 30 -t 3 "$url" || echo "[WARNING] Failed to download $fname"
        fi
    else
        if [ ! -s "$fname" ]; then
            rm -f "$fname"
            echo "Downloading $fname..."
            # Try primary URL first
            if ! wget -T 30 -t 3 "$url"; then
                echo "[WARNING] Failed to download $url"
                # If it's the main archive, try fallback extensions
                if [[ "$url" == "$MAIN_DOWNLOAD_URL" ]]; then
                    echo "Main archive download failed. Attempting fallbacks..."
                    base_url_no_ext=$(echo "$url" | sed -E 's/\.(tar\.(xz|gz|bz2|lz|lzma|zst)|zip|tgz|tbz2)$//')
                    success=false
                    for ext in .tar.xz .tar.gz .tar.bz2 .tar.lz .zip; do
                        alt_url="${base_url_no_ext}${ext}"
                        [[ "$alt_url" == "$url" ]] && continue
                        
                        echo "Trying fallback extension: $alt_url"
                        if wget -T 30 -t 2 "$alt_url"; then
                            MAIN_FILENAME=$(basename "$alt_url")
                            ALL_FILENAMES+=("$MAIN_FILENAME")
                            echo "Successfully downloaded fallback: $MAIN_FILENAME"
                            success=true
                            break
                        fi
                    done
                    
                    # Second Fallback: Strip redundant .0 from point-zero releases (x.y.0 -> x.y)
                    if [ "$success" = "false" ] && [[ "$base_url_no_ext" == *".0" ]]; then
                        alt_ver_base=$(echo "$base_url_no_ext" | sed 's/\.0$//')
                        echo "Attempting version fallback (stripping .0): $alt_ver_base"
                        for ext in .tar.xz .tar.gz .tar.bz2 .tar.lz .zip; do
                            alt_url="${alt_ver_base}${ext}"
                            echo "Trying: $alt_url"
                            if wget -T 30 -t 2 "$alt_url"; then
                                MAIN_FILENAME=$(basename "$alt_url")
                                ALL_FILENAMES+=("$MAIN_FILENAME")
                                echo "Successfully downloaded version fallback: $MAIN_FILENAME"
                                success=true
                                break
                            fi
                        done
                    fi
                    
                    if [ "$success" = "false" ]; then
                        echo "[ERROR] Could not download primary archive or any common fallbacks."
                        exit 1
                    fi
                else
                    # Not the main archive, but still a failure
                     echo "[ERROR] Failed to download required file: $url"
                     exit 1
                fi
            fi
        fi
    fi
done

chown -R "${NORMAL_USER}" /sources/archives
chmod -R a+rX /sources/archives

# 2. Cleanup old versions of the main package
echo "Cleaning up old versions..."
PKG_PREFIX=$(echo "$MAIN_FILENAME" | sed 's/[-_]\?[0-9].*//')
PKG_NAME_PREFIX=$(echo "$PACKAGE" | sed 's/[0-9]*$//')
if [ -n "$PKG_PREFIX" ] || [ -n "$PKG_NAME_PREFIX" ]; then
    for f in *; do
        [ -e "$f" ] || continue
        # Skip files we just downloaded
        skip=false
        for df in "${ALL_FILENAMES[@]}"; do [[ "$f" == "$df" ]] && skip=true && break; done
        [[ "$skip" == "true" ]] && continue
        
        # Match archive prefix or package name prefix
        if ([[ -n "$PKG_PREFIX" ]] && [[ "$f" =~ ^$PKG_PREFIX[-_]?[0-9] ]]) || \
           ([[ -n "$PKG_NAME_PREFIX" ]] && [[ "$f" =~ ^$PKG_NAME_PREFIX[-_]?[0-9] ]]); then
            echo "Removing old version: $f"
            rm -rf "$f"
        fi
    done
fi

# 3. Clean up /sources/ symlinks from previous runs
find /sources -maxdepth 1 -type l -delete

# 4. Symlink all downloaded files to /sources/ for easy access (except the main one if extracted)
for f in "${ALL_FILENAMES[@]}"; do
    [ "$f" == "$MAIN_FILENAME" ] && continue
    ln -sf "/sources/archives/$f" "/sources/$f"
    chown -h "${NORMAL_USER}" "/sources/$f"
done

# 5. Extract main archive
if [ "$FRAMEWORKS_MODE" == "true" ] || [ "$XORG_MULTI_MODE" == "true" ]; then
    mkdir -p "/sources/$DIRNAME"
    cd "/sources/$DIRNAME"
else
    echo "Extracting $MAIN_FILENAME..."
    # Always extract to root DIRNAME, but build in GEN_DIRNAME (set to DIRNAME/llvm for monorepo)
    if [[ -n "$DIRNAME" ]] && [[ "$DIRNAME" != "." ]] && [[ "$DIRNAME" != "/" ]] && [[ "$DIRNAME" != "archives" ]]; then
        # Extreme safety: ensure we are not deleting /sources itself or its internal archives
        TARGET_DIR="/sources/$DIRNAME"
        RESOLVED_TARGET=$(realpath -m "$TARGET_DIR")
        if [[ "$RESOLVED_TARGET" != "/sources" ]] && [[ "$RESOLVED_TARGET" != "/sources/" ]] && [[ "$RESOLVED_TARGET" != "/sources/archives"* ]]; then
            rm -rf "$TARGET_DIR"
            mkdir -p "$TARGET_DIR"
            # Try to strip components if it is a standard archive with a root folder
            # If tar succeeds but extracts nothing (silent failure on flat archives), fallback
            if echo $MAIN_FILENAME | grep -E "tar|tgz" &> /dev/null; then
                echo "Using tar with strip-components"
                tar -xf "$MAIN_FILENAME" -C "$TARGET_DIR" --strip-components=1 2>/dev/null || true
            elif echo $MAIN_FILENAME | grep "zip" &> /dev/null; then
                unzip "$MAIN_FILENAME" -d "$TARGET_DIR" 2>/dev/null || true
            fi
            if [ ! "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
                # Fallback for flat archives (like tzdata)
                if echo $MAIN_FILENAME | grep -E "tar|tgz" &> /dev/null; then
                    echo "Using tar"
                    tar -xf "$MAIN_FILENAME" -C "$TARGET_DIR" 2>/dev/null || true
                elif echo $MAIN_FILENAME | grep "zip" &> /dev/null; then
                    unzip "$MAIN_FILENAME" -d "$TARGET_DIR" 2>/dev/null || true
                fi
            fi
            # Flatten archives that extract into a single nested subfolder (common when archives have a leading ./ prefix)
            # Skip this for NSS/NSPR as their build system and book commands expect the nested directory
            if [[ $(ls -A "$TARGET_DIR" | wc -l) -eq 1 ]] && [[ -d "$TARGET_DIR/$(ls -A "$TARGET_DIR")" ]] && [[ "$PACKAGE" != "nss" ]] && [[ "$PACKAGE" != "nspr" ]] && [[ "${PACKAGE,,}" != "lmdb" ]]; then
                SUBDIR=$(ls -A "$TARGET_DIR")
                echo "Detected nested directory '$SUBDIR' after extraction. Moving contents up."
                mv "$TARGET_DIR/$SUBDIR"/{.[!.]*,*} "$TARGET_DIR/" 2>/dev/null || true
                rmdir "$TARGET_DIR/$SUBDIR"
            fi
            # Ensure recursive ownership immediately after extraction
            chown -R "${NORMAL_USER}" "$TARGET_DIR"
            
            # Package-specific source fixes after extraction
            if [[ "${PACKAGE,,}" == "libportal" ]] && [[ -f "$TARGET_DIR/libportal/meson.build" ]]; then
                echo "Applying libportal-specific Meson fix for Qt6 dependency..."
                sed -i "s/requires: \[qt6_dep/requires: ['Qt6Core', 'Qt6Gui', 'Qt6Widgets'/" "$TARGET_DIR/libportal/meson.build"
            fi
            if [[ "${PACKAGE,,}" == "ruby" ]] && [[ -f "$TARGET_DIR/ext/openssl/ossl_asn1.c" ]]; then
                echo "Applying Ruby OpenSSL 4.0 compatibility patch via python..."
                python3 -c '
import os
file_path = os.path.join("'"$TARGET_DIR"'", "ext/openssl/ossl_asn1.c")
with open(file_path, "r") as f:
    code = f.read()

# Fix obj_to_asn1bstr body (may already be done by BLFS patch hunk #1)
target1 = """    ASN1_BIT_STRING_set(bstr, (unsigned char *)RSTRING_PTR(obj), RSTRING_LENINT(obj));
    bstr->flags &= ~(ASN1_STRING_FLAG_BITS_LEFT|0x07); /* clear */
    bstr->flags |= ASN1_STRING_FLAG_BITS_LEFT | unused_bits;"""

replacement1 = """    if (!ASN1_BIT_STRING_set1(bstr, (const unsigned char *)RSTRING_PTR(obj), RSTRING_LENINT(obj), (int)unused_bits)) {
        ASN1_BIT_STRING_free(bstr);
        ossl_raise(eASN1Error, "ASN1_BIT_STRING_set1");
    }"""

# Fix decode_bstr body (original uses opaque bstr->length, bstr->flags, bstr->data)
target2 = """    long len;
    VALUE ret;

    p = der;
    if(!(bstr = d2i_ASN1_BIT_STRING(NULL, &p, length)))
        ossl_raise(eASN1Error, NULL);
    len = bstr->length;
    *unused_bits = 0;
    if(bstr->flags & ASN1_STRING_FLAG_BITS_LEFT)
        *unused_bits = bstr->flags & 0x07;
    ret = rb_str_new((const char *)bstr->data, len);"""

replacement2 = """    size_t len = 0;
    int unused = 0;
    VALUE ret;

    p = der;
    if(!(bstr = d2i_ASN1_BIT_STRING(NULL, &p, length)))
        ossl_raise(eASN1Error, NULL);
    if (!ASN1_BIT_STRING_get_length(bstr, &len, &unused)) {
        ASN1_BIT_STRING_free(bstr);
        ossl_raise(eASN1Error, "ASN1_BIT_STRING_get_length");
    }
    *unused_bits = unused;
    ret = rb_str_new((const char *)ASN1_STRING_get0_data((const ASN1_STRING *)bstr), (long)len);"""

if target1 in code:
    code = code.replace(target1, replacement1)
    print("Patched obj_to_asn1bstr body")
else:
    print("obj_to_asn1bstr body: already patched or not found, skipping")

if target2 in code:
    code = code.replace(target2, replacement2)
    print("Patched decode_bstr body")
else:
    print("decode_bstr body: already patched or not found, skipping")

# Always fix decode_bstr signature: long *unused_bits -> int *unused_bits
# (call site passes &flag which is int*, so signature must match)
sig_old = "decode_bstr(unsigned char* der, long length, long *unused_bits)"
sig_new = "decode_bstr(unsigned char* der, long length, int *unused_bits)"
if sig_old in code:
    code = code.replace(sig_old, sig_new)
    print("Fixed decode_bstr signature: long* -> int*")
else:
    print("decode_bstr signature: already int* or not found")

with open(file_path, "w") as f:
    f.write(code)
print("Done writing ossl_asn1.c")
'
            fi
        else
            echo "[ERROR] Unsafe DIRNAME detected: $DIRNAME. Aborting extraction to prevent data loss."
            exit 1
        fi
    else
        echo "[ERROR] Invalid or empty DIRNAME: '$DIRNAME'. Aborting extraction."
        exit 1
    fi
    cd "/sources/$GEN_DIRNAME"
fi

echo "Marking build start time..."
touch /tmp/build_start_timestamp_${PACKAGE}

# Record initial file state to handle clock drift/skew during build
if [[ "$FRAMEWORKS_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
    SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt /boot"
    EXISTING_DIRS=""
    for d in $SEARCH_DIRS; do [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"; done
    find $EXISTING_DIRS -xdev -printf "%p %T@\n" 2>/dev/null | LC_ALL=C sort > /tmp/build_state_before_${PACKAGE}
fi

# Initialize inventory file with version before build starts to prevent overwriting DESTDIR captures
# Skip this for meta-packages, as their subpackages track their own versions internally
if [[ "$FRAMEWORKS_MODE" == "false" && "$PLASMA_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
    sudo mkdir -p /var/lib/book-packages
    echo "${VERSION_TO_RECORD}" | sudo tee "/var/lib/book-packages/${PACKAGE}" > /dev/null
    sudo chmod 755 "/var/lib/book-packages/${PACKAGE}"
fi

echo "Running build commands (user blocks as ${NORMAL_USER}, root blocks as root)..."
# The build script is injected via an environment variable on the guest
# to avoid quoting issues with base64 embedding inside the remote script.
if [ -n "$BS_B64" ]; then
    echo "$BS_B64" | base64 -d > /tmp/build-cmds-${PACKAGE}.sh
    if [[ "${PACKAGE,,}" == "ruby" ]]; then
        sed -i 's/bundle update rake/bundle update rake || true/g' /tmp/build-cmds-${PACKAGE}.sh
    fi
    chmod +x /tmp/build-cmds-${PACKAGE}.sh
    set +e
    bash /tmp/build-cmds-${PACKAGE}.sh 2>&1 | tee "/tmp/build_log_${PACKAGE}.txt"
    build_exit_code=${PIPESTATUS[0]}
    set -e
    if [ $build_exit_code -ne 0 ]; then
        exit $build_exit_code
    fi
else
     echo "[ERROR] BUILD_SCRIPT content (BS_B64) not found on guest."
     echo "$COMMANDS" > /tmp/cmds_final.out
fi

if [[ "$FRAMEWORKS_MODE" == "false" && "$PLASMA_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
    # Save file list to /var/lib/book-packages/
    sudo mkdir -p /var/lib/book-packages
    # Append version if not already there (though we initialized it above, safety first)
    if ! grep -q "^${VERSION_TO_RECORD}$" "/var/lib/book-packages/${PACKAGE}" 2>/dev/null; then
        echo "${VERSION_TO_RECORD}" | sudo tee -a "/var/lib/book-packages/${PACKAGE}" > /dev/null
    fi
    SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt /boot"
    EXISTING_DIRS=""
    for d in $SEARCH_DIRS; do [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"; done
    
    # 1. Capture via timestamp (susceptible to clock drift/skew on long builds like Linux kernel)
    find $EXISTING_DIRS -xdev -newer /tmp/build_start_timestamp_${PACKAGE} 2>/dev/null | sudo tee -a "/var/lib/book-packages/${PACKAGE}" > /dev/null
    
    # 2. Capture via robust before-and-after diffing (immune to clock skew/drift)
    if [ -f "/tmp/build_state_before_${PACKAGE}" ]; then
        echo "Calculating installed files using state diff (before/after)..."
        find $EXISTING_DIRS -xdev -printf "%p %T@\n" 2>/dev/null | LC_ALL=C sort > /tmp/build_state_after_${PACKAGE}
        LC_ALL=C comm -13 "/tmp/build_state_before_${PACKAGE}" "/tmp/build_state_after_${PACKAGE}" | cut -d' ' -f1 | sudo tee -a "/var/lib/book-packages/${PACKAGE}" > /dev/null
    fi

    # 3. For cmake-built packages, also read the cmake install manifest (immune to timestamp issues)
    # cmake writes cmake_install_manifest.txt listing every file it installed
    if [ -d "/sources/${GEN_DIRNAME}" ]; then
        find "/sources/${GEN_DIRNAME}" -maxdepth 3 -name 'cmake_install_manifest.txt' 2>/dev/null | while read mf; do
            grep '^/' "$mf" 2>/dev/null | while read installed_file; do
                [ -e "$installed_file" ] && echo "$installed_file"
            done
        done | sudo tee -a "/var/lib/book-packages/${PACKAGE}" > /dev/null
    fi
    
    # Enrich inventory with archive manifest to catch files that weren't updated (up-to-date)
    # Search in common archive locations for maximum robustness
    archive_path=""
    if [ -f "$MAIN_FILENAME" ]; then
        archive_path="$MAIN_FILENAME"
    elif [ -f "/sources/archives/$MAIN_FILENAME" ]; then
        archive_path="/sources/archives/$MAIN_FILENAME"
    elif [ -f "/sources/$MAIN_FILENAME" ]; then
        archive_path="/sources/$MAIN_FILENAME"
    fi
    if [ -n "$archive_path" ]; then
        echo "Enriching inventory from archive manifest ($archive_path) for $PACKAGE..."
        enrich_tmp="/tmp/enrich_${PACKAGE}"
        rm -f "$enrich_tmp"
        tar -tf "$archive_path" | sed 's|^[^/]*||; s|^/||' | while read f; do
            [ -z "$f" ] && continue
            # Common prefixes in BLFS
            for pref in /usr / /opt /etc; do
                target="${pref}${f}"
                if [ -e "$target" ] && [ ! -d "$target" ]; then
                    echo "$target" >> "$enrich_tmp"
                    break
                fi
            done
        done
        [ -f "$enrich_tmp" ] && { sudo bash -c "cat '$enrich_tmp' >> '/var/lib/book-packages/${PACKAGE}'"; rm -f "$enrich_tmp"; }
    fi
    # Deduplicate but preserve version on line 1
    sudo bash -c "head -n 1 '/var/lib/book-packages/${PACKAGE}' > '/tmp/pkg_${PACKAGE}'; tail -n +2 '/var/lib/book-packages/${PACKAGE}' | sort -u >> '/tmp/pkg_${PACKAGE}'; mv '/tmp/pkg_${PACKAGE}' '/var/lib/book-packages/${PACKAGE}'"
    sudo chmod 755 "/var/lib/book-packages/${PACKAGE}"
    echo "Recorded installed files for $PACKAGE in /var/lib/book-packages/$PACKAGE"
fi

if [[ "$RM_LIBS" == "true" ]]; then
    # Find files installed by this build (newer than timestamp)
    SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt /boot"
    for d in $SEARCH_DIRS; do [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"; done
    NEW_FILES_LIST=$(mktemp)
    find $EXISTING_DIRS -xdev -newer /tmp/build_start_timestamp_${PACKAGE} ! -name "$(basename "$NEW_FILES_LIST")" > "$NEW_FILES_LIST" 2>/dev/null || true

    while read -r line; do
        [ -e "$line" ] || continue
        dirname=$(dirname "$line")
        basename=$(basename "$line")

        if [[ "$basename" =~ \.so\.[0-9]+ || "$basename" =~ -[0-9].*\.so$ ]]; then
            major_prefix=$(echo "$basename" | grep -oE '^.*\.so\.[0-9]+|^[a-zA-Z0-9_]+-')
            if [ -n "$major_prefix" ]; then
                for candidate in "$dirname"/"$major_prefix"*; do
                    [ -f "$candidate" ] && [ "$candidate" != "$line" ] || continue
                    if ! [[ "$candidate" -nt /tmp/build_start_timestamp_${PACKAGE} ]]; then
                        echo "Removing old library version: $candidate"
                        #rm -f "$candidate"
                    fi
                done
            fi

            # Track preserved libraries with different major versions
            lib_base=$(echo "$basename" | sed 's/\.so\.[0-9].*//')
            if [ -n "$lib_base" ]; then
                for candidate in "$dirname"/"$lib_base".so.*; do
                    [ -f "$candidate" ] || continue
                    if ! [[ "$candidate" -nt /tmp/build_start_timestamp_${PACKAGE} ]] && \
                       [[ "$candidate" != "$dirname/$major_prefix"* ]]; then
                        echo "Found preserved library: $candidate"
                        echo "$candidate" | sudo tee -a "/tmp/preserved_libs_${PACKAGE}.txt" > /dev/null
                    fi
                done
            fi
        fi

        if [ -d "$line" ]; then
            if [[ "$basename" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                for candidate in "$dirname"/*; do
                    [ -d "$candidate" ] && [ "$candidate" != "$line" ] || continue
                    cbase=$(basename "$candidate")
                    if [[ "$cbase" =~ ^[0-9]+(\.[0-9]+)*$ ]] && ! [[ "$candidate" -nt /tmp/build_start_timestamp_${PACKAGE} ]]; then
                         echo "Removing old version directory: $candidate"
                         rm -rf "$candidate"
                    fi
                done
            elif [[ "$basename" =~ ^[a-zA-Z]+[0-9]+(\.[0-9]+)*$ ]]; then
                 prefix=$(echo "$basename" | sed -E 's/([a-zA-Z]+).*/\1/')
                 for candidate in "$dirname"/"$prefix"*; do
                    [ -d "$candidate" ] && [ "$candidate" != "$line" ] || continue
                    cbase=$(basename "$candidate")
                    if [[ "$cbase" =~ ^$prefix[0-9]+(\.[0-9]+)*$ ]] && ! [[ "$candidate" -nt /tmp/build_start_timestamp_${PACKAGE} ]]; then
                         echo "Removing old version directory: $candidate"
                         rm -rf "$candidate"
                    fi
                 done
            fi
        fi

        if [[ "$dirname" == "/boot" ]]; then
            boot_prefix=$(echo "$basename" | grep -oE '^(vmlinuz|System\.map|config|initramfs|initrd\.img)')
            if [ -n "$boot_prefix" ]; then
                for candidate in "$dirname"/"$boot_prefix"*; do
                    [ -f "$candidate" ] && [ "$candidate" != "$line" ] && ! [ -L "$candidate" ] || continue
                    if ! [[ "$candidate" -nt /tmp/build_start_timestamp_${PACKAGE} ]]; then
                        echo "Removing old kernel file: $candidate"
                        rm -f "$candidate"
                    fi
                done
            fi
        fi
    done < "$NEW_FILES_LIST"
    rm -f "$NEW_FILES_LIST" /tmp/build_start_timestamp_${PACKAGE} /tmp/build_state_before_${PACKAGE} /tmp/build_state_after_${PACKAGE}

    for doc_dir in /usr/share/doc/linux-*; do
        [ -d "$doc_dir" ] || continue
        if ! [[ "$doc_dir" -nt /tmp/build_start_timestamp_${PACKAGE} ]]; then
            echo "Removing old kernel doc directory: $doc_dir"
            rm -rf "$doc_dir"
        fi
    done
else
    echo "Skipping library cleanup (use --rm-libs flag to remove old library versions)"
    rm -f /tmp/build_start_timestamp_${PACKAGE} /tmp/build_state_before_${PACKAGE} /tmp/build_state_after_${PACKAGE}
fi

echo "Build and installation complete for $PACKAGE"
cd /sources
# Remove extracted source tree
rm -rf "$GEN_DIRNAME"

# Only remove downloaded archives if the build succeeded AND inventory has actual file entries.
# Guards:
#   1. Line 1 must NOT be BUILD_FAILED (error log entries make wc -l > 1 even on failure)
#   2. Inventory must have more than 1 line (i.e. actual installed files, not just the version)
_inv_line1=""
_inv_lines=0
if [ -f "/var/lib/book-packages/${PACKAGE}" ]; then
    _inv_line1=$(head -n 1 "/var/lib/book-packages/${PACKAGE}")
    _inv_lines=$(wc -l < "/var/lib/book-packages/${PACKAGE}")
fi
if [ "$_inv_line1" != "BUILD_FAILED" ] && [ "$_inv_lines" -gt 1 ]; then
    echo "Cleaning up archives for $PACKAGE..."
    for f in "${ALL_FILENAMES[@]}"; do
        rm -f "/sources/archives/$f"
        rm -f "/sources/$f"
    done
else
    echo "Skipping archive cleanup for $PACKAGE (build failed or inventory empty — archives preserved for retry)."
fi
# Remove generated helper scripts
# rm -f "/sources/archives/build-xorg.sh" "/sources/archives/build-frameworks.sh"
rm -f "/tmp/build-cmds-${PACKAGE}.sh"
) 200>/tmp/lfs_autobuild.lock
REMOTE_EOF
} > "$RS_FILE"

# (REMOTE SCRIPT is already generated at /tmp/remote_script_${PACKAGE}.sh)

# If running on host (identified by HOST_MODE), transfer and run on guest
if [[ "$HOST_MODE" == "true" ]]; then
    log "Transferring build script to remote VM..."
    if ! cp_to_vm "Linux From Scratch" /tmp/remote_script_${PACKAGE}.sh /tmp/remote_script_${PACKAGE}.sh; then
        error "Failed to transfer build script to remote VM."
    fi
    log "Executing remote build script..."
    ssh_lfs "sudo bash /tmp/remote_script_${PACKAGE}.sh"
    CODE=$?
# ssh_lfs "rm -f /tmp/remote_script_${PACKAGE}.sh"
    if [[ $CODE -ne 0 ]]; then
        error "Remote build script failed for $PACKAGE."
    fi
else
    # Running on guest already (piped)
    sudo bash /tmp/remote_script_${PACKAGE}.sh
fi
rm -f /tmp/remote_script_${PACKAGE}.sh

# Optional binary stripping on host after build
if [[ "$STRIP" == "true" ]] && [[ "$HOST_MODE" == "true" ]]; then
    if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
        source "$NIXCFG/shell/user/21-lfs.sh"
        lfs_strip
    fi
fi

done
