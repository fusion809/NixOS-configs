sync_to_vm() {
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    echo "Syncing LFS scripts to VM..."
    ssh_lfs "mkdir -p ~/.lfs_scripts"
    
    # Sync new modular scripts
    ssh_lfs "cat > ~/.lfs_scripts/21-lfs.sh" < "$NIXCFG/shell/user/21-lfs.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-libs.sh" < "$NIXCFG/shell/user/lfs-libs.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-kerns.sh" < "$NIXCFG/shell/user/lfs-kerns.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-share.sh" < "$NIXCFG/shell/user/lfs-share.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-update.sh" < "$NIXCFG/shell/user/lfs-update.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-autoremove.sh" < "$NIXCFG/shell/user/lfs-autoremove.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-autobuild-func.sh" < "$NIXCFG/shell/user/lfs-autobuild-func.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-sync-to-vm.sh" < "$NIXCFG/shell/user/lfs-sync-to-vm.sh"
    
    ssh_lfs "cat > ~/.lfs_scripts/lfs-updates.sh && chmod +x ~/.lfs_scripts/lfs-updates.sh" \
        < "$NIXCFG/shell/user/lfs-updates.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-vm-bootstrap.sh" \
        < "$NIXCFG/shell/user/lfs-vm-bootstrap.sh"
    ssh_lfs "cat > ~/.lfs_autobuild.sh && chmod +x ~/.lfs_autobuild.sh" \
        < "$NIXCFG/shell/user/lfs-autobuild.sh"
    ssh_lfs "cat > ~/.lfs_scripts/xorg_loop.awk" \
        < "$NIXCFG/shell/user/xorg_loop.awk"
    ssh_lfs "cat > ~/.lfs_scripts/upos.sh" \
        < "$NIXCFG/shell/user/upos.sh"

    # Hook into ~/.bashrc if not already present
    ssh_lfs "grep -q 'lfs-vm-bootstrap.sh' ~/.bashrc || echo '# LFS update helpers' >> ~/.bashrc && echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.bashrc"
    ssh_lfs "touch ~/.zshrc && (grep -q 'lfs-vm-bootstrap.sh' ~/.zshrc || echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.zshrc)"
    echo "Sync complete. 'updates', 'update', 'autobuild', 'autoremove', 'commit', 'updatec', and 'sync_to_vm' are now available on the host; 'updates', 'update', 'autobuild', 'autoremove', and 'commit' are available on the VM."
}
