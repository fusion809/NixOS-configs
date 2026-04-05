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
export -f ssh_lfs

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
export -f updates

# ---- Commit and Push Registry Changes ----
lfs_package_commit() {
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
export -f lfs_package_commit

# ---- Manual Commit Helper ----
lfs_commit() {
    lfs_package_commit "$@"
}
export -f lfs_commit

# `update` = lfs_update_all
update() {
    lfs_update_all "$@"
}
export -f update
