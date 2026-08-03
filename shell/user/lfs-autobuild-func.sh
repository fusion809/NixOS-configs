#!/usr/bin/env bash

lfs_autobuild() {
    local logfile="/tmp/lfs-autobuild.log"
    # Truncate log if it exceeds 100MB to keep searches fast
    if [[ -f "$logfile" ]] && [[ $(stat -c%s "$logfile") -gt 104857600 ]]; then
        echo "--- Log truncated at $(date) (over 100MB) ---" > "$logfile"
    fi
    echo "--- Build session starting at $(date) ---" | tee -a "$logfile" >/dev/null
    
    # Only source SSH helpers and sync scripts when running on the host
    if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
        source "$NIXCFG/shell/user/08-ssh.sh"
        source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
        # Sync the latest host scripts to the VM, then execute it there.
        # This ensures the VM always uses the host's current version.
        ssh_lfs "cat > ~/.lfs_autobuild.sh && chmod +x ~/.lfs_autobuild.sh" \
            < "$NIXCFG/shell/user/lfs-autobuild.sh"
        ssh_lfs "cat > ~/.lfs_scripts/xorg_loop.awk" \
            < "$NIXCFG/shell/user/xorg_loop.awk"
        # Also keep lfs update scripts in sync
        ssh_lfs "mkdir -p ~/.lfs_scripts"
        ssh_lfs "cat > ~/.lfs_scripts/21-lfs.sh" < "$NIXCFG/shell/user/21-lfs.sh"
        ssh_lfs "cat > ~/.lfs_scripts/lfs-updates.sh && chmod +x ~/.lfs_scripts/lfs-updates.sh" \
            < "$NIXCFG/shell/user/lfs-updates.sh"
        ssh_lfs "cat > ~/.lfs_scripts/lfs-vm-bootstrap.sh" \
            < "$NIXCFG/shell/user/lfs-vm-bootstrap.sh"
        ssh_lfs "grep -q 'lfs-vm-bootstrap.sh' ~/.bashrc || echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.bashrc"
        echo "Building $@..." | tee -a "$logfile" >/dev/null
        ssh_lfs "bash ~/.lfs_autobuild.sh $(printf '%q ' "$@")" 2>&1 | tee -a "$logfile"
        return ${PIPESTATUS[0]}
    else
        # Running directly on the VM, no syncing needed, just execute it locally
        echo "Building $@..." | tee -a "$logfile" >/dev/null
        bash ~/.lfs_autobuild.sh "$@" 2>&1 | tee -a "$logfile"
        return ${PIPESTATUS[0]}
    fi
}

