#!/usr/bin/env bash

lfs_autoremove_gpt() {
    local dry_run=false
    local force=false
    local pkg=""
    
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            dry_run=true
        elif [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
            force=true
        else
            pkg="$arg"
        fi
    done

    if [ -z "$pkg" ]; then
        echo "Usage: lfs_autoremove [--dry-run] [-f] <package_name>"
        return 1
    fi

    local inv_file=""
    if [ -f "/var/lib/custom-packages/$pkg" ]; then
        inv_file="/var/lib/custom-packages/$pkg"
    elif [ -f "/var/lib/book-packages/$pkg" ]; then
        inv_file="/var/lib/book-packages/$pkg"
    else
        echo "Package $pkg not found in inventory."
        return 1
    fi

    echo "Reading inventory for $pkg..."
    local inv_files=()
    local inv_dirs=()
    local inv_libs=()
    
    # Read inventory, skipping the first line (version)
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [ -d "$f" ]; then
            inv_dirs+=("$f")
        else
            inv_files+=("$f")
            if [[ "$f" =~ \.so(\.[0-9]+)*$ ]]; then
                inv_libs+=("$(basename "$f")")
            fi
        fi
    done < <(tail -n +2 "$inv_file")

    if [[ "$force" == "false" ]]; then
        if [ ${#inv_libs[@]} -gt 0 ]; then
            echo "Checking if other packages depend on libraries provided by $pkg..."
            
            local grep_pattern=""
            for lib in "${inv_libs[@]}"; do
                if [ -z "$grep_pattern" ]; then
                    grep_pattern="\[$lib\]"
                else
                    grep_pattern="$grep_pattern\|\[$lib\]"
                fi
            done
            
            local blocker_files=()
            local found_deps=0
            
            # Use find to list all binaries/libraries
            while IFS= read -r file; do
                # Quick skip if file is owned by the package
                if grep -qFx "$file" "$inv_file"; then
                    continue
                fi
                
                # Check dependencies
                if readelf -d "$file" 2>/dev/null | grep -q "(NEEDED)" && readelf -d "$file" 2>/dev/null | grep "(NEEDED)" | grep -q "\($grep_pattern\)"; then
                    blocker_files+=("$file")
                    found_deps=1
                fi
            done < <(find /usr/bin /usr/lib /lib /opt -type f \( -executable -o -name "*.so*" \) 2>/dev/null)
            
            if [ $found_deps -eq 1 ]; then
                echo "Cannot uninstall $pkg. The following files from other packages depend on it:"
                for b in "${blocker_files[@]}"; do
                    echo "  - $b"
                    local b_pkg=$(grep -rl "^$b$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | head -n1 | xargs basename 2>/dev/null)
                    if [ -n "$b_pkg" ]; then
                         echo "    (owned by package: $b_pkg)"
                    fi
                done
                return 1
            fi
        fi

        echo "Checking explicit dependencies in installed custom packages..."
        local blocker_pkgs=()
        for build_script in $(find ~/lfs_packaging -name "build.sh" 2>/dev/null); do
            local dep_line=$(grep -E '^depends=' "$build_script" | head -n 1)
            if [ -n "$dep_line" ]; then
                local deps_val=$(echo "$dep_line" | sed -E 's/^[a-zA-Z_]+=\(?//' | sed -E 's/\)$//')
                eval "local deps=($deps_val)"
                for d in "${deps[@]}"; do
                    if [ "$d" = "$pkg" ]; then
                        local dep_dir=$(basename $(dirname "$build_script"))
                        if [ -f "/var/lib/custom-packages/$dep_dir" ] || [ -f "/var/lib/book-packages/$dep_dir" ]; then
                            blocker_pkgs+=("$dep_dir")
                        fi
                    fi
                done
            fi
        done
        
        if [ ${#blocker_pkgs[@]} -gt 0 ]; then
            echo "Cannot uninstall $pkg. The following installed packages explicitly depend on it:"
            for bp in "${blocker_pkgs[@]}"; do
                echo "  - $bp"
            done
            return 1
        fi
    else
        echo "Force flag provided. Skipping dependency checks."
    fi

    if [[ "$dry_run" == "true" ]]; then
        if [[ "$force" == "true" ]]; then
            echo "[DRY RUN] Force flag active. The following files and directories would be uninstalled for $pkg:"
        else
            echo "[DRY RUN] Dependencies satisfied. The following files and directories would be uninstalled for $pkg:"
        fi
    else
        if [[ "$force" == "true" ]]; then
            echo "Force flag active. Uninstalling $pkg..."
        else
            echo "Dependencies satisfied. Uninstalling $pkg..."
        fi
    fi
    
    for f in "${inv_files[@]}"; do
        if [ -f "$f" ] || [ -L "$f" ]; then
            if [[ "$dry_run" == "true" ]]; then
                echo "Would delete file: $f"
            else
                sudo rm -f "$f"
            fi
        fi
    done

    # Sort directories descending (longest path first) to remove subdirectories before parents
    if [ ${#inv_dirs[@]} -gt 0 ]; then
        local sorted_dirs=($(printf "%s\n" "${inv_dirs[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-))
        for d in "${sorted_dirs[@]}"; do
            if [ -d "$d" ]; then
                local is_shared=false
                local providers=$(grep -rl "^$d$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null)
                for p in $providers; do
                    if [ "$p" != "$inv_file" ]; then
                        is_shared=true
                        break
                    fi
                done
                
                if [ "$is_shared" = false ]; then
                    if [[ "$dry_run" == "true" ]]; then
                        # Predict if directory will be empty
                        local remaining=$(find "$d" -mindepth 1 -maxdepth 1 2>/dev/null | grep -vFx -f "$inv_file")
                        if [ -z "$remaining" ]; then
                            echo "Would delete empty directory: $d"
                        else
                            echo "Notice: Would not delete $d as it will not be empty."
                        fi
                    else
                        if [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
                            sudo rmdir "$d" 2>/dev/null
                        else
                            echo "Notice: Not deleting $d as it is not empty."
                        fi
                    fi
                fi
            fi
        done
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "Would delete inventory file: $inv_file"
        echo "[DRY RUN] Uninstallation simulation of $pkg complete."
    else
        sudo rm -f "$inv_file"
        echo "Uninstallation of $pkg complete."
    fi
}

lfs_autoremove() {
    local args=("$@")
    if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
        source "$NIXCFG/shell/user/08-ssh.sh"
        source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
        ssh_lfs "$(declare -f lfs_autoremove_gpt); lfs_autoremove_gpt $(printf '%q ' "${args[@]}")"
    else
        lfs_autoremove_gpt "${args[@]}"
    fi
}

