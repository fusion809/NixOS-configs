#!/usr/bin/env bash
# Automate LFS/BLFS package building by scraping official books (Development/SVN)

# Ensure NIXCFG is set
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source dependencies
source "$NIXCFG/shell/user/08-ssh.sh"
source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

LFS_BOOK_DEFAULT="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_BOOK_DEFAULT="https://linuxfromscratch.org/blfs/view/systemd"
LFS_BOOK="$LFS_BOOK_DEFAULT"
BLFS_BOOK="$BLFS_BOOK_DEFAULT"

DRY_RUN=false
STRIP=false
UPSTREAM=false
SEARCH_LFS=true
SEARCH_BLFS=true
PACKAGE=""

usage() {
    echo "Usage: $0 [options] <package-name>"
    echo "Options:"
    echo "  --dry-run             Show commands without executing them"
    echo "  --strip               Run stripping commands after build"
    echo "  --upstream            Attempt to find the latest upstream version (linux and vim only)"
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
        *) PACKAGE="$1" ;;
    esac
    shift
done

if [[ -z "$PACKAGE" ]]; then
    usage
fi

log() { echo "[$(date +'%H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

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
        # Search in LFS chapter 8 (development)
        local lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*${pkg}[^\"]*\.html)\"/is) { print \$1; exit }")
        
        if [[ -n "$lfs_page" ]]; then
            echo "$LFS_BOOK/chapter08/$lfs_page"
            return 0
        fi
    fi

    if [[ "$SEARCH_BLFS" == "true" ]]; then
        log "Searching for '$pkg' in BLFS index..." >&2
        # Search in BLFS long index
        local blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | tr -d '\r' | perl -0777 -ne "if (/href\s*=\s*\"([^\"]*${pkg}[^\"]*\.html)\"/is) { print \$1; exit }")
        
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

PAGE_URL=$(find_package_page "$PACKAGE")
if [[ -z "$PAGE_URL" ]]; then
    error "Could not find page for package '$PACKAGE'"
fi

log "Found package page: $PAGE_URL"

# 2. Extract Download URL and Build Commands
log "Fetching content from $PAGE_URL..."
HTML_CONTENT=$(curl -s "$PAGE_URL")

if [[ -z "$HTML_CONTENT" ]]; then
    error "Empty content from $PAGE_URL"
fi

get_commands() {
    local html="$1"
    # Extract blocks and clean them individually
    printf '%s' "$html" | awk '
        BEGIN { IGNORECASE=1 }
        /<pre [^>]*class="(userinput|root)"[^>]*>/ { in_block=1; print "___BLOCK_START___" }
        in_block { print }
        /<\/pre>/ { in_block=0; print "___BLOCK_END___" }
    ' | perl -0777 -pe 's/<[^>]+>//gs' | \
        sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | \
        sed 's/^[[:space:]]*//' | \
        grep -vE "^$|^exec |vim -c |mountpoint -q /dev/shm|mount -t tmpfs devshm"
}

log "Extracting build commands..."
RAW_CONTENT=$(get_commands "$HTML_CONTENT")

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
configure_seen=false
while read -r line; do
    if [[ "$line" == "___BLOCK_START___" ]]; then
        CURRENT_BLOCK=""
        continue
    elif [[ "$line" == "___BLOCK_END___" ]]; then
        [[ -z "$CURRENT_BLOCK" ]] && continue
        
        # 1. Block Blacklist (mainly for glibc)
        if [[ "$PACKAGE" == "glibc" ]]; then
            # Using grep -qi for robust case-insensitive matching
            if grep -qiE "(nscd|gcc[[:space:]]+-print-libgcc-file-name|localedef|localedata/install-locales|nsswitch\.conf|ZONEINFO|tzselect|localtime|ld\.so\.conf)" <<< "$CURRENT_BLOCK"; then
                log "Skipping unnecessary glibc configuration/maintenance block." >&2
                continue
            fi
        fi
        
        # 2. Skip duplicate configure blocks (BLFS shows alternatives)
        # Keep only the first ./configure block encountered
        # Note: Match optionally indented ./configure
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
        # But preserve blocks containing 'make install'
        if [[ "$PACKAGE" == "openssh" ]]; then
            if [[ ! "$CURRENT_BLOCK" =~ "make install" ]] && grep -qE "(sshd_config|ssh-keygen|ssh-copy-id)" <<< "$CURRENT_BLOCK"; then
                log "Skipping OpenSSH configuration block." >&2
                continue
            fi
            # Skip install-sshd (configuration step)
            if [[ "$CURRENT_BLOCK" =~ "make install-sshd" ]]; then
                log "Skipping OpenSSH install-sshd block." >&2
                continue
            fi
        fi

        
        # 3. Skip post-installation configuration blocks
        # These are blocks that create config files in /etc/ or /var/
        if grep -qE "^cat[[:space:]]*>[[:space:]]*/etc/|^cat[[:space:]]*>[[:space:]]*/var/" <<< "$CURRENT_BLOCK"; then
            log "Skipping post-installation configuration block." >&2
            continue
        fi

        # 4. Determine if this block is a test suite or related setup
        # keywords: make/ninja tests, expect scripts, tester user, su to tester, testdir, test_summary
        if [[ "$CURRENT_BLOCK" =~ (make.*(check|test|tests|jstest|jit-test)|ninja.*test|spawn.*make|\<expect\>|tester|su.*tester|testdir|test_summary) ]]; then
            if [[ "$is_critical" == "true" ]]; then
                # Wrap critical test block in prompt
                # Note: Remove trailing newline for cleaner injection
                CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
                COMMANDS+="
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
"
            else
                log "Skipping non-critical test block." >&2
            fi
        elif [[ "$CURRENT_BLOCK" =~ "patch" ]]; then
            # Resilient patching: Wrap patch commands to ignore failures
            CURRENT_BLOCK="${CURRENT_BLOCK%$'\n'}"
            COMMANDS+="
