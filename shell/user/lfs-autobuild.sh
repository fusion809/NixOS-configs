#!/usr/bin/env bash
# Automate LFS/BLFS package building by scraping official books (Development/SVN)

# Ensure NIXCFG is set
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

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

DRY_RUN=false
STRIP=false
UPSTREAM=false
INCLUDE_CONFIG=false
SEARCH_LFS=true
SEARCH_BLFS=true
PACKAGES=()
XORG_MULTI_MODE=false

usage() {
    echo "Usage: $0 [options] <package-name> [package-name-2...]"
    echo "Options:"
    echo "  --dry-run             Show commands without executing them"
    echo "  --strip               Run stripping commands after build"
    echo "  --upstream            Attempt to find the latest upstream version (linux, vim, firefox, rustc, and llvm)"
    echo "  --include-config      Include configuration commands in the LFS/BLFS book entry"
    echo "  --lfs                 Search only in the LFS book"
    echo "  --blfs                Search only in the BLFS book"
    echo "  --lfs-book <book>     Specify LFS book (e.g., development, systemd, stable, or full URL)"
    echo "  --blfs-book <book>    Specify BLFS book (e.g., systemd, development, stable, or full URL)"
    echo "  -h, --help            Show this help message"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --strip) STRIP=true ;;
        --upstream) UPSTREAM=true ;;
        --include-config) INCLUDE_CONFIG=true ;;
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
        -h|--help) usage ;;
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
fi

log() { echo "[$(date +'%H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# Guard against circular dependencies across recursive invocations
BUILDING_STACK="${BUILDING_STACK:-}"

# Loop over all requested packages
for PACKAGE in "${PACKAGES[@]}"; do
    if [[ ":${BUILDING_STACK}:" == *":${PACKAGE}:"* ]]; then
        log "Skipping '$PACKAGE': already in build stack (circular dependency guard)."
        continue
    fi
    # Use a local stack for this iteration to allow independent subsequent packages
    export BUILDING_STACK="${BUILDING_STACK:+${BUILDING_STACK}:}${PACKAGE}"

    # 0. Check for custom package in ~/lfs_packaging
CUSTOM_BUILD_SH=$(target_run "find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name build.sh 2>/dev/null | xargs grep -l -E \"^[A-Z_]*NAME=['\\\"']?${PACKAGE}['\\\"']?\\$\" 2>/dev/null | head -n 1" 2>/dev/null | grep -vE "^(Warning:|Connection|IP|SSH|grep:)" | tr -d '\r')
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
set -e
cd "$CUSTOM_DIR"
bash build.sh

# Update registry (needs sudo)
sudo mkdir -p /var/lib/lfs-custom-packages
# Try to determine the new version we just installed
new_ver=""
version_line_num=$(grep -nE '^[A-Z_]*VERSION=' build.sh | head -n 1 | cut -d: -f1)
if [ -n "$version_line_num" ]; then
    head -n "$version_line_num" build.sh > /tmp/eval_ver_${TARGET_PKG}.sh
    var_name=$(grep -E '^[A-Z_]*VERSION=' build.sh | head -n 1 | cut -d= -f1)
    echo "echo \$$var_name" >> /tmp/eval_ver_${TARGET_PKG}.sh
    new_ver=$(bash /tmp/eval_ver_${TARGET_PKG}.sh 2>/dev/null | tail -n 1)
    rm -f /tmp/eval_ver_${TARGET_PKG}.sh
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
        new_ver=$(git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}')
    fi
fi

if [ -n "$new_ver" ]; then
    echo "$new_ver" | sudo tee /var/lib/lfs-custom-packages/"$TARGET_PKG" > /dev/null
    echo "Updated registry for $TARGET_PKG to version $new_ver"
else
    echo "Could not determine version for $TARGET_PKG to update registry"
fi
EOF
)
    ssh_lfs "TARGET_PKG=\"$PACKAGE\" CUSTOM_DIR=\"$CUSTOM_DIR\" bash -c '$(echo "$REMOTE_SCRIPT" | sed "s/'/'\\\\''/g")'"


    
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

