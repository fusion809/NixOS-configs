#!/bin/bash
# Apply a wrapper to GNOME session to clear systemd user state
source ~/.lfs_scripts/08-ssh.sh
ssh_lfs 'sudo bash -c "cat > /usr/local/bin/gnome-session-sddm-wrapper << '\''INNEREOF'\''
#!/bin/bash
systemctl --user stop graphical-session.target graphical-session-pre.target 2>/dev/null || true
systemctl --user reset-failed 2>/dev/null || true
exec /usr/bin/gnome-session \"\$@\"
INNEREOF
chmod +x /usr/local/bin/gnome-session-sddm-wrapper
sed -i \"s|^Exec=/usr/bin/gnome-session|Exec=/usr/local/bin/gnome-session-sddm-wrapper|g\" /usr/share/wayland-sessions/gnome.desktop
sed -i \"s|^Exec=/usr/bin/gnome-session|Exec=/usr/local/bin/gnome-session-sddm-wrapper|g\" /usr/share/wayland-sessions/gnome-wayland.desktop
"'