echo \"Attempting to apply patch...\"
( $CURRENT_BLOCK ) || echo \"[WARNING] Patch application failed, continuing build...\"
"
        else
            # Not a test or patch block, process for parallel make
            # We decompose block into lines to apply -j$(nproc) safely
            while read -r bline; do
                if [[ "$bline" =~ ^(make|./configure && make) ]] && \
                   [[ ! "$bline" =~ "install" ]] && \
                   [[ ! "$bline" =~ "headers" ]] && \
                   [[ ! "$bline" =~ "-j" ]]; then
                    bline=$(echo "$bline" | sed 's/make/make -j$(nproc)/')
                fi
                COMMANDS+="$bline"$'\n'
            done <<< "$CURRENT_BLOCK"
        fi
        continue
    fi
    CURRENT_BLOCK+="$line"$'\n'
done <<< "$RAW_CONTENT"

# Special handling for Linux kernel - include headers
if [[ "$PACKAGE" == "linux" ]]; then
    log "Adding Linux API Headers build steps..."
    HEADER_HTML=$(curl -s "$LFS_BOOK/chapter05/linux-headers.html")
    # In a running system, we don't use $LFS prefix and we install to /usr
    # Filter out block markers that are used for internal processing
    HEADER_CMDS=$(get_commands "$HEADER_HTML" | sed 's/\$LFS//g' | grep -v "^___BLOCK_")
    COMMANDS="${HEADER_CMDS}
${COMMANDS}"
fi

if [[ -z "$COMMANDS" ]]; then
    error "Could not extract build commands for '$PACKAGE'"
fi

# 2.5 Auto-detect Rust dependency
if echo "$HTML_CONTENT" | grep -qiE "rust|rustc|cargo"; then
    log "Rust dependency detected (rust/rustc/cargo found in page content)."
    COMMANDS="export PATH=\$PATH:/opt/rustc/bin
$COMMANDS"
fi

# 3. Resolve Download URLs
DOWNLOAD_URLS=()

