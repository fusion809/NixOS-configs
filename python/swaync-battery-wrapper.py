#!/usr/bin/env python3
import sys
import json
import subprocess
import threading
import time

# Script to get battery info
KDECONNECT_SCRIPT = "/home/fusion809/GitHub/mine/config/NixOS-configs/shell/hyprland/kdeconnect"

swaync_state = {"text": "", "alt": "none", "tooltip": "", "class": "none"}
battery_text = ""
battery_tooltip = ""

def update_battery():
    global battery_text, battery_tooltip
    while True:
        try:
            res = subprocess.run([KDECONNECT_SCRIPT], capture_output=True, text=True)
            if res.stdout.strip():
                batt_data = json.loads(res.stdout.strip())
                # Only keep the battery text if it's connected (not the disconnected icon)
                bt = batt_data.get("text", "")
                if bt.startswith("󰄷"):
                    battery_text = "" # Don't show anything if disconnected
                else:
                    battery_text = bt
                battery_tooltip = batt_data.get("tooltip", "")
        except Exception:
            pass
        print_combined()
        time.sleep(30)

def print_combined():
    combined = swaync_state.copy()
    
    # We can combine tooltips
    sway_tt = swaync_state.get("tooltip", "")
    tt = []
    if battery_tooltip: tt.append(battery_tooltip)
    if sway_tt: tt.append(sway_tt)
    combined["tooltip"] = "\n".join(tt)
    
    icons = {
        "notification": "󱅫",
        "none": "󰂚",
        "dnd-notification": "󰂛",
        "dnd-none": "󰂛",
        "inhibited-notification": "󱅫",
        "inhibited-none": "󰂚",
        "dnd-inhibited-notification": "󰂛",
        "dnd-inhibited-none": "󰂛"
    }
    
    alt_val = swaync_state.get("alt", "none")
    icon = icons.get(alt_val, "󰂚")
    
    st = swaync_state.get("text", "")
    if st == "0" or not st:
        st = ""
        
    parts = []
    if battery_text: parts.append(battery_text)
    parts.append(icon)
    if st: parts.append(st)
    
    combined["text"] = " ".join(parts)
        
    print(json.dumps(combined), flush=True)

def read_swaync():
    global swaync_state
    cmd = ["swaync-client", "-swb"]
    # Unbuffered reads
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)
    for line in process.stdout:
        try:
            if line.strip():
                swaync_state = json.loads(line.strip())
                print_combined()
        except Exception:
            pass

if __name__ == "__main__":
    t = threading.Thread(target=update_battery, daemon=True)
    t.start()
    read_swaync()
