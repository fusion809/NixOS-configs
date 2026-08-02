#!/usr/bin/env bash
# LFS VM Bootstrap - Auto-synced from host via lfs_sync_to_vm
# Provides `updates` and `update` commands inside the LFS VM.
# DO NOT EDIT MANUALLY - changes will be overwritten on next sync.

# ---- Local passthrough for ssh_lfs (we ARE the VM) ----
ssh_lfs() {
    local cmd="$1"
    shift
    case "$cmd" in
        "bash -s")
            bash -s "$@"
            ;;
        *)
            eval "$cmd" "$@"
            ;;
    esac
}
if [ -n "$BASH_VERSION" ]; then
    export -f ssh_lfs
fi

# NIXCFG is not meaningful inside the VM, but 21-lfs.sh needs it set.
export NIXCFG="${HOME}/.lfs_scripts"

# Source the main helper library
if [[ -f "${HOME}/.lfs_scripts/21-lfs.sh" ]]; then
    source "${HOME}/.lfs_scripts/21-lfs.sh"
fi

# ---- VM-side command aliases ----
# `updates` = lfs_updates (with optional --upstream flag)
updates() {
    bash "${HOME}/.lfs_scripts/lfs-updates.sh" "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f updates
fi

# ---- Commit and Push Registry Changes ----
lfs_package_commit() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: lfs_commit [message]"
        echo "Example: lfs_commit 'Updated kernel to 6.6.1'"
        echo "If no message is provided, one will be auto-generated based on changes."
        return 0
    fi

    # Safety check: refuse to commit if any inventory is broken (≤1 line = only version
    # header, or BUILD_FAILED marker written by the failure trap in lfs-autobuild.sh).
    local broken_pkgs
    broken_pkgs=$(find /var/lib/book-packages /var/lib/custom-packages \
        -maxdepth 1 -type f ! -name ".*" 2>/dev/null \
        | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" \
        | while read -r f; do
            [ "$(wc -l < "$f")" -le 1 ] && basename "$f"
          done)
    if [[ -n "$broken_pkgs" ]]; then
        echo "ERROR: Refusing to commit — the following packages have missing/broken inventories:"
        echo "$broken_pkgs"
        echo "Fix them (re-run lfs_autobuild for each), then retry lfs_package_commit."
        return 1
    fi

    local msg="$1"
    local push_needed=false
    for dir in /var/lib/book-packages /var/lib/custom-packages; do
        if [ -d "$dir/.git" ]; then
            (
                cd "$dir"
                local final_msg=""
                if [ -z "$msg" ]; then
                    # Auto-generate list of version changes
                    local changes=""
                    # Get all modified or new files
                    for f in $(git status --short | awk '{print $NF}'); do
                        [ -f "$f" ] || continue
                        local name=$(basename "$f")
                        # Ignore metadata files
                        [[ "$name" =~ ^(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$ ]] && continue
                        
                        local new_v=$(head -n 1 "$f" | tr -d '[:space:]' | sed 's/\.tar.*//')
                        local old_v=$(git show "HEAD:$f" 2>/dev/null | head -n 1 | tr -d '[:space:]' | sed 's/\.tar.*//' || echo "NEW")
                        
                        if [ "$old_v" = "NEW" ]; then
                            changes="${changes}${name}: ${new_v} (NEW); "
                        elif [ "$old_v" != "$new_v" ]; then
                            changes="${changes}${name}: ${old_v}->${new_v}; "
                        fi
                    done
                    if [ -n "$changes" ]; then
                        final_msg="${changes%; }."
                    fi
                else
                    final_msg="$msg"
                fi

                if [ -n "$final_msg" ]; then
                    echo "Committing updates in $dir: $final_msg"
                    git add -A
                    git commit -m "$final_msg" 2>/dev/null
                fi

                # Push if we are ahead of origin
                if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
                    local branch=$(git rev-parse --abbrev-ref HEAD)
                    if [ "$(git rev-list ${branch}...origin/${branch} --count 2>/dev/null || echo 1)" -gt 0 ]; then
                        echo "Pushing changes in $dir..."
                        git push origin "$branch" 2>/dev/null || true
                    fi
                fi
            )
        fi
    done
}

if [ -n "$BASH_VERSION" ]; then
    export -f lfs_package_commit
fi

# ---- Manual Commit Helper ----
lfs_commit() {
    lfs_package_commit "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f lfs_commit
fi

# `update` = lfs_update
update() {
    lfs_update "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f update
fi

# `autobuild` = lfs_autobuild
autobuild() {
    lfs_autobuild "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f autobuild
fi

# `autoremove` = lfs_autoremove
autoremove() {
    lfs_autoremove "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f autoremove
fi

# `cleanup_share_dirs` = cleanup old versioned dirs in /usr/share
cleanup_share_dirs() {
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
if [ -n "$BASH_VERSION" ]; then
    export -f cleanup_share_dirs
fi