if [[ "$UPSTREAM" == "true" ]]; then
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Fetching latest mainline Linux kernel version..."
        KERNEL_VER=$(curl -s https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -oP '[0-9.]+' | sort -Vr | head -n 1)
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
        VIM_TAG=$(curl -sL https://github.com/vim/vim/tags | grep -oP 'href="/vim/vim/releases/tag/v\K[0-9.]+' | head -n 1)
        if [[ -z "$VIM_TAG" ]]; then
             VIM_TAG=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | grep -oP '(?<="tag_name": "v)[0-9.]+' | head -n 1)
        fi
        
        if [[ -n "$VIM_TAG" ]]; then
            DOWNLOAD_URLS+=("https://github.com/vim/vim/archive/v${VIM_TAG}/vim-${VIM_TAG}.tar.gz")
            UPSTREAM_VERSION="$VIM_TAG"
        fi
    elif [[ "$PACKAGE" == "firefox" ]]; then
        log "Fetching latest upstream Firefox version from Mozilla..."
        FIREFOX_JSON=$(curl -s https://product-details.mozilla.org/1.0/firefox_versions.json)
        UPSTREAM_VERSION=$(echo "$FIREFOX_JSON" | grep -oP '(?<="LATEST_FIREFOX_VERSION": ")[0-9.]+')
        if [[ -n "$UPSTREAM_VERSION" ]]; then
            DOWNLOAD_URLS+=("https://archive.mozilla.org/pub/firefox/releases/${UPSTREAM_VERSION}/source/firefox-${UPSTREAM_VERSION}.source.tar.xz")
        fi
    else
        log "Upstream flag ignored for package '$PACKAGE' (only supported for linux, vim, and firefox)"
    fi
fi

# Strip trailing digits only for certain known versioned names (python3, lua5)
if [[ "$PACKAGE" =~ ^[a-zA-Z]+[0-9]$ ]]; then
    PKG_BASE="$PACKAGE"
else
    PKG_BASE=$(echo "$PACKAGE" | sed 's/[0-9]*$//')
fi
log "Package base name for search: $PKG_BASE"

if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]]; then
    # 0. Primary Link from Page (Robust Extraction)
    # The first "Download (HTTP)" link is usually the main one
    http_download=$(echo "$HTML_CONTENT" | perl -0777 -ne 'if (/Download \(HTTP\):\s*<a[^>]+href="([^"]+)"/is) { print $1 }')
    [[ -n "$http_download" ]] && DOWNLOAD_URLS+=("$http_download")

    # 1. Main Page Links (for both LFS and BLFS)
    # Extract all archive and patch links
    mapfile -t PAGE_LINKS < <(printf '%s' "$HTML_CONTENT" | grep -ioP "https?://[^\s\"]*(\.tar\.[a-z2]+|\.zip|\.patch|\.tgz)" | sort -u)
    
    # 2. LFS Patches Page (for LFS packages)
    if [[ "$PAGE_URL" == *"/lfs/"* ]]; then
        log "Searching LFS Chapter 3 for packages and patches..."
        # Add main source from chapter 3 if not found on page
        LFS_PKG_URL=$(curl -s "$LFS_BOOK/chapter03/packages.html" | grep -ioP "https?://[^\s\"]*/${PKG_BASE}-?[0-9][^\s\"]*(\.tar\.[a-z2]+|\.zip)" | head -n 1)
        [[ -n "$LFS_PKG_URL" ]] && DOWNLOAD_URLS+=("$LFS_PKG_URL")
        
        # Add patches from chapter 3
        mapfile -t LFS_PATCH_URLS < <(curl -s "$LFS_BOOK/chapter03/patches.html" | grep -ioP "https?://[^\s\"]*/${PKG_BASE}-[^\s\"]*\.patch" | sort -u)
        DOWNLOAD_URLS+=("${LFS_PATCH_URLS[@]}")
    fi

    # Filter page links for relevance
    for link in "${PAGE_LINKS[@]}"; do
        # Include if it matches package base name (case insensitive)
        # or if it's explicitly a patch on a package page
        # Special case: spidermonkey often uses firefox source
        if grep -qi "${PKG_BASE}" <<< "$(basename "$link")" || \
           ([[ "$PACKAGE" == "spidermonkey" ]] && grep -qi "firefox" <<< "$(basename "$link")"); then
            DOWNLOAD_URLS+=("$link")
        fi
    done
fi