# 1. Discover package page
find_package_page() {
    local pkg="$1"
    local found=""

    if [[ "$SEARCH_LFS" == "true" ]]; then
        if [[ "$pkg" == "linux" ]]; then
            echo "$LFS_BOOK/chapter10/kernel.html"
            return 0
        fi

        log "Searching for '$pkg' in LFS book..." >&2
        # First try exact match (e.g., /pkg.html)
        local lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*\/$pkg\.html)\"/is) { print \$1; exit }")
        
        # Fallback to loose match but only at boundaries (e.g. openssl vs nss)
        if [[ -z "$lfs_page" ]]; then
            lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*[^a-z]${pkg}\.html|[^\"]*\/$pkg[^a-z0-9][^\"]*\.html)\"/is) { print \$1; exit }")
        fi
        
        if [[ -n "$lfs_page" ]]; then
            echo "$LFS_BOOK/chapter08/$lfs_page"
            return 0
        fi
    fi

    if [[ "$SEARCH_BLFS" == "true" ]]; then
        case "$pkg" in
            xorg-lib|x7lib)       echo "$BLFS_BOOK/x/x7lib.html"; return 0 ;;
            xorg-app|x7app)       echo "$BLFS_BOOK/x/x7app.html"; return 0 ;;
            xorg-font|x7font)     echo "$BLFS_BOOK/x/x7font.html"; return 0 ;;
            xorg-driver|x7driver) echo "$BLFS_BOOK/x/x7driver.html"; return 0 ;;
        esac

        log "Searching for '$pkg' in BLFS index..." >&2

        local search_pkg="$pkg"
        if [[ "$pkg" =~ ^gst-plugins-(base|good|bad|ugly)$ ]]; then
            search_pkg="gst10-plugins-${BASH_REMATCH[1]}"
        elif [[ "$pkg" == "rustc" ]]; then
            search_pkg="rust"
        elif [[ "$pkg" == "pygobject" ]]; then
            search_pkg="pygobject3"
        fi

        # First try match for pkg.html (with optional fragment)
        local blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*\/$search_pkg\.html(?:#[^\"]*)?)\"/is) { print \$1; exit }")
        
        # Second try: match fragment directly (if search_pkg is used as a fragment)
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]+\.html#$search_pkg)\"/is) { print \$1; exit }")
        fi

        # Fallback to match at boundaries
        if [[ -z "$blfs_page" ]]; then
            blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*\/[^a-z0-9]${search_pkg}[^\"]*\.html(?:#[^\"]*)?|[^\"]*\/$search_pkg[^a-z0-9][^\"]*\.html(?:#[^\"]*)?)\"/is) { print \$1; exit }")
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
    JDK_MAJOR=$(curl -s https://jdk.java.net/ | perl -nle 'while (m{href="\./\K[0-9]+}g) { print $& }' | sort -rn | head -n 1)
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
PAGE_URL=$(find_package_page "$PACKAGE")
if [[ -z "$PAGE_URL" ]]; then
    error "Could not find page for package '$PACKAGE'"
fi

log "Found package page: $PAGE_URL"

if [[ "$PACKAGE" =~ ^(xorg|x7)-(lib|app|font|driver)$ ]]; then
    XORG_MULTI_MODE=true
    log "Enabling Xorg multi-package mode."
fi

# 2. Extract Download URL and Build Commands
log "Fetching content from $PAGE_URL..."
HTML_CONTENT=$(curl -s "$PAGE_URL")

if [[ -z "$HTML_CONTENT" ]]; then
    error "Empty content from $PAGE_URL"
fi

# 2.1 Help extraction by slicing HTML if URL has a fragment (e.g. #pygobject3)
FRAG=$(echo "$PAGE_URL" | grep -o "#.*$")
if [[ -n "$FRAG" ]]; then
    FRAG_ID=${FRAG#\#}
    log "Slicing HTML content for fragment: $FRAG_ID"
    # Extract starting from the anchor with the id $FRAG_ID up to the next sect/header
    HTML_CONTENT=$(printf '%s' "$HTML_CONTENT" | perl -0777 -nse '
        if (/(<a\s+(?:id|name)="\Q$id\E"[^>]*>.*?)(?=<div\s+class="sect[12]"|<h[12]|id="(?!\Q$id\E)[^"]+")/is) {
            print $1;
        } elsif (/(<a\s+(?:id|name)="\Q$id\E"[^>]*>.*)/is) {
            print $1;
        }
    ' -- -id="$FRAG_ID")
    if [[ -z "$HTML_CONTENT" ]]; then
         error "Failed to slice HTML for fragment $FRAG_ID in $PAGE_URL"
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

get_commands() {
    local html="$1"
    # Extract blocks and clean them individually, preserving root vs userinput class
    printf '%s' "$html" | awk '
        BEGIN { IGNORECASE=1 }
        /<pre [^>]*class="root"[^>]*>/ { in_block=1; print "___BLOCK_START_ROOT___" }
        /<pre [^>]*class="userinput"[^>]*>/ { in_block=1; print "___BLOCK_START_USER___" }
        in_block { print }
        /<\/pre>/ { in_block=0; print "___BLOCK_END___" }
    ' | perl -0777 -pe 's/<[^>]+>//gs' | \
        sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | \
        sed 's/^[[:space:]]*//' | \
        grep -vE "^$|^exec |vim -c |mountpoint -q /dev/shm|mount -t tmpfs devshm" | \
        perl -0777 -pe '
            # 1. Remove trailing && before block ends or start of next markers
            s/\s*&&\s*\n\s*?___BLOCK_END___/\n___BLOCK_END___/gs;
            s/\s*&&\s*\n\s*?___BLOCK_START_/\n___BLOCK_START_/gs;
            # 2. Remove empty blocks
            s/___BLOCK_START_(ROOT|USER)___\s*___BLOCK_END___\s*//gs;
            # 3. Final cleanup of any trailing && at end of file
            s/\s*&&\s*$//gs;
        '
}

    log "Extracting build commands..."
    RAW_CONTENT=$(get_commands "$HTML_CONTENT")

    # Special handling for Linux kernel - include headers
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Adding Linux API Headers build steps..."
        HEADER_HTML=$(curl -s "$LFS_BOOK/chapter05/linux-headers.html")
        # In a running system, we don't use $LFS prefix and we install to /usr
        # Prepend header commands to RAW_CONTENT so they get processed by the annotation loop
        HEADER_CMDS=$(get_commands "$HEADER_HTML" | sed 's/\$LFS//g')
        RAW_CONTENT="${HEADER_CMDS}
${RAW_CONTENT}"
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
while read -r line; do
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

        # Determine effective type: explicit root, or heuristic for userinput blocks
        _eff_type="$CURRENT_BLOCK_TYPE"
        if [[ "$_eff_type" == "user" ]]; then
            if grep -qE '^[[:space:]]*(make[[:space:]]+.*install|ninja[[:space:]]+.*install|meson[[:space:]].*install|cmake[[:space:]]+--install|install[[:space:]].*(/usr|/boot|/etc|/lib|/var)|ln[[:space:]].*(/usr|/boot|/etc|/lib|/var)|rm[[:space:]].*(/usr|/boot|/etc|/lib|/var)|cp[[:space:]].*(/usr|/boot|/etc|/lib|/var)|mv[[:space:]].*(/usr|/boot|/etc|/lib|/var)|(mkinitramfs|grub-mkconfig|ldconfig|depmod))' <<< "$CURRENT_BLOCK"; then
                _eff_type="root"
            fi
        fi
        
        # 1. Block Blacklist (mainly for glibc)
        if [[ "$PACKAGE" == "glibc" ]]; then
            if grep -qiE "(nscd|gcc[[:space:]]+-print-libgcc-file-name|localedef|localedata/install-locales|nsswitch\.conf|ZONEINFO|tzselect|localtime|ld\.so\.conf)" <<< "$CURRENT_BLOCK"; then
                log "Skipping unnecessary glibc configuration/maintenance block." >&2
                continue
            fi
        fi
        
        # 2. Skip duplicate configure blocks (BLFS shows alternatives)
        if [[ "$CURRENT_BLOCK" =~ [[:space:]]*\./configure ]]; then
            if [[ "$configure_seen" == "true" ]]; then
                log "Skipping duplicate configure block (alternative build method)." >&2
                continue
            fi
            configure_seen="true"
        fi

        # 3. Skip system configuration and service management blocks
        if grep -qE "(groupadd|useradd|usermod|systemctl)" <<< "$CURRENT_BLOCK"; then
            log "Skipping system configuration/service management block." >&2
            continue
        fi

        # 4. Skip blfs-systemd-units install commands
        if [[ "$CURRENT_BLOCK" =~ make[[:space:]]+install-dhcpcd ]]; then
            log "Skipping blfs-systemd-units install command." >&2
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
        if [[ "$INCLUDE_CONFIG" == "false" ]] && grep -qE "^cat[[:space:]]*>[[:space:]]*/etc/|^cat[[:space:]]*>[[:space:]]*/var/" <<< "$CURRENT_BLOCK"; then
            log "Skipping post-installation configuration block." >&2
            continue
        fi

        # 7. Determine if this block is a test suite or related setup
        if [[ "$XORG_MULTI_MODE" == "false" ]] && [[ "$CURRENT_BLOCK" =~ (make.*(check|test|tests|jstest|jit-test|all-headless)|ninja.*test|spawn.*make|\<expect\>|tester|su.*tester|testdir|test_summary|cd[[:space:]]+t$) ]]; then
            if [[ "$is_critical" == "true" ]]; then
                CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
                COMMANDS+="
# __BEGIN_ROOT__
if ! (
$CURRENT_BLOCK
); then
    echo '[WARNING] Test suite for $PACKAGE failed.'
    read -p 'Build failed tests. Proceed to installation anyway? [y/N] ' -n 1 -r < /dev/tty
    echo
    if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
# __END_ROOT__
"
            else
                log "Skipping non-critical test block." >&2
            fi
        elif [[ "$CURRENT_BLOCK" =~ "patch" ]]; then
            CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
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
            while read -r bline; do
                if [[ "$bline" =~ ^(make([[:space:]]|$)|\./configure[[:space:]]&&[[:space:]]make([[:space:]]|$)) ]] && \
                   [[ ! "$bline" =~ "install" ]] && \
                   [[ ! "$bline" =~ "headers" ]] && \
                   [[ ! "$bline" =~ "-j" ]]; then
                    bline=$(echo "$bline" | sed -E 's/\bmake\b/make -j$(nproc)/g')
                elif [[ "$bline" =~ ^ninja([[:space:]]|$) ]] && [[ ! "$bline" =~ "-j" ]]; then
                    bline=$(echo "$bline" | sed -E 's/\bninja\b/ninja -j$(nproc)/g')
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

if [[ -z "$COMMANDS" ]]; then
    error "Could not extract build commands for '$PACKAGE'"
fi

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

# 2.7 Auto-detect Qt6 dependency
if echo "$HTML_CONTENT" | grep -qiE "qt-6|qt6|qt 6"; then
    log "Qt6 dependency detected: adding /opt/qt6/bin to PATH."
    SETUP_COMMANDS+="export PATH=\$PATH:/opt/qt6/bin
"
fi

# 2.8 Respect existing Fortran support for GCC
if [[ "$PACKAGE" == "gcc" ]] && [[ "$COMMANDS" == *"--enable-languages=c,c++"* ]]; then
    if target_run "command -v gfortran" &>/dev/null; then
        log "gfortran detected on target system. Adding Fortran support to GCC build."
        COMMANDS="${COMMANDS/--enable-languages=c,c++/--enable-languages=c,c++,fortran}"
    fi
fi

# 2.8 Ensure LLVM is built with WebAssembly support (required by Firefox / wasm32-wasi)
if [[ "$PACKAGE" == "llvm" ]] && [[ "$COMMANDS" == *"LLVM_TARGETS_TO_BUILD"* ]]; then
    if [[ "$COMMANDS" != *"WebAssembly"* ]]; then
        log "Adding WebAssembly to LLVM_TARGETS_TO_BUILD."
        COMMANDS=$(echo "$COMMANDS" | sed 's/-D LLVM_TARGETS_TO_BUILD="\([^"]*\)"/-D LLVM_TARGETS_TO_BUILD="\1;WebAssembly"/')
    fi
fi

# 2.9 Check for documentation tools and disable if missing
DOC_TOOLS="doxygen gi-docgen db2html xmlto xsltproc sphinx-build"
DOC_PATTERNS="-D (docs?|documentation)=(enabled|true)|--enable-(gtk-doc|doxygen-docs|docs)"
ENABLE_DOC_BUILD=true

if [[ "$COMMANDS" =~ $DOC_PATTERNS ]]; then
    for tool in $DOC_TOOLS; do
        if [[ "$COMMANDS" =~ $tool ]] || [[ "$COMMANDS" =~ (docs?|documentation) ]]; then
            if ! target_run "command -v $tool" &>/dev/null; then
                log "[WARNING] Documentation tool '$tool' not found on target. Disabling documentation building."
                ENABLE_DOC_BUILD=false
                break
            fi
        fi
    done
fi

if [[ "$ENABLE_DOC_BUILD" == "false" ]]; then
    # Disable docs in meson, cmake, and autotools
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/-D (docs?|documentation)=enabled/-D \1=disabled/g')
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/-D (docs?|documentation)=true/-D \1=false/g')
    COMMANDS=$(echo "$COMMANDS" | sed -E 's/--enable-(gtk-doc|doxygen-docs|docs)/--disable-\1/g')
    # Handle meson configure specifically
    COMMANDS=$(echo "$COMMANDS" | sed 's/meson configure -D docs=enabled/meson configure -D docs=disabled/g')
    COMMANDS=$(echo "$COMMANDS" | sed 's/meson configure -D documentation=true/meson configure -D documentation=false/g')
    # Wrap standalone doxygen/gi-docgen calls
    COMMANDS=$(echo "$COMMANDS" | awk '
        /^(doxygen|gi-docgen)/ { print "if command -v " $1 " &>/dev/null; then"; print; print "fi"; next }
        { print }
    ')
fi

# 2.10 ensure XORG_PREFIX and XORG_CONFIG are set if referenced in commands
if [[ "$COMMANDS" =~ "XORG_PREFIX" || "$COMMANDS" =~ "XORG_CONFIG" ]]; then
    if [[ ! "$COMMANDS" =~ "export XORG_PREFIX=/usr" ]]; then
        SETUP_COMMANDS+="export XORG_PREFIX=/usr
export XORG_CONFIG=\"--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static\"
"
    fi
fi

# Special handling for Xorg multi-package targets (libs, apps, fonts, drivers)
if [[ "$XORG_MULTI_MODE" == "true" ]]; then
    log "Enabling Xorg multi-package loop mode."

    # Fix the bash subshell and execution for Xorg loops
    log "Converting Xorg build loop into a standalone script..."
    COMMANDS=$(echo "$COMMANDS" | awk '
        BEGIN {
            in_loop = 0
            in_as_root = 0
            in_md5 = 0
            as_root_content = ""
            other_cmds = ""
            loop_content = ""
            md5_file = ""
        }
        /^as_root\(\)/ { in_as_root = 1; as_root_content = $0; next }
        /^bash -e/ { next }
        /^exit/ { next }
        /^cat > .*\.md5 << "EOF"/ { 
            in_md5 = 1; 
            other_cmds = other_cmds "\n" $0; 
            next 
        }
        /^for package in/ { in_loop = 1; loop_content = $0; next }
        {
            if (in_as_root) {
                as_root_content = as_root_content "\n" $0
                if (/export -f as_root/) in_as_root = 0
            } else if (in_loop) {
                loop_content = loop_content "\n" $0
                if (/done/) in_loop = 0
            } else if (in_md5) {
                other_cmds = other_cmds "\n" $0
                if (/^EOF$/) in_md5 = 0
            } else {
                other_cmds = other_cmds "\n" $0
            }
        }
        END {
            sub(/^\n/, "", other_cmds)
            print "cd /sources/archives"
            print other_cmds
            print "cd /sources/archives"
            print "cat > build-xorg.sh << \"EOF\""
            print "#!/bin/bash"
            print "set -e"
            print ""
            print as_root_content
            print ""
            # Inject markers for BUILD_SCRIPT generator
            # The as_root from the book works if sudo is available.
            # We dont need to override it here.
            print ""
            print loop_content
            print "EOF"
            print "bash build-xorg.sh"
        }
    ')
fi

# 2.11 Special handling for KDE frameworks6 and plasma-all
FRAMEWORKS_MODE=false
if [[ "${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "plasma-all" || "${PACKAGE,,}" == "plasma" ]]; then
    FRAMEWORKS_MODE=true
    log "Enabling special KDE frameworks/plasma loop mode."
    
    # Remove the /opt/kf6 installation commands as user installs to /usr
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^mv .* /opt/kf6")
    COMMANDS=$(echo "$COMMANDS" | grep -vE "^ln -s.* /opt/kf6")

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

    
    # Ensure KF6_PREFIX, Qt6 PATH, and Qt6 LD_LIBRARY_PATH are set for all KDE packages
    if [[ ! "$COMMANDS" =~ "export KF6_PREFIX=/usr" ]]; then
        SETUP_COMMANDS+="export KF6_PREFIX=/usr
"
    fi
    if ! echo "$COMMANDS" | grep -q "LD_LIBRARY_PATH.*qt6"; then
        SETUP_COMMANDS+="export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/qt6/lib
"
    fi
    if ! echo "$COMMANDS" | grep -q "PATH.*qt6"; then
        SETUP_COMMANDS+="export PATH=\$PATH:/opt/qt6/bin
"
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

    # Strip desktop session testing commands (startx etc) which break SSH builds
    COMMANDS=$(echo "$COMMANDS" | sed '/cat > ~\/.xinitrc << "EOF"/,/EOF/d')
    COMMANDS=$(echo "$COMMANDS" | grep -v "^startx")

    # Fix the bash subshell and execution
    log "Converting build loop into a standalone script..."
    COMMANDS=$(echo "$COMMANDS" | awk '
        BEGIN {
            in_loop = 0
            in_as_root = 0
            in_md5 = 0
            as_root_content = ""
            other_cmds = ""
            loop_content = ""
        }
        /^as_root\(\)/ { in_as_root = 1; as_root_content = $0; next }
        /^bash -e/ { next }
        /^exit/ { next }
        /^cat > (frameworks|plasma)-.*\.md5 << "EOF"/ { in_md5 = 1; other_cmds = other_cmds "\n" $0; next }
        /^while read -r line; do/ { in_loop = 1; loop_content = $0; next }
        {
            if (in_as_root) {
                as_root_content = as_root_content "\n" $0
                if (/export -f as_root/) in_as_root = 0
            } else if (in_loop) {
                loop_content = loop_content "\n" $0
                if (/done < (frameworks|plasma)-.*\.md5/) in_loop = 0
            } else if (in_md5) {
                other_cmds = other_cmds "\n" $0
                if (/^EOF$/) in_md5 = 0
            } else {
                other_cmds = other_cmds "\n" $0
            }
        }
        END {
            sub(/^\n/, "", other_cmds)
            print "cd /sources/archives"
            print other_cmds
            print "cd /sources/archives"
            print "cat > build-frameworks.sh << \"EOF\""
            print "#!/bin/bash"
            print "set -e"
            print ""
            print as_root_content
            print ""
            print loop_content
            print "EOF"
            print "bash build-frameworks.sh"
    ')
fi

# 2.22 Extract Download URL and identify main filename
if [[ "$SKIP_HTML_EXTRACTION" == "true" ]]; then
    # Already set by special case
    :
elif [[ "$XORG_MULTI_MODE" == "true" ]]; then
        # Extract md5 file content and base URL to populate DOWNLOAD_URLS
        BASE_URL=$(echo "$COMMANDS" | perl -nle 'if (/ -B\s+(https?:\/\/\S+)/) { print $1; exit }')
        if [[ -z "$BASE_URL" ]]; then
            case "$PACKAGE" in
                xorg-lib|x7lib)       BASE_URL="https://www.x.org/pub/individual/lib/" ;;
                xorg-app|x7app)       BASE_URL="https://www.x.org/pub/individual/app/" ;;
                xorg-font|x7font)     BASE_URL="https://www.x.org/pub/individual/font/" ;;
                xorg-driver|x7driver) BASE_URL="https://www.x.org/pub/individual/driver/" ;;
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
            DOWNLOAD_URLS+=("${BASE_URL}${f}")
        done
        MAIN_DOWNLOAD_URL="${DOWNLOAD_URLS[0]}"
    fi
fi

if [[ "$UPSTREAM" == "true" ]]; then
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Fetching latest mainline Linux kernel version..."
        KERNEL_VER=$(curl -s https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | perl -nle 'while (m{[0-9.]+}g) { print $& }' | sort -Vr | head -n 1)
        if [[ -n "$KERNEL_VER" ]]; then
            # Append .0 if version doesn't have two dots (e.g., 6.19 -> 6.19.0)
            if [[ $(echo "$KERNEL_VER" | grep -o '\.' | wc -l) -eq 1 ]]; then
                KERNEL_VER="${KERNEL_VER}.0"
            fi
            MAJOR=$(echo "$KERNEL_VER" | cut -d. -f1)
            DOWNLOAD_URLS+=("https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KERNEL_VER}.tar.xz")
            UPSTREAM_VERSION="$KERNEL_VER"
        fi
    elif [[ "$PACKAGE" == "vim" ]]; then
        log "Fetching latest upstream Vim version from GitHub..."
        VIM_TAG=$(curl -sL https://github.com/vim/vim/tags | perl -nle 'while (m{href="/vim/vim/releases/tag/v\K[0-9.]+}g) { print $& }' | head -n 1)
        if [[ -z "$VIM_TAG" ]]; then
             VIM_TAG=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | perl -nle 'while (m{(?<="tag_name": "v)[0-9.]+}g) { print $& }' | head -n 1)
        fi
        
        if [[ -n "$VIM_TAG" ]]; then
            DOWNLOAD_URLS+=("https://github.com/vim/vim/archive/v${VIM_TAG}/vim-${VIM_TAG}.tar.gz")
            UPSTREAM_VERSION="$VIM_TAG"
        fi
    elif [[ "$PACKAGE" == "firefox" ]]; then
        log "Fetching latest upstream Firefox version from Mozilla..."
        FIREFOX_JSON=$(curl -s https://product-details.mozilla.org/1.0/firefox_versions.json)
        UPSTREAM_VERSION=$(echo "$FIREFOX_JSON" | perl -nle 'while (m{(?<="LATEST_FIREFOX_VERSION": ")[0-9.]+}g) { print $& }')
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            DOWNLOAD_URLS+=("https://archive.mozilla.org/pub/firefox/releases/${UPSTREAM_VERSION}/source/firefox-${UPSTREAM_VERSION}.source.tar.xz")
        fi
    elif [[ "${PACKAGE,,}" == "frameworks6" || "${PACKAGE,,}" == "frameworks" ]]; then
        log "Fetching latest upstream KDE Frameworks version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE Frameworks version: $UPSTREAM_VERSION"
        fi
    elif [[ "${PACKAGE,,}" == "plasma-all" || "${PACKAGE,,}" == "plasma" ]]; then
        log "Fetching latest upstream KDE Plasma version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/plasma/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE Plasma version: $UPSTREAM_VERSION"
        fi
    elif [[ "${PACKAGE,,}" =~ ^(konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)$ ]]; then
        log "Fetching latest upstream KDE Application (Gear) version from KDE mirrors..."
        UPSTREAM_VERSION=$(curl -sL https://download.kde.org/stable/release-service/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1)
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            log "Found upstream KDE App version: $UPSTREAM_VERSION"
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
        UPSTREAM_VERSION=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases/latest | perl -nle 'while (m{"tag_name":\s*"llvmorg-([0-9.]+)"}g) { print $1 }' | head -n 1)
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
    else
        log "Upstream flag ignored for package '$PACKAGE' (only supported for linux, vim, firefox, frameworks, plasma, libuv, and KDE apps)"
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
else
    PKG_BASE=$(echo "$PACKAGE" | sed 's/[0-9]*$//')
fi
log "Package base name for search: $PKG_BASE"

if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]] || [[ "$UPSTREAM" == "true" ]]; then
    # 0. Primary Link from Page (Robust Extraction)
    # The first "Download (HTTP)" link is usually the main one
    http_download=$(echo "$HTML_CONTENT" | perl -0777 -ne 'if (/Download \(HTTP\):\s*<a[^>]+href="([^"]+)"/is) { print $1 }')
    [[ -n "$http_download" ]] && DOWNLOAD_URLS+=("$http_download")

    # 1. Main Page Links (for both LFS and BLFS)
    # Extract all archive and patch links
    mapfile -t PAGE_LINKS < <(printf '%s' "$HTML_CONTENT" | perl -nle 'while (m{(?i)https?://[^\s"]*(\.tar\.[a-z2]+|\.zip|\.patch|\.tgz)}g) { print $& }' | sort -u)
    
    # 2. LFS Patches Page (for LFS packages)
    if [[ "$PAGE_URL" == *"/lfs/"* ]]; then
        log "Searching LFS Chapter 3 for packages and patches..."
        # Add main source from chapter 3 if not found on page
        LFS_PKG_URL=$(curl -s "$LFS_BOOK/chapter03/packages.html" | perl -nle "while (m{(?i)https?://[^\\s\"]*/${PKG_BASE}-?[0-9][^\\s\"]*(\\.tar\\.[a-z2]+|\\.zip)}g) { print $& }" | head -n 1)
        [[ -n "$LFS_PKG_URL" ]] && DOWNLOAD_URLS+=("$LFS_PKG_URL")
        
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
        if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "llvm" ]] && [[ "$(basename "$link")" =~ (llvm-|clang-|cmake-|third-party-|compiler-rt-)[0-9] ]]; then
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

        if grep -Eiq "${match_pattern}" <<< "$link_base" || \
           ([[ "$PACKAGE" == "spidermonkey" ]] && grep -qi "firefox" <<< "$link_base"); then
            DOWNLOAD_URLS+=("$link")
        fi
    done
fi

# Final deduplication and prioritization
if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]] && [[ "$FRAMEWORKS_MODE" == "false" ]] && [[ "$XORG_MULTI_MODE" == "false" ]]; then
    error "Could not find any download URLs for '$PACKAGE'"
