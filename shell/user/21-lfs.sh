#!/usr/bin/env bash
# LFS/BLFS update management logic

LFS_DEV_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_SVN_BOOK="https://linuxfromscratch.org/blfs/view/svn"

lfs_autobuild() {
    "$NIXCFG/shell/user/lfs-autobuild.sh" "$@"
}

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
    
    ssh_lfs "find /sources/archives -type f 2>/dev/null" | \
        sed 's|.*/||; s/\.tar.*//; s/\.zip//; s/\.patch//' | \
        grep -vE "^$|-docs-html|-systemd" | \
        sort -u
}

lfs_strip() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    echo "Running binary stripping on LFS VM..."

    local strip_script=$(cat <<'EOF'
save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.34
             libitm.so.1.0.0
             libatomic.so.1.2.0"

cd /usr/lib

for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

online_usrbin="bash find strip"
online_usrlib="libbfd-2.45.1.so
               libsframe.so.2.0.0
               libhistory.so.8.3
               libncursesw.so.6.6
               libm.so.6
               libreadline.so.8.3
               libz.so.1.3.1
               libzstd.so.1.5.7
               $(cd /usr/lib; find libnss*.so* -type f)"

for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-debug /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
         $(find /usr/lib -type f -name \*.a)                 \
         $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename $i)* )
            ;;
        * ) strip --strip-debug $i
            ;;
    esac
done

unset BIN LIB save_usrlib online_usrbin online_usrlib
EOF
)

    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: Would execute the following stripping commands on VM:"
        echo "$strip_script"
    else
        ssh_lfs "sudo bash -c '$(echo "$strip_script" | sed "s/'/'\\\\''/g")'"
    fi
}

lfs_update_all() {
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

    # Run stripping commands once at the end if any packages were built
    if [[ "$dry_run" == "true" ]]; then
        lfs_strip --dry-run
    else
        lfs_strip
    fi
}
