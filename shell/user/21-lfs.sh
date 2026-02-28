#!/usr/bin/env bash
# LFS/BLFS update management logic

LFS_DEV_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_SVN_BOOK="https://linuxfromscratch.org/blfs/view/systemd"

lfs_autobuild() {
    "$NIXCFG/shell/user/lfs-autobuild.sh" "$@"
}

lfs_get_remote_packages() {
    KERNEL_VER=$(curl -s https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | grep -oP '[0-9.]+' | sort -Vr | head -n 1)
    VIM_VER=$(curl -sL https://github.com/vim/vim/tags | grep -oP 'href="/vim/vim/releases/tag/v\K[0-9.]+' | head -n 1)
    if [[ -z "$VIM_VER" ]]; then
        VIM_VER=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | grep -oP '(?<="tag_name": "v)[0-9.]+' | head -n 1)
    fi
    # LFS packages are in links ending in .tar.* or .zip
    local lfs_remote=$(curl -s "$LFS_DEV_BOOK/chapter03/packages.html" | tr -d '\r' | \
        grep -oP '[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+\.(tar\.[a-z2]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | \
        sed "s|^linux-[0-9.]*$|linux-${KERNEL_VER}|g" | \
        sed "s|^[Vv]im-[0-9.]*$|vim-${VIM_VER}|g" | \
        sort -u)

    # BLFS longindex has package-version in <a> tags or before " -- "
    local blfs_remote=$(curl -s "$BLFS_SVN_BOOK/longindex.html" | tr -d '\r' | \
        perl -0777 -ne 'while (/SpiderMonkey:.*?firefox-([0-9.]+)/gs) { print "spidermonkey-$1\n" } while (/>([a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+)<\/a>/gs) { print "$1\n" }' | \
        sed "/[Vv]im-[0-9.]*$/d" | \
        sort -u)
    echo -e "${lfs_remote}\n${blfs_remote}" | sort -u | tr -d '\r'
}

lfs_get_local_packages() {
    # Ensure dependencies are available
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    
    ssh_lfs "find /sources/archives -type f ! -name '*.patch*' 2>/dev/null | tr -d '\r'" | \
        sed 's|.*/||; s/\.tar\.[a-z2]\+//; s/\.zip$//; s/\.patch\.[a-z2]\+//; s/\.[a-z2]\+$//; s/-apng$//' | \
        sed 's/^firefox-\([0-9].*esr\.source\)/spidermonkey-\1/' | \
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

lfs_check_custom_updates() {
    # Ensure dependencies are available
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    local script=$(cat <<'EOF'
    sudo mkdir -p /var/lib/lfs-custom-packages 2>/dev/null || true
    for build_script in $(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null); do
        pkg_dir=$(dirname "$build_script")
        pkg_name=$(basename "$pkg_dir")
        
        # 1. Get local version
        local_ver="none"
        if [ -f "/var/lib/lfs-custom-packages/$pkg_name" ]; then
            local_ver=$(cat "/var/lib/lfs-custom-packages/$pkg_name" 2>/dev/null || echo "none")
        fi
        
        # 2. Get remote version
        remote_ver=""
        # Try to extract VERSION= line and evaluate it
        version_line=$(grep -E '^[A-Z_]*VERSION=' "$build_script" | head -n 1)
        if [ -n "$version_line" ]; then
            var_name=$(echo "$version_line" | cut -d= -f1)
            echo "$version_line" > /tmp/eval_ver.sh
            echo "echo \$$var_name" >> /tmp/eval_ver.sh
            remote_ver=$(bash /tmp/eval_ver.sh 2>/dev/null | tail -n 1)
            rm -f /tmp/eval_ver.sh
        fi
        
        # If no VERSION line, try to determine git remote head
        if [ -z "$remote_ver" ] && grep -q "git clone" "$build_script"; then
            repo_url=$(grep -oP 'git clone \K[^ ]+' "$build_script" | head -n 1)
            if [ -n "$repo_url" ]; then
                remote_ver=$(git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}')
            fi
        fi
        
        if [ -n "$remote_ver" ]; then
            if [ "$local_ver" != "$remote_ver" ]; then
                # Assume it's an update if they don't match exactly
                echo "$pkg_name $local_ver $remote_ver"
            fi
        fi
    done
EOF
)
    ssh_lfs "bash -c '$(echo "$script" | sed "s/'/'\\\\''/g")'" 2>/dev/null | grep -vE "^(Warning:|Connection|IP|SSH|grep:)"
}

lfs_update_all() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    echo "Updating Python packages via pip..."
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: sudo pip3 install --upgrade pyparsing attrs numpy sphinx pyqt-builder pyopengl sip pyqt6-sip"
    else
        ssh_lfs "sudo pip3 install --upgrade pyparsing attrs numpy sphinx pyqt-builder pyopengl sip pyqt6-sip"
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

    # Also check custom updates
    local custom_updates=$(lfs_check_custom_updates)
    while read -r update_line; do
        [[ -z "$update_line" ]] && continue
        local name=$(echo "$update_line" | awk '{print $1}')
        local local_ver=$(echo "$update_line" | awk '{print $2}')
        local remote_ver=$(echo "$update_line" | awk '{print $3}')
        echo "Found custom update: $name ($local_ver -> $remote_ver)"
        updates+=("$name")
    done <<< "$custom_updates"

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
