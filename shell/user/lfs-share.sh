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

    local removed=0 removed_kept=0

    while IFS= read -r dir; do
        local base pkg_base
        base=$(basename "$dir")
        pkg_base=$(echo "$base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
        [[ "$pkg_base" == "$base" ]] && continue   # no version suffix → skip

        # Is there a strictly newer version directory for this package?
        local has_newer=false newest_base=""
        local other_dir other_base other_pkg_base newest
        while IFS= read -r other_dir; do
            [[ "$other_dir" == "$dir" ]] && continue
            other_base=$(basename "$other_dir")
            other_pkg_base=$(echo "$other_base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
            [[ "$other_pkg_base" != "$pkg_base" ]] && continue
            # Same package base — is other_base strictly newer than base?
            newest=$(printf '%s\n%s\n' "$base" "$other_base" | sort -V | tail -n 1)
            if [[ "$newest" == "$other_base" && "$newest" != "$base" ]]; then
                has_newer=true
                newest_base="$other_base"
                break
            fi
        done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d)

        # No newer version exists → this IS the only/newest → always keep
        [[ "$has_newer" == "false" ]] && continue

        # A newer version exists. Check if old version is legitimately still installed.
        # Registry files have the current version as their first line. If the file
        # containing the old path has a version line matching this dir's version,
        # it's a genuine current entry (e.g. gcr-3 coexisting with gcr-4).
        # If the version line has moved on (e.g. to linux-7.1.6), the path is stale.
        local keep_it=false
        local dir_version="${base#${pkg_base}-}"
        local reg_file
        while IFS= read -r reg_file; do
            local reg_ver
            reg_ver=$(head -n 1 "$reg_file" 2>/dev/null | tr -d '[:space:]')
            if [[ "$reg_ver" == "$dir_version" ]]; then
                keep_it=true
                break
            fi
        done < <(grep -rl --exclude-dir=.git "^${dir}$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null)

        if [[ "$keep_it" == "true" ]]; then
            echo "Keeping $base (legitimately in registry)"
            removed_kept=$((removed_kept + 1))
            continue
        fi

        # Older AND stale/unregistered → safe to delete.
        echo "Removing stale: $base  (newer: $newest_base)"
        if [[ "$dry_run" == "false" ]]; then
            sudo rm -rf -- "$dir"
        fi
        removed=$((removed + 1))
    done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d | sort -V)

    echo "---"
    echo "Removed : $removed"
    echo "Kept    : $removed_kept"
}

rm_old_docs() {
    local funcdef args
    funcdef=$(declare -f rm_old_docs_gpt)
    args="$*"
    printf '%s\nrm_old_docs_gpt %s\n' "$funcdef" "$args" | ssh_lfs "bash --norc --noprofile -s"
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
