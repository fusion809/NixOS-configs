#!/usr/bin/env bash

# Shared dependency cache paths
LFS_DEP_CACHE="/tmp/lfs_dep_cache.txt"
LFS_DEP_CACHE_LOCK="/tmp/lfs_dep_cache.lock"
LFS_DEP_CACHE_DIRS="/usr/bin /usr/lib /lib /opt"

# Ensure the shared dependency cache is up-to-date.
# - If the cache is being built by another process, waits for it to finish.
# - Rebuilds only when a file in the searched dirs is newer than the cache.
lfs_ensure_dep_cache() {
    # Wait for any concurrent build to finish (up to 5 minutes)
    (
        flock -w 300 9 || { echo "Timed out waiting for dep cache lock."; return 1; }

        # Check staleness: rebuild if cache missing or any searched file is newer
        local needs_rebuild=false
        if [[ ! -s "$LFS_DEP_CACHE" ]]; then
            needs_rebuild=true
        else
            # shellcheck disable=SC2086
            if find $LFS_DEP_CACHE_DIRS -newer "$LFS_DEP_CACHE" -type f \( -executable -o -name "*.so*" \) 2>/dev/null | grep -q .; then
                needs_rebuild=true
            fi
        fi

        if [[ "$needs_rebuild" == "true" ]]; then
            echo "Building dependency cache (searching $LFS_DEP_CACHE_DIRS)..."
            local tmp_cache="${LFS_DEP_CACHE}.tmp.$$"
            # shellcheck disable=SC2086
            find $LFS_DEP_CACHE_DIRS -type f \( -executable -o -name "*.so*" \) 2>/dev/null | \
                xargs -P"$(nproc)" -I{} sh -c \
                    "readelf -d '{}' 2>/dev/null | grep -q '(NEEDED)' && \
                     deps=\$(readelf -d '{}' 2>/dev/null | grep '(NEEDED)' | sed -E 's/.*\[(.*)\].*/\1/' | tr '\n' ' ') && \
                     echo \"{}: \$deps\"" > "$tmp_cache"
            mv -f "$tmp_cache" "$LFS_DEP_CACHE"
            echo "Dependency cache built."
        else
            echo "Dependency cache is up-to-date."
        fi
    ) 9>"$LFS_DEP_CACHE_LOCK"
}

