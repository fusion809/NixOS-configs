#!/usr/bin/env bash

rm_old_docs_gpt() {
    local doc_root="/usr/share/doc"
    local dry_run=false
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=true ;;
            /*) doc_root="$arg" ;;
        esac
    done
    [[ "$dry_run" == "true" ]] && echo "[DRY RUN] No files will be deleted."
    echo "Scanning $doc_root for stale old-version directories..."

    # Pass 1: determine the newest versioned dir for each package base name.
    declare -A latest=()
    local dir base pkg_base
    while IFS= read -r dir; do
        base=$(basename "$dir")
        pkg_base=$(echo "$base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
        [[ "$pkg_base" == "$base" ]] && continue   # no version suffix → skip
        latest["$pkg_base"]="$dir"                 # sort -V: last wins = newest
    done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d | sort -V)

    # Pass 2: for every versioned dir that is NOT the newest for its base,
    # delete it only if it is not listed in any package registry file.
    local removed=0 kept_registered=0
    while IFS= read -r dir; do
        base=$(basename "$dir")
        pkg_base=$(echo "$base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
        [[ "$pkg_base" == "$base" ]] && continue

        # Condition 1: is there a newer dir for this package?
        [[ "${latest[$pkg_base]}" == "$dir" ]] && continue   # this IS the newest → keep

        # Condition 2: is this dir listed in any registry file?
        if grep -qrl "^${dir}" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null; then
            echo "Keeping $base (older but listed in registry)"
            kept_registered=$((kept_registered + 1))
            continue
        fi

        # Older AND not in registry → stale, safe to delete.
        echo "Removing stale: $base  (newer: $(basename "${latest[$pkg_base]}"))"
        if [[ "$dry_run" == "false" ]]; then
            sudo rm -rf -- "$dir"
        fi
        removed=$((removed + 1))
    done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d | sort -V)

    echo "---"
    echo "Removed          : $removed"
    echo "Kept (registered): $kept_registered"
}

rm_old_docs() {
    ssh_lfs "$(declare -f rm_old_docs_gpt); rm_old_docs_gpt $*"
}


# `rm_old_share` = cleanup old versioned dirs in /usr/share
rm_old_share() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    echo "Scanning /usr/share for orphaned directories..."

    # Create a fast lookup of all currently owned files and directories
    local all_files_db=$(mktemp)
    # Combine all package databases (ignoring first line versions/errors)
    cat /var/lib/book-packages/* /var/lib/custom-packages/* 2>/dev/null | grep "^/" > "$all_files_db" || true

    if [[ ! -s "$all_files_db" ]]; then
        echo "Error: Package database is empty or could not be read. Aborting cleanup for safety."
        rm -f "$all_files_db"
        return 1
    fi

    local deleted_count=0
    # Check top-level directories in /usr/share
    for dir in $(find /usr/share -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
        # We only want to clean up directories that look like they have a version suffix
        # to avoid wiping out things like /usr/share/man if it accidentally got untracked,
        # but the user specifically wanted to clean up versioned leftovers.
        local dir_version=$(echo "$dir" | grep -oE -- '-[0-9]+(\.[0-9]+)*$' | sed 's/^-//')
        if [[ -n "$dir_version" ]]; then
            local base_name=$(echo "$dir" | sed -E "s/-${dir_version}\$//")
            
            # Check if this directory or anything inside it is claimed by ANY active package
            if ! grep -q "^${dir}\$\|^${dir}/" "$all_files_db"; then
                # Only delete if there is a newer version of this directory in /usr/share
                local has_newer=false
                for other_dir in $(find /usr/share -mindepth 1 -maxdepth 1 -type d -name "$(basename "${base_name}")-*" 2>/dev/null); do
                    [[ "$other_dir" == "$dir" ]] && continue
                    local other_version=$(echo "$other_dir" | grep -oE -- '-[0-9]+(\.[0-9]+)*$' | sed 's/^-//')
                    if [[ -n "$other_version" ]]; then
                        local highest=$(printf "%s\n%s\n" "$dir_version" "$other_version" | sort -V | tail -n 1)
                        if [[ "$highest" == "$other_version" && "$highest" != "$dir_version" ]]; then
                            has_newer=true
                            break
                        fi
                    fi
                done
                
                if [[ "$has_newer" == "true" ]]; then
                    deleted_count=$((deleted_count + 1))
                    if [[ "$dry_run" == "true" ]]; then
                        echo "Would delete orphaned versioned dir (newer version exists): $dir"
                    else
                        echo "Deleting orphaned versioned dir: $dir"
                        sudo rm -rf "$dir"
                    fi
                fi
            fi
        fi
    done

    rm -f "$all_files_db"
    
    if [[ "$deleted_count" -eq 0 ]]; then
        echo "No orphaned versioned directories were found to delete."
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete."
    else
        echo "Cleanup of /usr/share complete."
    fi
}
