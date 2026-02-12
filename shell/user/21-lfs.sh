#!/usr/bin/env bash
# LFS/BLFS update management logic

LFS_DEV_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_SVN_BOOK="https://linuxfromscratch.org/blfs/view/svn"

lfs_get_remote_packages() {
    # LFS packages are in links ending in .tar.* or .zip
    local lfs_remote=$(curl -s "$LFS_DEV_BOOK/chapter03/packages.html" | \
        grep -oP '[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+\.(tar\.[a-z2]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | \
        sort -u)

    # BLFS longindex has package-version in <a> tags or before " -- "
    local blfs_remote=$(curl -s "$BLFS_SVN_BOOK/longindex.html" | \
        grep -oP '(?<=>)[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+(?=</a>| -- )' | \
        sort -u)

    echo -e "${lfs_remote}\n${blfs_remote}" | sort -u
}

lfs_get_local_packages() {
    # Ensure dependencies are available
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    
    ssh_lfs "ls /sources/archives 2>/dev/null" | \
        sed 's/\.tar.*//; s/\.zip//; s/\.patch//' | \
        grep -vE "^$|-docs-html|-systemd" | \
        sort -u
}

lfs_updates_all() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    echo "Fetching remote package list from Development books..."
    local remote_list=$(lfs_get_remote_packages)
    echo "Fetching local package list from VM..."
    local local_list=$(lfs_get_local_packages)

    echo "Checking for updates..."
    local updates=()

    while read -r local_pkg; do
        [[ -z "$local_pkg" ]] && continue
        
        local name=$(echo "$local_pkg" | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
        local local_ver=$(echo "$local_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*)/\1/')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && continue

        # Find matching package in remote list (case-insensitive)
        local remote_pkg=$(echo "$remote_list" | grep -Ei "^${name}-([0-9])" | head -n 1)
        
        if [[ -n "$remote_pkg" ]]; then
            local remote_ver=$(echo "$remote_pkg" | sed -E "s/^.{${#name}}-//I")
            
            if [[ "$local_ver" != "$remote_ver" ]]; then
                local higher=$(echo -e "$local_ver\n$remote_ver" | sort -V | tail -n 1)
                if [[ "$higher" == "$remote_ver" ]]; then
                    echo "Found update: $name ($local_ver -> $remote_ver)"
                    updates+=("$name")
                fi
            fi
        fi
    done <<< "$local_list"

    if [[ ${#updates[@]} -eq 0 ]]; then
        echo "No updates found."
        return 0
    fi

    echo "Applying ${#updates[@]} updates..."
    for pkg in "${updates[@]}"; do
        if [[ "$dry_run" == "true" ]]; then
            echo "DRY RUN: $NIXCFG/shell/user/lfs-autobuild.sh --dry-run $pkg"
            "$NIXCFG/shell/user/lfs-autobuild.sh" --dry-run "$pkg"
        else
            echo "Building $pkg..."
            "$NIXCFG/shell/user/lfs-autobuild.sh" "$pkg"
        fi
    done
}