rm_old_libs_gpt() {
    local dep_cache="/tmp/lfs_dep_cache.txt"
    local pkg_cache="/tmp/lfs_pkg_cache.txt"
    
    echo "[LFS-AUTOBUILD] Generating dependency and package caches. This ensures accurate and fast cleanup..."
    
    # 1. Generate system-wide dependency cache (shared, with locking and staleness check)
    lfs_ensure_dep_cache
    local dep_cache="$LFS_DEP_CACHE"
    
    # 2. Generate package inventory mapping (File -> Package)
    # This maps every installed file back to the package that registered it in /var/lib/*-packages/
    grep -r "^/" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | sed -E 's|/var/lib/[^/]+-packages/([^:]+):(.*)|\2:\1|' > "$pkg_cache"

    echo "[LFS-AUTOBUILD] Caches generated. Evaluating system libraries..."

    # 3. Identify old versions (files only)
    # A version is old if a newer version with the same base name exists.
    local old_libs=($(find /usr/lib -type f \( -name "lib*.so.[0-9]*" -o -name "lib*-[0-9]*.so" \) ! -name "*.dbg" ! -name "*-gdb.py" 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        # Check if the file is an actual versioned shared library
        if (base ~ /\.so\.[0-9]+(\.[0-9]+)*$/) {
            orig = base
            sub(/\.so\.[0-9.]+$/, ".so", base)
            if (prev_base && base != prev_base) {
                for (i=1; i < prev_count; i++) print prev[i]
                prev_count = 0
            }
            prev[++prev_count] = orig
            prev_base = base
        } else if (base ~ /-[0-9]+(\.[0-9]+)*\.so$/) {
            orig = base
            sub(/-[0-9.]+/, "", base)
            if (prev_base && base != prev_base) {
                for (i=1; i < prev_count; i++) print prev[i]
                prev_count = 0
            }
            prev[++prev_count] = orig
            prev_base = base
        }
    }
    END {
        for (i=1; i < prev_count; i++) print prev[i]
    }'))

    # 3b. Identify old versions (directories only)
    local old_dirs=($(find /usr/lib -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        sub(/-[0-9]+(\.[0-9]+)*$/, "", base)
        if (base != $0) {
            if (prev_base && base == prev_base) {
                for (i=1; i <= prev_count; i++) print prev[i]
                prev_count = 0
            } else {
                prev_count = 0
            }
            prev[++prev_count] = $0
            prev_base = base
        }
    }'))

    # Filter out directories that are listed in the package registry:
    # e.g. /usr/lib/gtk-3.0 belongs to gtk3, not an obsolete version of gtk-4.0.
    local filtered_dirs=()
    for _dir in "${old_dirs[@]}"; do
        if grep -qrl "^${_dir}" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null; then
            echo "Skipping registered directory: $_dir (belongs to an installed package)"
        else
            filtered_dirs+=("$_dir")
        fi
    done
    old_dirs=("${filtered_dirs[@]}")

    local old_items=("${old_libs[@]}" "${old_dirs[@]}")

    if [ ${#old_items[@]} -eq 0 ]; then
        echo "No old library versions found to clean up."
        rm -f "$dep_cache" "$pkg_cache"
        return
    fi

    # Track packages already rebuilt this session to avoid rebuilding the same
    # package dozens of times (e.g. once per old boost .so variant)
    declare -A rebuilt_packages=()

    for i in "${old_items[@]}"; do
        [ -e "$i" ] || continue
        echo "------------------------------------------------"
        
        local all_names=()
        if [ -d "$i" ]; then
            echo "Checking obsolete version (directory): $(basename "$i")"
            echo "Path: $i"
            local dir_basename=$(basename "$i")
            all_names=($(find "$i" -name "*.so*" -printf "%f\n" 2>/dev/null | sort -u))
            local outside_libs=($(find /usr/lib /lib -maxdepth 1 -name "lib${dir_basename}*.so*" -printf "%f\n" 2>/dev/null))
            all_names+=("${outside_libs[@]}")
        else
            echo "Checking obsolete version (file): $(basename "$i")"
            echo "Path: $i"
            local lib_basename=$(basename "$i")
            local i_dir=$(dirname "$i")
            local link_names=($(find "$i_dir" /usr/lib /lib -maxdepth 1 -type l -printf "%p %l\n" 2>/dev/null | grep -w "$lib_basename$" | awk '{print $1}'))
            all_names=("$lib_basename")
            for link in "${link_names[@]}"; do
                all_names+=($(basename "$link"))
            done
        fi
        
        # Ensure unique all_names and avoid empty checks
        all_names=($(printf "%s\n" "${all_names[@]}" | sort -u | grep -v "^$"))
        
        # Guard against matching linker scripts or raw symlinks like libc.so and libm.so
        local safe_names=()
        for name in "${all_names[@]}"; do
            if [[ "$name" =~ \.so\.[0-9]+ ]] || [[ "$name" =~ -[0-9]+\.so$ ]]; then
                safe_names+=("$name")
            else
                echo "Skipping generic/unsafe name '$name' to prevent false positive matches."
            fi
        done
        all_names=("${safe_names[@]}")

        # 4. FAST dependency check for ANY of these names in the cache
        local deps=()
        if [ ${#all_names[@]} -gt 0 ]; then
            for name in "${all_names[@]}"; do
                # The cache format is "FILE: lib1 lib2 lib3 "
                local matches=($(grep " $name " "$dep_cache" | cut -d: -f1))
                [ ${#matches[@]} -gt 0 ] && deps+=("${matches[@]}")
            done
        fi
        # Unique list
        deps=($(printf "%s\n" "${deps[@]}" | sort -u))

        # Filter out deps that are inside the old directory itself
        if [ -d "$i" ] && [ ${#deps[@]} -gt 0 ]; then
            local outside_deps=()
            for d in "${deps[@]}"; do
                if [[ "$d" != "$i/"* ]]; then
                    outside_deps+=("$d")
                fi
            done
            deps=("${outside_deps[@]}")
        fi

        # Filter out deps that are also old libraries slated for deletion
        if [ ${#deps[@]} -gt 0 ]; then
            local valid_deps=()
            for d in "${deps[@]}"; do
                local is_old=false
                for old_item in "${old_items[@]}"; do
                    if [ "$d" = "$old_item" ] || [[ "$d" == "$old_item/"* ]]; then
                        is_old=true
                        break
                    fi
                done
                if [ "$is_old" = "false" ]; then
                    valid_deps+=("$d")
                fi
            done
            deps=("${valid_deps[@]}")
        fi

        if [ ${#deps[@]} -eq 0 ]; then
            if [ -d "$i" ]; then
                echo "Result: Unused. Deleting directory $i..."
                sudo rm -rf -- "$i"
            else
                if [ ${#all_names[@]} -gt 1 ]; then
                    echo "Result: Unused (including symlinks: ${all_names[@]:1}). Deleting $i and its symlinks..."
                    for name in "${all_names[@]:1}"; do
                       sudo rm -f "/usr/lib/$name" "/lib/$name" 2>/dev/null
                    done
                else
                    echo "Result: Unused. Deleting $i..."
                fi
                sudo rm -f -- "$i"
            fi
            continue
        fi

        echo "Status: Library (or its symlinks) has ${#deps[@]} remaining dependents."
        echo "Names tracked: ${all_names[@]}"
        echo "Example dependents: ${deps[@]:0:3} ..."
        
        # 5. Robust package identification using the inventory cache
        local found_pkgs=()
        for d in "${deps[@]}"; do
            local p=$(grep "^$d:" "$pkg_cache" | cut -d: -f2)
            [ -n "$p" ] && found_pkgs+=("$p")
        done
        
        # Get unique package names
        local pkgs=($(printf "%s\n" "${found_pkgs[@]}" | sort -u))
        
        if [ ${#pkgs[@]} -eq 0 ]; then
            echo "Warning: No parent package found for ANY of the ${#deps[@]} dependents."
            echo "These dependents are likely orphaned files from a previous version (e.g., protobuf binaries)."
            echo "Orphaned files preventing deletion of $i:"
            for d in "${deps[@]}"; do
                echo "  - $d"
            done
            echo "Please manually delete these orphaned files if they are no longer needed."
            echo "Safety Hold: Keeping $i."
            continue
        fi

        echo "Identified parent packages to rebuild: ${pkgs[@]}"
        
        local rebuild_success=true
        for pkg in "${pkgs[@]}"; do
            if [[ -n "${rebuilt_packages[$pkg]+x}" ]]; then
                echo "Skipping rebuild of '$pkg' (already rebuilt in this session)."
                continue
            fi
            echo "Action: Rebuilding $pkg to switch to newer library..."
            if lfs_autobuild --force "$pkg"; then
                rebuilt_packages[$pkg]=1
            else
                local item_name=$(basename "$i")
                echo "Error: Failed to rebuild $pkg. Cannot delete $item_name."
                rebuild_success=false
                break
            fi
        done

        if [ "$rebuild_success" = true ]; then
             echo "Verification: Re-checking dependencies for $(IFS=, ; echo "${all_names[*]}") after rebuilds..."
             local remaining=0
             local remaining_outsiders=()
             # Re-scan binaries from DISK (not stale cache) to get up-to-date ELF info.
             for d in "${deps[@]}"; do
                 [ -f "$d" ] || continue
                 for name in "${all_names[@]}"; do
                     if readelf -d "$d" 2>/dev/null | grep -q "\[$name\]"; then
                         # Check whether the binary belongs to a package we just rebuilt.
                         # If it does, the dependency is legitimate (the rebuilt package
                         # still needs this library, e.g. OpenSSL 4 ships libcrypto.so.3).
                         local owner=$(grep -rl "^$d$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | head -n1 | xargs basename 2>/dev/null)
                         if [ -n "$owner" ] && [[ -n "${rebuilt_packages[$owner]+x}" ]]; then
                             echo "Note: $d still depends on $name but '$owner' was just rebuilt — dependency is current."
                         else
                             echo "Persistence: $d still depends on $name"
                             remaining=1
                             remaining_outsiders+=("$d")
                         fi
                         break
                     fi
                 done
             done
             
             if [ $remaining -eq 0 ]; then
                 if [ -d "$i" ]; then
                     echo "Final Action: All dependencies cleared. Deleting directory $i."
                     sudo rm -rf -- "$i"
                 else
                     # Safety check: before deleting the old versioned .so, confirm
                     # that at least one other real file (not a broken symlink) matching
                     # the same base soname exists — i.e. the owner actually installed a
                     # replacement. Without this, a failed owning-package rebuild would
                     # leave the system with NO copy of the library at all.
                     local i_dir i_base i_sobase replacement_found
                     i_dir=$(dirname "$i")
                     i_base=$(basename "$i")
                     # Strip everything from .so onwards or after '-' to get base (e.g. libMagickCore-7.Q16HDRI or libsystemd-core)
                     i_sobase=$(echo "$i_base" | sed -E 's/-[0-9.]+\.so/.so/; s/\.so\.[0-9.]+$/.so/')
                     replacement_found=false
                     # Search for candidates matching the base name (without .so suffix for broader matching)
                     local search_base="${i_sobase%%.so}"
                     for candidate in "$i_dir"/${search_base}*; do
                         if [[ "$candidate" != "$i" ]] && [ -e "$candidate" ]; then
                             replacement_found=true
                             break
                         fi
                     done
                     if [ "$replacement_found" = false ]; then
                         echo "Safety Hold: No replacement for $i_base found in $i_dir."
                         echo "             Skipping deletion — the owning package may not have reinstalled cleanly."
                         echo "             Run: autobuild -f <owning-package> to fix this manually."
                         continue
                     fi
                     echo "Final Action: All dependencies cleared. Deleting $i and its symlinks."
                     for name in "${all_names[@]:1}"; do
                        sudo rm -f "/usr/lib/$name" "/lib/$name" 2>/dev/null
                     done
                     sudo rm -f -- "$i"
                 fi
             else
                 local blocker_pkgs=()
                 for d in "${remaining_outsiders[@]}"; do
                     local p=$(grep -rl "^$d$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | head -n1 | xargs basename 2>/dev/null)
                     [ -n "$p" ] && blocker_pkgs+=("$p")
                 done
                 blocker_pkgs=($(printf "%s\n" "${blocker_pkgs[@]}" | sort -u))
                 echo "Final Action: Keeping $i (non-rebuilt binaries still linked: ${blocker_pkgs[*]:-unknown})."
             fi
        else
            echo "Final Action: Keeping $i (rebuilds incomplete or blocked)."
        fi
    done
    
    rm -f "$pkg_cache"
    # Note: dep_cache ($LFS_DEP_CACHE) is shared and not removed here;
    # it will be reused or invalidated by staleness checks on the next run.
}

rm_old_libs() {
    ssh_lfs "source ~/.zshrc ; rm_old_libs_gpt"
}

ls_old_libs_gpt() {
    local show_deps=false
    if [[ "$1" == "-d" ]]; then
        show_deps=true
    fi

    echo "Scanning for old libraries in /usr/lib..."

    local old_libs=($(find /usr/lib -type f \( -name "lib*.so.[0-9]*" -o -name "lib*-[0-9]*.so" \) ! -name "*.dbg" ! -name "*-gdb.py" 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        if (base ~ /\.so\.[0-9]+(\.[0-9]+)*$/) {
            orig = base
            sub(/\.so\.[0-9.]+$/, ".so", base)
            if (prev_base && base != prev_base) {
                for (i=1; i < prev_count; i++) print prev[i]
                prev_count = 0
            }
            prev[++prev_count] = orig
            prev_base = base
        } else if (base ~ /-[0-9]+(\.[0-9]+)*\.so$/) {
            orig = base
            sub(/-[0-9.]+/, "", base)
            if (prev_base && base != prev_base) {
                for (i=1; i < prev_count; i++) print prev[i]
                prev_count = 0
            }
            prev[++prev_count] = orig
            prev_base = base
        }
    }
    END {
        for (i=1; i < prev_count; i++) print prev[i]
    }'))

    local old_dirs=($(find /usr/lib -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        sub(/-[0-9]+(\.[0-9]+)*$/, "", base)
        if (base != $0) {
            if (prev_base && base == prev_base) {
                for (i=1; i <= prev_count; i++) print prev[i]
                prev_count = 0
            } else {
                prev_count = 0
            }
            prev[++prev_count] = $0
            prev_base = base
        }
    }'))

    # Filter out directories that are listed in the package registry:
    # a directory like /usr/lib/gtk-3.0 belongs to gtk3, not an obsolete version.
    local filtered_dirs=()
    for _dir in "${old_dirs[@]}"; do
        if grep -qrl "^${_dir}" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null; then
            : # registered — belongs to an installed package, skip
        else
            filtered_dirs+=("$_dir")
        fi
    done
    old_dirs=("${filtered_dirs[@]}")

    local old_items=("${old_libs[@]}" "${old_dirs[@]}")

    if [ ${#old_items[@]} -eq 0 ]; then
        echo "No old library versions found."
        return 0
    fi

    if [[ "$show_deps" == "true" ]]; then
        echo "Building/reusing shared dependency cache..."
        lfs_ensure_dep_cache
    fi
    local dep_cache="$LFS_DEP_CACHE"

    echo "--- Old Libraries ---"
    for i in "${old_items[@]}"; do
        [ -e "$i" ] || continue
        echo "- $i"
        
        if [[ "$show_deps" == "true" ]]; then
            local all_names=()
            if [ -d "$i" ]; then
                local dir_basename=$(basename "$i")
                all_names=($(find "$i" -name "*.so*" -printf "%f\n" 2>/dev/null | sort -u))
                local outside_libs=($(find /usr/lib /lib -maxdepth 1 -name "lib${dir_basename}*.so*" -printf "%f\n" 2>/dev/null))
                all_names+=("${outside_libs[@]}")
            else
                local lib_basename=$(basename "$i")
                local i_dir=$(dirname "$i")
                local link_names=($(find "$i_dir" /usr/lib /lib -maxdepth 1 -type l -printf "%p %l\n" 2>/dev/null | grep -w "$lib_basename$" | awk '{print $1}'))
                all_names=("$lib_basename")
                for link in "${link_names[@]}"; do
                    all_names+=($(basename "$link"))
                done
            fi
            
            all_names=($(printf "%s\n" "${all_names[@]}" | sort -u | grep -v "^$"))
            
            local safe_names=()
            for name in "${all_names[@]}"; do
                if [[ "$name" =~ \.so\.[0-9]+ ]] || [[ "$name" =~ -[0-9]+\.so$ ]]; then
                    safe_names+=("$name")
                fi
            done
            all_names=("${safe_names[@]}")

            local deps=()
            if [ ${#all_names[@]} -gt 0 ]; then
                for name in "${all_names[@]}"; do
                    local matches=($(grep " $name " "$dep_cache" | cut -d: -f1))
                    [ ${#matches[@]} -gt 0 ] && deps+=("${matches[@]}")
                done
            fi
            deps=($(printf "%s\n" "${deps[@]}" | sort -u))

            if [ -d "$i" ] && [ ${#deps[@]} -gt 0 ]; then
                local outside_deps=()
                for d in "${deps[@]}"; do
                    if [[ "$d" != "$i/"* ]]; then
                        outside_deps+=("$d")
                    fi
                done
                deps=("${outside_deps[@]}")
            fi

            if [ ${#deps[@]} -gt 0 ]; then
                local valid_deps=()
                for d in "${deps[@]}"; do
                    local is_old=false
                    for old_item in "${old_items[@]}"; do
                        if [ "$d" = "$old_item" ] || [[ "$d" == "$old_item/"* ]]; then
                            is_old=true
                            break
                        fi
                    done
                    if [ "$is_old" = "false" ]; then
                        valid_deps+=("$d")
                    fi
                done
                deps=("${valid_deps[@]}")
            fi

            if [ ${#deps[@]} -gt 0 ]; then
                echo "  ↳ Dependents:"
                for d in "${deps[@]}"; do
                    echo "    - $d"
                done
            else
                echo "  ↳ No dependents found."
            fi
        fi
    done

    # Note: dep_cache ($LFS_DEP_CACHE) is shared and not removed here.
}

ls_old_libs() {
    ssh_lfs "$(declare -f ls_old_libs_gpt); ls_old_libs_gpt $*"
}

ls_orphaned_files_gpt() {
    echo "Gathering list of all system files..."
    local sys_files="/tmp/sys_files.txt"
    find /bin /sbin /lib /lib64 /usr /etc /opt -type f -o -type l 2>/dev/null | sort -u > "$sys_files"

    echo "Gathering list of all tracked files..."
    local tracked_files="/tmp/tracked_files.txt"
    cat /var/lib/book-packages/* /var/lib/custom-packages/* 2>/dev/null | awk 'FNR>1 {print $0}' | sort -u > "$tracked_files"

    echo "Calculating orphaned files..."
    local orphaned_files="/tmp/orphaned_files.txt"
    comm -23 "$sys_files" "$tracked_files" | \
        grep -v "/site-packages/" | \
        grep -v "/__pycache__/" | \
        grep -v "/usr/share/info/dir" | \
        grep -v "/etc/ld.so.cache" | \
        grep -vE '^/etc/(passwd|group|shadow|gshadow|fstab|resolv\.conf|-|localtime|hostname|hosts)' | \
        grep -vE '^/usr/share/fonts/.*/fonts\.(dir|scale)' | \
        grep -vE '^/usr/lib/modules/' | \
        grep -vE '^/usr/share/mime/.*\.cache' | \
        grep -vE '^/usr/share/glib-2\.0/schemas/gschemas\.compiled' | \
        grep -vE '^/usr/share/icons/.*/icon-theme\.cache' > "$orphaned_files"

    echo "--- Orphaned Files ---"
    cat "$orphaned_files"
    
    echo ""
    echo "Total orphaned files: $(wc -l < "$orphaned_files")"
    rm -f "$sys_files" "$tracked_files" "$orphaned_files"
}

ls_orphaned_files() {
    ssh_lfs "$(declare -f ls_orphaned_files_gpt); ls_orphaned_files_gpt $*"
}

which_pkg_owns_gpt() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: which_pkg_owns <file> [file2 ...]"
        return 1
    fi

    for target in "$@"; do
        # Normalize: strip trailing slash for directories
        target="${target%/}"
        local found=false

        # Search book-packages first, then custom-packages
        for dir in /var/lib/book-packages /var/lib/custom-packages; do
            [[ -d "$dir" ]] || continue
            local pkg_type
            if [[ "$dir" == *book* ]]; then pkg_type="book"; else pkg_type="custom"; fi

            # Each file in $dir is a package; the first line is the version,
            # subsequent lines are installed file paths.
            for pkg_file in "$dir"/*; do
                [[ -f "$pkg_file" ]] || continue
                local pkg_name=$(basename "$pkg_file")
                # awk: skip line 1 (version), check if any line matches target
                if awk 'NR>1 && $0 == target { found=1; exit } END { exit !found }' \
                        target="$target" "$pkg_file" 2>/dev/null; then
                    local version=$(head -n1 "$pkg_file" 2>/dev/null)
                    echo "$target → $pkg_name ($pkg_type, v$version)"
                    found=true
                    break 2
                fi
            done
        done

        if [[ "$found" != "true" ]]; then
            echo "$target → (not owned by any tracked package)"
        fi
    done
}

which_pkg_owns() {
    ssh_lfs "$(declare -f which_pkg_owns_gpt); which_pkg_owns_gpt $*"
}

prune_pkg_inventory_gpt() {
    # Usage: prune_pkg_inventory_gpt <inventory_to_prune> <authoritative_inventory> [...]
    # Removes entries from <inventory_to_prune> that are listed in any <authoritative_inventory>.
    # The first line (version) of the pruned inventory is preserved.
    if [[ $# -lt 2 ]]; then
        echo "Usage: prune_pkg_inventory <inventory_to_prune> <authoritative_inventory> [more_inventories...]"
        echo "Example: prune_pkg_inventory /var/lib/book-packages/qt6 /var/lib/custom-packages/imagemagick"
        return 1
    fi

    local target="$1"
    shift
    local authority_files=("$@")

    if [[ ! -f "$target" ]]; then
        echo "Error: target inventory not found: $target"
        return 1
    fi

    # Build a set of all file paths from all authoritative inventories (skip line 1 = version)
    local auth_files_tmp=$(mktemp)
    for auth in "${authority_files[@]}"; do
        if [[ ! -f "$auth" ]]; then
            echo "Warning: authoritative inventory not found: $auth"
            continue
        fi
        tail -n +2 "$auth" >> "$auth_files_tmp"
    done
    sort -u -o "$auth_files_tmp" "$auth_files_tmp"

    local total_auth=$(wc -l < "$auth_files_tmp")
    echo "Loaded $total_auth file entries from ${#authority_files[@]} authoritative inventories."

    # Count how many lines in target would be removed
    local version_line=$(head -n1 "$target")
    local before=$(tail -n +2 "$target" | wc -l)

    # Write new inventory: keep version line, then only paths NOT in auth set
    local tmp_out=$(mktemp)
    echo "$version_line" > "$tmp_out"
    tail -n +2 "$target" | grep -vxFf "$auth_files_tmp" >> "$tmp_out"

    local after=$(tail -n +1 "$tmp_out" | wc -l)
    local after_entries=$(( after - 1 ))
    local removed=$(( before - after_entries ))

    if [[ $removed -eq 0 ]]; then
        echo "No overlapping entries found. Inventory unchanged."
        rm -f "$auth_files_tmp" "$tmp_out"
        return 0
    fi

    echo "Removing $removed entries from $(basename "$target") (was $before, now $after_entries files)."
    sudo cp "$tmp_out" "$target"
    echo "Done. Inventory pruned successfully."
    rm -f "$auth_files_tmp" "$tmp_out"
}

prune_pkg_inventory() {
    # Resolve inventory paths: if bare name given, search both dirs
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == /* ]]; then
            args+=("$arg")
        elif [[ -f "/var/lib/book-packages/$arg" ]]; then
            args+=("/var/lib/book-packages/$arg")
        elif [[ -f "/var/lib/custom-packages/$arg" ]]; then
            args+=("/var/lib/custom-packages/$arg")
        else
            args+=("$arg")  # pass through, let the remote function error
        fi
    done
    ssh_lfs "$(declare -f prune_pkg_inventory_gpt); prune_pkg_inventory_gpt ${args[*]}"
}