fi

# Remove duplicates while preserving order (to some extent)
DOWNLOAD_URLS=($(printf "%s\n" "${DOWNLOAD_URLS[@]}" | awk '!x[$0]++'))

if [[ "$FRAMEWORKS_MODE" == "false" && "$XORG_MULTI_MODE" == "false" ]]; then
    # Identify MAIN_DOWNLOAD_URL (the one that looks most like the source archive)
    MAIN_DOWNLOAD_URL=""
    for url in "${DOWNLOAD_URLS[@]}"; do
        fname=$(basename "$url")
        # For LLVM, prefer the monorepo if available
        if [[ "$PACKAGE" == "llvm" ]] && [[ "$fname" == *"llvm-project-"* ]]; then
            MAIN_DOWNLOAD_URL="$url"
            break
        fi
        # Priority 1: matches package-version.tar.*
        if [[ "$fname" =~ ^${PKG_BASE}-?[0-9].*\.tar\. ]]; then
            MAIN_DOWNLOAD_URL="$url"
            break
        fi
    done

    # Fallback: first one that isn't a patch or docs
    if [[ -z "$MAIN_DOWNLOAD_URL" ]]; then
        for url in "${DOWNLOAD_URLS[@]}"; do
            fname=$(basename "$url")
            if [[ ! "$fname" =~ \.patch$ ]] && [[ ! "$fname" =~ -docs ]]; then
                MAIN_DOWNLOAD_URL="$url"
                break
            fi
        done
    fi

    # Final fallback: first one
    [[ -z "$MAIN_DOWNLOAD_URL" ]] && MAIN_DOWNLOAD_URL="${DOWNLOAD_URLS[0]}"

    log "Identified main archive: $MAIN_DOWNLOAD_URL"
    log "Total files to download: ${#DOWNLOAD_URLS[@]}"
