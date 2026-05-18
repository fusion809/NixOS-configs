#!/usr/bin/env bash

# Move active window to the other monitor's active workspace
# Requirement: hyprctl and jq must be installed.

# Get the list of monitors
monitors=$(hyprctl monitors -j)

# Find the ID of the other monitor (not focused)
# Assuming 2 monitors. If there are more, this takes the first non-focused one.
other_monitor_workspace=$(echo "$monitors" | jq -r '.[] | select(.focused == false) | .activeWorkspace.id')

if [ -n "$other_monitor_workspace" ] && [ "$other_monitor_workspace" != "null" ]; then
    hyprctl dispatch movetoworkspace "$other_monitor_workspace"
fi
