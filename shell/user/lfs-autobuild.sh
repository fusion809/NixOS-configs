#!/usr/bin/env bash
# Automate LFS/BLFS package building by scraping official books (Development/SVN)

# Ensure NIXCFG is set
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source dependencies
source "$NIXCFG/shell/user/08-ssh.sh"
source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

LFS_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_BOOK="https://linuxfromscratch.org/blfs/view/svn"

DRY_RUN=false
STRIP=false
UPSTREAM=false
PACKAGE=""

usage() {
    echo "Usage: $0 [options] <package-name>"
    echo "Options:"
    echo "  --dry-run    Show commands without executing them"
    echo "  --strip      Run stripping commands after build"
    echo "  --upstream   Attempt to find the latest upstream version (linux and vim only)"
    echo "  -h, --help   Show this help message"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --strip) STRIP=true ;;
        --upstream) UPSTREAM=true ;;
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

    if [[ "$pkg" == "linux" ]]; then
        echo "$LFS_BOOK/chapter10/kernel.html"
        return 0
    fi

    log "Searching for '$pkg' in LFS book..." >&2
    # Search in LFS chapter 8 (development)
    local lfs_page=$(curl -s "$LFS_BOOK/chapter08/chapter08.html" | grep -iP "href=\"[a-z0-9_\-]*${pkg}[a-z0-9_\-]*\.html\"" | head -n 1 | grep -oP '(?<=href=")[^"]+')
    
    if [[ -n "$lfs_page" ]]; then
        echo "$LFS_BOOK/chapter08/$lfs_page"
        return 0
    fi

    log "Searching for '$pkg' in BLFS index..." >&2
    # Search in BLFS long index
    local blfs_page=$(curl -s "$BLFS_BOOK/longindex.html" | grep -iP "href=\"[^\"]*${pkg}[^\"]*\.html\"" | head -n 1 | grep -oP '(?<=href=")[^"]+')
    
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
        /<pre [^>]*class="userinput"[^>]*>/ { in_block=1; print "___BLOCK_START___" }
        in_block { print }
        /<\/pre>/ { in_block=0; print "___BLOCK_END___" }
    ' | perl -0777 -pe 's/<[^>]+>//gs' | \
        sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | \
        sed 's/^[[:space:]]*//' | \
        grep -vE "^$|^exec "
}

log "Extracting build commands..."
RAW_CONTENT=$(get_commands "$HTML_CONTENT")

# Process blocks: Parallel make and Test filtering
CRITICAL_PKGS="gcc binutils glibc"
is_critical=false

# 1. Hardcoded critical packages
for c in $CRITICAL_PKGS; do
    if [[ "$PACKAGE" == "$c" || "$PACKAGE" == "$c-"* ]]; then
        is_critical=true
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

        # 2. Determine if this block is a test suite or related setup
        # keywords: make/ninja tests, expect scripts, tester user, su to tester, testdir
        if [[ "$CURRENT_BLOCK" =~ (make[[:space:]]+(check|test|tests)|ninja[[:space:]]+test|spawn[[:space:]]+make|expect|tester|su[[:space:]]+.*tester|testdir) ]]; then
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
        else
            # Not a test block, process for parallel make
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
    HEADER_CMDS=$(get_commands "$HEADER_HTML" | sed 's/\$LFS//g')
    COMMANDS="${HEADER_CMDS}
${COMMANDS}"
fi

if [[ -z "$COMMANDS" ]]; then
    error "Could not extract build commands for '$PACKAGE'"
fi

# 3. Resolve Download URL
if [[ "$UPSTREAM" == "true" ]]; then
    if [[ "$PACKAGE" == "linux" ]]; then
        log "Fetching latest mainline Linux kernel version..."
        KERNEL_VER=$(curl -s https://www.kernel.org/ | grep -A 1 "mainline:" | grep -oP '[0-9.]+' | head -n 1)
        if [[ -n "$KERNEL_VER" ]]; then
            MAJOR=$(echo "$KERNEL_VER" | cut -d. -f1)
            DOWNLOAD_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KERNEL_VER}.tar.xz"
        fi
    elif [[ "$PACKAGE" == "vim" ]]; then
        log "Fetching latest upstream Vim version from GitHub..."
        # Robust method for Vim tags from tags page
        VIM_TAG=$(curl -sL https://github.com/vim/vim/tags | grep -oP 'href="/vim/vim/releases/tag/v\K[0-9.]+' | head -n 1)
        if [[ -z "$VIM_TAG" ]]; then
             VIM_TAG=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | grep -oP '(?<="tag_name": "v)[0-9.]+' | head -n 1)
        fi
        
        if [[ -n "$VIM_TAG" ]]; then
            DOWNLOAD_URL="https://github.com/vim/vim/archive/v${VIM_TAG}/vim-${VIM_TAG}.tar.gz"
        fi
    else
        log "Upstream flag ignored for package '$PACKAGE' (only supported for linux and vim)"
    fi
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    # Strip trailing digits from package name for more flexible search (e.g., python3 -> python)
    PKG_BASE=$(echo "$PACKAGE" | sed 's/[0-9]*$//')
    log "Package base name for search: $PKG_BASE"

    # LFS packages have URLs in Chapter 3
    if [[ "$PAGE_URL" == *"/lfs/"* ]]; then
        log "Fetching download URL from LFS Chapter 3..."
        DOWNLOAD_URL=$(curl -s "$LFS_BOOK/chapter03/packages.html" | grep -ioP "https?://[^\s\"]*${PKG_BASE}[^\s\"]*\.tar\.[a-z2]+" | head -n 1)
    else
        # BLFS packages usually have it on the page
        log "Searching for download URL on BLFS page..."
        DOWNLOAD_URL=$(printf '%s' "$HTML_CONTENT" | grep -ioP "https?://[^\s\"]*\.tar\.[a-z2]+" | grep -i "${PKG_BASE}" | grep -vE "(-docs|-html)" | head -n 1)
    fi

    if [[ -z "$DOWNLOAD_URL" ]]; then
        log "Falling back to broader URL search..."
        DOWNLOAD_URL=$(printf '%s' "$HTML_CONTENT" | grep -ioP "https?://[^\s\"]*[^\s\"]*\.tar\.[a-z2]+" | grep -i "${PKG_BASE}" | head -n 1)
    fi
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    error "Could not find download URL for '$PACKAGE'"
fi

log "Extracted download URL: $DOWNLOAD_URL"

if [[ "$DRY_RUN" == "true" ]]; then
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
FILENAME=$(basename "$DOWNLOAD_URL")
DIRNAME=$(echo "$FILENAME" | sed 's/\.tar.*//; s/\.zip//')

log "Starting remote build for $PACKAGE..."

# Prepare the build script to run on the guest
# Note: Root execution is handled by running the entire script via sudo
REMOTE_SCRIPT=$(cat <<EOF
set -e
mkdir -p /sources/archives
cd /sources/archives

if [ ! -f "$FILENAME" ]; then
    echo "Downloading $FILENAME..."
    wget "$DOWNLOAD_URL"
fi

echo "Extracting $FILENAME..."
rm -rf "/sources/$DIRNAME"
mkdir -p "/sources/$DIRNAME"
tar -xf "$FILENAME" -C "/sources/$DIRNAME" --strip-components=1

cd "/sources/$DIRNAME"

echo "Running build commands..."
$COMMANDS

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