else
    log "Frameworks mode: skipping MAIN_DOWNLOAD_URL identification."
fi

# Replace hardcoded Vim versions when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "vim" && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (e.g., "9.1.2031")
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{vim-\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    
    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS version $LFS_VERSION with upstream version $UPSTREAM_VERSION in commands..."
        # Replace full version strings
        COMMANDS="${COMMANDS//vim-$LFS_VERSION/vim-$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        
        # Replace vimXY directory references (e.g., vim91 -> vim92)
        LFS_MAJOR_MINOR=$(echo "$LFS_VERSION" | cut -d. -f1-2 | tr -d '.')
        UPSTREAM_MAJOR_MINOR=$(echo "$UPSTREAM_VERSION" | cut -d. -f1-2 | tr -d '.')
        COMMANDS="${COMMANDS//vim$LFS_MAJOR_MINOR/vim$UPSTREAM_MAJOR_MINOR}"
    fi
fi

# Replace hardcoded Linux kernel versions and fix build commands when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "linux" && -n "$UPSTREAM_VERSION" ]]; then
    # Fetch LFS release version (e.g., "r12.4-84")
    log "Fetching LFS release version from systemd manual..."
    LFS_RELEASE=$(curl -s https://www.linuxfromscratch.org/lfs/view/systemd/chapter10/kernel.html | \
                  grep "systemd" | head -n 1 | cut -d '"' -f 4 | \
                  sed 's/lfs-//g' | sed 's/-systemd//g')
    
    # Extract LFS kernel version from commands
    LFS_KERNEL_VER=$(echo "$COMMANDS" | perl -nle 'while (m{linux-\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    
    if [[ -n "$LFS_KERNEL_VER" ]]; then
        log "Processing Linux kernel commands..."
        log "Replacing LFS kernel version $LFS_KERNEL_VER with upstream version $UPSTREAM_VERSION"
        if [[ -n "$LFS_RELEASE" ]]; then
            log "Using LFS release version: $LFS_RELEASE"
        fi
        
        # Replace kernel version strings
        COMMANDS="${COMMANDS//$LFS_KERNEL_VER/$UPSTREAM_VERSION}"
        
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
            /^make modules_install/ {
                print
                print ""
                print "mkinitramfs " ver
                print "mv initrd.img-" ver " /boot/initramfs-" ver "-lfs-" lfs_rel "-systemd.img"
                next
            }
            /^cp -iv arch\/x86\/boot\/bzImage \/boot\/vmlinuz-/ {
                print
                print ""
                print "grub-mkconfig -o /boot/grub/grub.cfg"
                next
            }
            { print }
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
    fi
fi

if [[ "$UPSTREAM" == "true" && ("${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "frameworks6") && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (e.g. frameworks-6.23.0.md5)
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{frameworks-\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS KDE Frameworks version $LFS_VERSION with $UPSTREAM_VERSION.0 in commands..."
        LFS_MAJOR_MINOR=$(echo "$LFS_VERSION" | cut -d. -f1-2)
        # Fix URL: replace only the version number in the path (avoid double-slash)
        COMMANDS=$(echo "$COMMANDS" | sed "s|/stable/frameworks/${LFS_MAJOR_MINOR}/|/stable/frameworks/${UPSTREAM_VERSION}/|g")
        COMMANDS="${COMMANDS//frameworks-$LFS_VERSION/frameworks-${UPSTREAM_VERSION}.0}"
        COMMANDS="${COMMANDS//$LFS_VERSION/${UPSTREAM_VERSION}.0}"
    fi
fi

if [[ "$UPSTREAM" == "true" && ("${PACKAGE,,}" == "plasma" || "${PACKAGE,,}" == "plasma-all") && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (e.g. plasma-6.6.1.md5)
    LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{plasma-\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS KDE Plasma version $LFS_VERSION with $UPSTREAM_VERSION in commands..."
        COMMANDS="${COMMANDS//plasma-$LFS_VERSION/plasma-$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

if [[ "$UPSTREAM" == "true" && "${PACKAGE,,}" =~ ^(konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)$ && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from the identified main download URL (e.g. konsole-24.12.2.tar.xz)
    LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle "while (m{${PKG_BASE}-\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }" | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$MAIN_DOWNLOAD_URL" | perl -nle 'while (m{[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        # Fallback
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
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
    fi
fi

if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "libuv" && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from HTML content (before it gets overwritten or supplemented)
    LFS_VERSION=$(echo "$HTML_CONTENT" | perl -nle 'while (m{libuv-v\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{libuv-v\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    fi
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | perl -nle 'while (m{v\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | head -n 1)
    fi
    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS libuv version $LFS_VERSION with $UPSTREAM_VERSION in commands and URLs..."
        COMMANDS="${COMMANDS//v$LFS_VERSION/v$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
        for i in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URLS[$i]="${DOWNLOAD_URLS[$i]//$LFS_VERSION/$UPSTREAM_VERSION}"
        done
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

# Replace hardcoded LLVM versions when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "llvm" && -n "$UPSTREAM_VERSION" ]]; then
    # 1. Broad version replacement
    FOUND_VERSIONS=()
    while IFS= read -r v; do
        [[ -n "$v" ]] && FOUND_VERSIONS+=("$v")
    done < <(echo "$COMMANDS ${DOWNLOAD_URLS[*]}" | perl -nle 'while (m{[0-9]+\.[0-9]+\.[0-9]+}g) { print "$&\n" }' | sort -u)
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
            if [[ "$fname" == *"$UPSTREAM_VERSION"* ]]; then
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
fi

# Deduplicate DOWNLOAD_URLS while preserving order as much as possible
if [[ ${#DOWNLOAD_URLS[@]} -gt 0 ]]; then
    mapfile -t DOWNLOAD_URLS < <(printf "%s\n" "${DOWNLOAD_URLS[@]}" | awk '!x[$0]++')
fi

# For plasma/frameworks, prevent wget -r from re-downloading already-fetched archives
# when it revisits directory sort-order links (?C=N;O=A etc)
if [[ "${PACKAGE,,}" == "plasma" || "${PACKAGE,,}" == "plasma-all" || \
      "${PACKAGE,,}" == "frameworks" || "${PACKAGE,,}" == "frameworks6" ]]; then
    COMMANDS=$(echo "$COMMANDS" | sed 's/wget -r /wget -r --no-clobber /g')
fi


if [[ "$PACKAGE" == "vim" ]]; then
    log "Removing /usr/bin/vi symlink creation and cleaning up docs..."
    # Remove symlink creation for vi that often appears in the book
    COMMANDS=$(echo "$COMMANDS" | grep -v "ln -sv .* /usr/bin/vi")
    # Also remove the loop that links vi.1 and other man pages
    COMMANDS=$(echo "$COMMANDS" | perl -0777 -pe 's/for L in.*?do.*?ln -sv vim\.1.*?done//gs')
    # Clean up old documentation before linking the new one
    COMMANDS=$(echo "$COMMANDS" | sed "\|ln -sv ../vim/vim$UPSTREAM_MAJOR_MINOR/doc /usr/share/doc/vim-$UPSTREAM_VERSION|i rm -rf /usr/share/doc/vim-*")
fi


if [[ "$FRAMEWORKS_MODE" == "true" || "$XORG_MULTI_MODE" == "true" ]]; then
    MAIN_FILENAME="$PACKAGE"
    DIRNAME="$PACKAGE"
    ALL_FILENAMES=()
else
    MAIN_FILENAME=$(basename "$MAIN_DOWNLOAD_URL")
    DIRNAME=$(echo "$MAIN_FILENAME" | sed 's/\.tar.*//; s/\.zip//')
    ALL_FILENAMES=()
    for url in "${DOWNLOAD_URLS[@]}"; do
        ALL_FILENAMES+=("$(basename "$url")")
    done
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
            echo "su '${normal_user}' -s /bin/bash << '${sentinel}'"
            echo "set -e"
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
            if [[ "$cmd" =~ (^|[[:space:]])cd[[:space:]]+\"([^\"]+)\" ]]; then
                target="${BASH_REMATCH[2]}"
            elif [[ "$cmd" =~ (^|[[:space:]])cd[[:space:]]+\'([^\']+)\' ]]; then
                target="${BASH_REMATCH[2]}"
            elif [[ "$cmd" =~ (^|[[:space:]])cd[[:space:]]+([^[:space:]&;\|]+) ]]; then
                target="${BASH_REMATCH[2]}"
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
    echo "BUILD_DIR=\"/sources/${dirname}\""
    echo "# Grant regular user access to build directory for compilation"
    echo "chown -R '${normal_user}' \"/sources/${dirname}\" 2>/dev/null || true"
    echo "cd '/sources/${dirname}'"

    while IFS= read -r line; do
        if [[ "$line" == "# __BEGIN_ROOT__" ]]; then
            _flush_user
            in_section="root"
            # Ensure ROOT blocks start with setup commands
            if [[ -n "$setup_cmds" ]]; then
                echo "$setup_cmds"
            fi
            # Ensure ROOT blocks start in the tracked directory
            echo "cd \"/sources/${dirname}/${current_rel_dir}\" || cd \"/sources/${dirname}\""
        elif [[ "$line" == "# __END_ROOT__" ]]; then
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
log "Starting remote build for $PACKAGE..."

# Generate the Privilege-Separated build script locally
BUILD_SCRIPT_LOCAL=$(_gen_build_script "$GEN_DIRNAME" "$NORMAL_USER" "$SETUP_COMMANDS")

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
  printf 'XORG_MULTI_MODE="%s"\n' "$XORG_MULTI_MODE"
  # Inject BS_B64 from a temporary file to avoid shell argument limits
  printf '%s' "$BUILD_SCRIPT_LOCAL" | base64 -w 0 > /tmp/bs_b64.txt
  printf 'BS_B64="'
  cat /tmp/bs_b64.txt
  printf '"\n'
  rm -f /tmp/bs_b64.txt

  # 2. Inject arrays safely using declare -p
  declare -p DOWNLOAD_URLS ALL_FILENAMES

  # 3. Append the main logic using a quoted heredoc
  cat <<'REMOTE_EOF'
set -e
mkdir -p /sources/archives
cd /sources/archives

# 1. Download all files
for url in "${DOWNLOAD_URLS[@]}"; do
    fname=$(basename "$url")
    if [[ "$fname" == *".patch"* ]]; then
        # Resilient download for patches
        if [ ! -s "$fname" ]; then rm -f "$fname"; echo "Downloading $fname..."; wget "$url" || echo "[WARNING] Failed to download $fname"; fi
    else
        if [ ! -s "$fname" ]; then rm -f "$fname"; echo "Downloading $fname..."; wget "$url"; fi
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
            rm "$f"
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
    rm -rf "/sources/$DIRNAME"
    mkdir -p "/sources/$DIRNAME"
    tar -xf "$MAIN_FILENAME" -C "/sources/$DIRNAME" --strip-components=1
    # Ensure recursive ownership immediately after extraction
    chown -R "${NORMAL_USER}" "/sources/$DIRNAME"
    cd "/sources/$GEN_DIRNAME"
fi

echo "Marking build start time..."
touch /tmp/build_start_timestamp_${PACKAGE}

echo "Running build commands (user blocks as ${NORMAL_USER}, root blocks as root)..."
# The build script is injected via an environment variable on the guest
# to avoid quoting issues with base64 embedding inside the remote script.
if [ -n "$BS_B64" ]; then
    echo "$BS_B64" | base64 -d > /tmp/build-cmds-${PACKAGE}.sh
    chmod +x /tmp/build-cmds-${PACKAGE}.sh
    bash /tmp/build-cmds-${PACKAGE}.sh
else
     echo "[ERROR] BUILD_SCRIPT content (BS_B64) not found on guest."
     exit 1
fi

echo "Performing post-install cleanup of old versions..."
# Find files installed by this build (newer than timestamp)
SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt"
EXISTING_DIRS=""
for d in $SEARCH_DIRS; do
    [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"
done

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
rm -f "$NEW_FILES_LIST" /tmp/build_start_timestamp_${PACKAGE}

for doc_dir in /usr/share/doc/linux-*; do
    [ -d "$doc_dir" ] || continue
    if ! [[ "$doc_dir" -nt /tmp/build_start_timestamp_${PACKAGE} ]] 2>/dev/null; then
        echo "Removing old kernel doc directory: $doc_dir"
        rm -rf "$doc_dir"
    fi
done

echo "Build and installation complete for $PACKAGE"
cd /sources
rm -rf "$GEN_DIRNAME"
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
    ssh_lfs "rm -f /tmp/remote_script_${PACKAGE}.sh"
    if [[ $CODE -ne 0 ]]; then
        error "Remote build script failed for $PACKAGE."
    fi
else
    # Running on guest already (piped)
    sudo bash /tmp/remote_script_${PACKAGE}.sh
fi
rm -f /tmp/remote_script_${PACKAGE}.sh

if [[ "$STRIP" == "true" ]]; then
    if [ -f "$NIXCFG/shell/user/21-lfs.sh" ]; then
        source "$NIXCFG/shell/user/21-lfs.sh"
        lfs_strip
    else
        echo "Warning: STRIP skipped because 21-lfs.sh is not available locally."
    fi
fi

done
