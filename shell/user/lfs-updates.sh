#!/usr/bin/env bash
# Fetch latest versions from LFS/BLFS master books
# and compare with locally installed packages in /sources/archives

# Ensure NIXCFG is set for sourced scripts
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

get_lfs_packages() {
    # LFS packages are in links ending in .tar.* or .zip
    curl -s https://www.linuxfromscratch.org/lfs/view/systemd/chapter03/packages.html | \
        grep -oP '[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+\.(tar\.[a-z2]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | \
        sort -u
}

get_blfs_packages() {
    # BLFS longindex has package-version in <a> tags or before " -- "
    curl -s https://linuxfromscratch.org/blfs/view/systemd/longindex.html | \
        grep -oP '(?<=>)[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+(?=</a>| -- )' | \
        sort -u
}

get_local_packages() {
    # Access LFS VM via SSH and list /sources/archives
    # Source the necessary scripts to have ssh_lfs available
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/08-ssh.sh"
    source "$script_dir/18-vms.sh" >/dev/null 2>&1
    
    ssh_lfs "ls /sources/archives 2>/dev/null" | \
        sed 's/\.tar.*//; s/\.zip//; s/\.patch//' | \
        grep -vE "^$|-docs-html|-systemd" | \
        sort -u
}

compare_versions() {
    local remote_list="$1"
    local local_list="$2"
    
    echo "Checking for updates..."
    echo "--------------------------------------------------------------------------------"
    printf "%-30s | %-15s | %-15s\n" "Package" "Local" "Remote"
    echo "--------------------------------------------------------------------------------"

    while read -r local_pkg; do
        [[ -z "$local_pkg" ]] && continue
        
        # Extract base name and version
        # Look for the last dash followed by a digit
        local name=$(echo "$local_pkg" | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
        local local_ver=$(echo "$local_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*)/\1/')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && continue

        # Find matching package in remote list (case-insensitive)
        local remote_pkg=$(echo "$remote_list" | grep -Ei "^${name}-([0-9])" | head -n 1)
        
        if [ -n "$remote_pkg" ]; then
            # Extract version from remote package name
            # We use the length of the name to be safe
            local remote_ver=$(echo "$remote_pkg" | sed -E "s/^.{${#name}}-//I")
            
            if [ "$local_ver" != "$remote_ver" ]; then
                local higher=$(echo -e "$local_ver\n$remote_ver" | sort -V | tail -n 1)
                if [ "$higher" == "$remote_ver" ]; then
                    printf "%-30s | %-15s | %-15s [UPDATE]\n" "$name" "$local_ver" "$remote_ver"
                fi
            fi
        fi
    done <<< "$local_list"
}

# Main
LFS_REMOTE=$(get_lfs_packages)
BLFS_REMOTE=$(get_blfs_packages)
ALL_REMOTE=$(echo -e "${LFS_REMOTE}\n${BLFS_REMOTE}" | sort -u)

LOCAL_PKGS=$(get_local_packages)

compare_versions "$ALL_REMOTE" "$LOCAL_PKGS"
