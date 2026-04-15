#!/usr/bin/env bash

# Wait for Wayland, DBus, and xdg-desktop-portal to finish fully initializing
# This is crucial for fixing the "Chrome freezes on startup on an unfocused workspace" issue.
sleep 2

# === WORKSPACE 7: Chrome and Terminals ===
hyprctl dispatch workspace 7

# Launch Chrome
google-chrome-stable &

# Give Chrome a little longer to render its first frame so it doesn't freeze
sleep 2

# Create the hy3 tab group
hyprctl dispatch hy3:makegroup tab

# Spawn terminals that belong in Workspace 7
$HOME/GitHub/mine/config/NixOS-configs/shell/hyprland/ved-alacritty &
sleep 0.5
$HOME/GitHub/mine/config/NixOS-configs/shell/hyprland/ged-alacritty &
sleep 0.5

# === WORKSPACE 20: Terminals ===
hyprctl dispatch workspace 20

# Launch first terminal
kitty &
sleep 0.5

# Create the hy3 tab group
hyprctl dispatch hy3:makegroup tab

# Launch second terminal
kitty &
sleep 0.5

# Ensure we're back at the default workspace (workspace 1) when done
hyprctl dispatch workspace 1
