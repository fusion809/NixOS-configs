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

# `update` = lfs_update_all
update() {
    lfs_update_all "$@"
}
export -f update
