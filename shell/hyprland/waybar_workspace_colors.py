#!/usr/bin/env python3
import json
import subprocess
import os
import time

CSS_PATH = os.path.expanduser("~/GitHub/mine/config/NixOS-configs/dotfiles/workspaces.css")
MONITOR_COLORS = {
    "HDMI-A-1": "#000000",
    "DVI-D-1": "#008B8B"
}

def get_workspaces():
    try:
        output = subprocess.check_output(["hyprctl", "-j", "workspaces"], encoding="utf-8")
        return json.loads(output)
    except Exception as e:
        print(f"Error getting workspaces: {e}")
        return []

def generate_css(workspaces):
    css_lines = ["/* Automatically generated workspace colors */"]
    for ws in workspaces:
        ws_id = ws.get("id")
        monitor = ws.get("monitor")
        color = MONITOR_COLORS.get(monitor, "#ffffff")
        
        # Target the button and its label with high specificity
        css_lines.append(f'#workspaces button.workspace-{ws_id},')
        css_lines.append(f'#workspaces button.workspace-{ws_id} label {{ color: {color}; }}')
    
    return "\n".join(css_lines)

def main():
    last_css = ""
    while True:
        workspaces = get_workspaces()
        new_css = generate_css(workspaces)
        
        if new_css != last_css:
            with open(CSS_PATH, "w") as f:
                f.write(new_css)
            last_css = new_css
            # Signal Waybar to reload CSS
            subprocess.run(["pkill", "-SIGUSR2", "waybar"])
            print("Updated Waybar CSS")
            
        time.sleep(2) # Poll every 2 seconds

if __name__ == "__main__":
    main()
