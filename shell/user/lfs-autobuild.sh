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
PACKAGE=""

usage() {
    echo "Usage: $0 [options] <package-name>"
    echo "Options:"
    echo "  --dry-run    Show commands without executing them"
    echo "  --strip      Run stripping commands after build"
    echo "  -h, --help   Show this help message"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --strip) STRIP=true ;;
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

# Multi-line grep for commands using awk
log "Extracting build commands..."
COMMANDS=$(printf '%s' "$HTML_CONTENT" | awk '
    BEGIN { IGNORECASE=1 }
    /<pre [^>]*class="userinput"[^>]*>/ { in_block=1 }
    in_block { print }
    /<\/pre>/ { in_block=0 }
' | sed ':a;N;$!ba;s/<[^>]*>//g' | \
    sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | \
    sed 's/^[[:space:]]*//' | \
    grep -vE "^$|^exec " )

if [[ -z "$COMMANDS" ]]; then
    error "Could not extract build commands for '$PACKAGE'"
fi

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
    exit 0
fi

# 3. Remote Execution
FILENAME=$(basename "$DOWNLOAD_URL")
DIRNAME=$(echo "$FILENAME" | sed 's/\.tar.*//; s/\.zip//')

log "Starting remote build for $PACKAGE..."

# Prepare the build script to run on the guest
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

ssh_lfs "$REMOTE_SCRIPT"

if [[ "$STRIP" == "true" ]]; then
    # lfs_strip is defined in 21-lfs.sh which is sourced by main.sh
    # or should be sourced here if needed.
    # Since lfs-autobuild.sh is intended to be run in a shell where main.sh was sourced
    # or standalone, let's make sure it's available.
    source "$NIXCFG/shell/user/21-lfs.sh"
    lfs_strip
fi
