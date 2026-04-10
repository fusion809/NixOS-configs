#!/usr/bin/env python3
import json
import subprocess
import os
import time

CSS_PATH = os.path.expanduser("~/GitHub/mine/config/NixOS-configs/dotfiles/workspaces.css")
MONITOR_COLORS = {
    "HDMI-A-1": "#212121",
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
    css_lines = ["/* Automatically generated workspace colors (nth-child approach) */"]
    
    # Sort workspaces by ID to match Waybar's default order
    sorted_ws = sorted(workspaces, key=lambda x: x.get("id", 0))
    
    for index, ws in enumerate(sorted_ws):
        ws_id = ws.get("id")
        monitor = ws.get("monitor")
        color = MONITOR_COLORS.get(monitor, "#ffffff")
        
        # We use index + 1 because nth-child is 1-indexed
        nth = index + 1
        
        # Target the button's background color while preserving hover/active states
        css_lines.append(f'#workspaces button:nth-child({nth}):not(:hover):not(.active) {{ background-color: {color}; }}')
        
        # Monitor-specific hover text color
        css_lines.append(f'#workspaces button:nth-child({nth}):hover {{ color: {color}; }}')
    
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