# Final deduplication and prioritization
if [[ ${#DOWNLOAD_URLS[@]} -eq 0 ]]; then
    error "Could not find any download URLs for '$PACKAGE'"
fi

# Remove duplicates while preserving order (to some extent)
DOWNLOAD_URLS=($(printf "%s\n" "${DOWNLOAD_URLS[@]}" | awk '!x[$0]++'))

# Identify MAIN_DOWNLOAD_URL (the one that looks most like the source archive)
MAIN_DOWNLOAD_URL=""
for url in "${DOWNLOAD_URLS[@]}"; do
    fname=$(basename "$url")
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

# Replace hardcoded Vim versions when using --upstream
if [[ "$UPSTREAM" == "true" && "$PACKAGE" == "vim" && -n "$UPSTREAM_VERSION" ]]; then
    # Extract LFS version from commands (e.g., "9.1.2031")
    LFS_VERSION=$(echo "$COMMANDS" | grep -oP 'vim-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    
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
    LFS_KERNEL_VER=$(echo "$COMMANDS" | grep -oP 'linux-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    
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
            OLD_LFS_RELEASE=$(echo "$COMMANDS" | grep -oP 'lfs-r[0-9]+\.[0-9]+-[0-9]+' | head -n 1 | sed 's/lfs-//g')
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
                    print "cp /boot/config-$(uname -r) .config"
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
    LFS_VERSION=$(echo "$COMMANDS" | grep -oP 'firefox-\K[0-9.]+esr' | head -n 1)
    if [[ -z "$LFS_VERSION" ]]; then
        LFS_VERSION=$(echo "$COMMANDS" | grep -oP 'firefox-\K[0-9.]+' | head -n 1)
    fi

    if [[ -n "$LFS_VERSION" ]]; then
        log "Replacing LFS version $LFS_VERSION with upstream version $UPSTREAM_VERSION in commands..."
        COMMANDS="${COMMANDS//firefox-$LFS_VERSION/firefox-$UPSTREAM_VERSION}"
        COMMANDS="${COMMANDS//$LFS_VERSION/$UPSTREAM_VERSION}"
    fi
fi

if [[ "$PACKAGE" == "vim" ]]; then
    log "Removing /usr/bin/vi symlink creation..."
    COMMANDS=$(echo "$COMMANDS" | sed '/ln .* \/usr\/bin\/vi/d' | sed '/for L in.*do/d' | sed '/done/d' | sed '/ln -sv vim.1.*vi.1/d')
    COMMANDS=$(echo "$COMMANDS" | sed "\|ln -sv ../vim/vim$UPSTREAM_MAJOR_MINOR/doc /usr/share/doc/vim-$UPSTREAM_VERSION|i rm -rf /usr/share/doc/vim-*")
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo "------------------------------------------------------------"
    echo "DRY RUN: Download URLs for $PACKAGE"
    echo "------------------------------------------------------------"
    for url in "${DOWNLOAD_URLS[@]}"; do echo "$url"; done
    echo "------------------------------------------------------------"
    echo "DRY RUN: Commands for $PACKAGE"
    echo "------------------------------------------------------------"
    echo "$COMMANDS"
    echo "------------------------------------------------------------"
    if [[ "$STRIP" == "true" ]]; then
        source "$NIXCFG/shell/user/21-lfs.sh"
        lfs_strip --dry-run
    fi
    exit 0
fi

# 4. Remote Execution
MAIN_FILENAME=$(basename "$MAIN_DOWNLOAD_URL")
DIRNAME=$(echo "$MAIN_FILENAME" | sed 's/\.tar.*//; s/\.zip//')
ALL_FILENAMES=()
for url in "${DOWNLOAD_URLS[@]}"; do
    ALL_FILENAMES+=("$(basename "$url")")
done

log "Starting remote build for $PACKAGE..."

# Prepare the build script to run on the guest
# Note: Root execution is handled by running the entire script via sudo
REMOTE_SCRIPT=$(cat <<EOF
set -e
mkdir -p /sources/archives
cd /sources/archives

# 1. Download all files
$(for url in "${DOWNLOAD_URLS[@]}"; do
    fname=$(basename "$url")
    if [[ "$fname" == *".patch"* ]]; then
        # Resilient download for patches
        echo "if [ ! -f '$fname' ]; then echo 'Downloading $fname...'; wget '$url' || echo '[WARNING] Failed to download $fname'; fi"
    else
        echo "if [ ! -f '$fname' ]; then echo 'Downloading $fname...'; wget '$url'; fi"
    fi
done)

# 2. Cleanup old versions of the main package
echo "Cleaning up old versions..."
PKG_PREFIX=\$(echo "$MAIN_FILENAME" | sed 's/[-_]\?[0-9].*//')
PKG_NAME_PREFIX=\$(echo "$PACKAGE" | sed 's/[0-9]*$//')
if [ -n "\$PKG_PREFIX" ] || [ -n "\$PKG_NAME_PREFIX" ]; then
    for f in *; do
        [ -e "\$f" ] || continue
        # Skip files we just downloaded
        skip=false
        for df in ${ALL_FILENAMES[*]}; do [[ "\$f" == "\$df" ]] && skip=true && break; done
        [[ "\$skip" == "true" ]] && continue
        
        # Match archive prefix or package name prefix
        if ([[ -n "\$PKG_PREFIX" ]] && [[ "\$f" =~ ^\$PKG_PREFIX[-_]?[0-9] ]]) || \
           ([[ -n "\$PKG_NAME_PREFIX" ]] && [[ "\$f" =~ ^\$PKG_NAME_PREFIX[-_]?[0-9] ]]); then
            echo "Removing old version: \$f"
            rm "\$f"
        fi
    done
fi

# 3. Clean up /sources/ symlinks from previous runs
find /sources -maxdepth 1 -type l -delete

# 4. Symlink all downloaded files to /sources/ for easy access (except the main one if extracted)
for f in ${ALL_FILENAMES[*]}; do
    [ "\$f" == "$MAIN_FILENAME" ] && continue
    ln -sf "/sources/archives/\$f" "/sources/\$f"
done

# 5. Extract main archive
echo "Extracting $MAIN_FILENAME..."
rm -rf "/sources/$DIRNAME"
mkdir -p "/sources/$DIRNAME"
tar -xf "$MAIN_FILENAME" -C "/sources/$DIRNAME" --strip-components=1

cd "/sources/$DIRNAME"

echo "Marking build start time..."
touch /tmp/build_start_timestamp

echo "Running build commands..."
$COMMANDS

echo "Performing post-install cleanup of old versions..."
# Find files installed by this build (newer than timestamp)
# Limit search to common system directories to avoid scanning /home, /sources, etc.
SEARCH_DIRS="/usr /bin /sbin /lib /lib64 /etc /opt"
EXISTING_DIRS=""
for d in \$SEARCH_DIRS; do
    if [ -d "\$d" ]; then
        EXISTING_DIRS="\$EXISTING_DIRS \$d"
    fi
done

NEW_FILES_LIST=\$(mktemp)
# limit find to xdev to avoid traversing mounts, exclude the list file itself
find \$EXISTING_DIRS -xdev -newer /tmp/build_start_timestamp ! -name "\$(basename "\$NEW_FILES_LIST")" > "\$NEW_FILES_LIST" 2>/dev/null || true

while read -r line; do
    [ -e "\$line" ] || continue
    dirname=\$(dirname "\$line")
    basename=\$(basename "\$line")

    # 1. Shared Libraries: libfoo.so.1.2.3 -> remove libfoo.so.1.2.2
    if [[ "\$basename" =~ \.so\.[0-9]+ ]]; then
        # Extract major version prefix (e.g., libfoo.so.1)
        major_prefix=\$(echo "\$basename" | grep -oE '^.*\.so\.[0-9]+')
        if [ -n "\$major_prefix" ]; then
            # Look for other files starting with this prefix
            for candidate in "\$dirname"/"\$major_prefix"*; do
                [ -f "\$candidate" ] || continue
                # Skip current new file
                [ "\$candidate" == "\$line" ] && continue
                
                # Check timestamp: if older than build start, it's a candidate for deletion
                if ! [[ "\$candidate" -nt /tmp/build_start_timestamp ]]; then
                    echo "Removing old library version: \$candidate"
                    rm -f "\$candidate"
                fi
            done
        fi
    fi

    # 2. Versioned Directories
    if [ -d "\$line" ]; then
        # Pure version dirs: 1.2.3
        if [[ "\$basename" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
            for candidate in "\$dirname"/*; do
                [ -d "\$candidate" ] || continue
                [ "\$candidate" == "\$line" ] && continue
                cbase=\$(basename "\$candidate")
                if [[ "\$cbase" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                     if ! [[ "\$candidate" -nt /tmp/build_start_timestamp ]]; then
                          echo "Removing old version directory: \$candidate"
                          rm -rf "\$candidate"
                     fi
                fi
            done
        # Name+Version dirs: vim91
        elif [[ "\$basename" =~ ^[a-zA-Z]+[0-9]+(\.[0-9]+)*$ ]]; then
             # Extract alpha part
             prefix=\$(echo "\$basename" | sed -E 's/([a-zA-Z]+).*/\1/')
             for candidate in "\$dirname"/"\$prefix"*; do
                [ -d "\$candidate" ] || continue
                [ "\$candidate" == "\$line" ] && continue
                cbase=\$(basename "\$candidate")
                if [[ "\$cbase" =~ ^\$prefix[0-9]+(\.[0-9]+)*$ ]]; then
                     if ! [[ "\$candidate" -nt /tmp/build_start_timestamp ]]; then
                          echo "Removing old version directory: \$candidate"
                          rm -rf "\$candidate"
                     fi
                fi
             done
        fi
    fi

done < "\$NEW_FILES_LIST"
rm -f "\$NEW_FILES_LIST" /tmp/build_start_timestamp

echo "Build and installation complete for $PACKAGE"
cd /sources
rm -rf "$DIRNAME"
EOF
)

# Run with sudo to ensure permissions for /usr, /etc, etc.
ssh_lfs "sudo bash -c '$(echo "$REMOTE_SCRIPT" | sed "s/'/'\\\\''/g")'"

if [[ "$STRIP" == "true" ]]; then
    source "$NIXCFG/shell/user/21-lfs.sh"
    lfs_strip
fi
