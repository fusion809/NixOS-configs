#!/usr/bin/env python3
import subprocess
import json
import re
import sys

def get_audio_info():
    try:
        # Get volume and mute status
        res = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True)
        # Output is like "Volume: 0.68 [MUTED]" or "Volume: 0.68"
        output = res.stdout.strip()
        
        volume_match = re.search(r"Volume: (\d+\.\d+)", output)
        volume = int(float(volume_match.group(1)) * 100) if volume_match else 0
        muted = "[MUTED]" in output
        
        # Get current sink ID and details
        res_status = subprocess.run(["wpctl", "status"], capture_output=True, text=True)
        status_output = res_status.stdout
        
        # Find the line with the * (active sink)
        # Example: " *   77. ROAMFREE                            [vol: 0.68]"
        sink_match = re.search(r"\*\s+(\d+)\.\s+(.*)\[vol:", status_output)
        if not sink_match:
            # Try another format if the above fails
            sink_match = re.search(r"\*\s+(\d+)\.\s+(.*)", status_output)
            
        if sink_match:
            sink_id = sink_match.group(1)
            sink_desc = sink_match.group(2).strip()
            
            # Inspect sink for Bluetooth address
            res_inspect = subprocess.run(["wpctl", "inspect", sink_id], capture_output=True, text=True)
            inspect_output = res_inspect.stdout
            
            mac_match = re.search(r'api\.bluez5\.address = "(.*)"', inspect_output)
            if mac_match:
                mac = mac_match.group(1)
                # Get battery percentage
                res_bt = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True)
                bt_output = res_bt.stdout
                battery_match = re.search(r"Battery Percentage: .* \((\d+)\)", bt_output)
                battery = battery_match.group(1) if battery_match else None
                return volume, muted, True, battery, sink_desc
            
            return volume, muted, False, None, sink_desc
    except Exception as e:
        pass
    return 0, False, False, None, "Unknown"

def main():
    volume, muted, is_bluetooth, battery, desc = get_audio_info()
    
    icons_default = ["", "", ""]
    icon_headphone = ""
    icon_bluetooth = ""
    icon_muted = ""
    
    if muted:
        icon = icon_muted
        text = f"{icon} "
    else:
        # Choose audio icon based on device type and volume
        if is_bluetooth:
            icon = f"{icon_headphone} {icon_bluetooth}"
        elif "headphone" in desc.lower() or "headset" in desc.lower():
            icon = icon_headphone
        else:
            idx = min(len(icons_default) - 1, volume // 34)
            icon = icons_default[idx]
        
        # Construct text
        battery_text = ""
        if is_bluetooth and battery:
            charge = int(battery)
            # Battery icons matching kdeconnect script
            if   charge >= 90: b_icon = "󰁹"
            elif charge >= 70: b_icon = "󰂀"
            elif charge >= 50: b_icon = "󰁾"
            elif charge >= 30: b_icon = "󰁼"
            elif charge >= 15: b_icon = "󰁺"
            else:              b_icon = "󰁻"
            battery_text = f"{b_icon}{battery}% "
            
        text = f"{battery_text}{icon}{volume}%"
            
    out = {
        "text": text,
        "tooltip": f"Device: {desc}\nVolume:{volume}%" + (f"\nBattery:{battery}%" if battery else ""),
        "class": "muted" if muted else ("bluetooth" if is_bluetooth else "normal"),
        "alt": "muted" if muted else "unmuted"
    }
    print(json.dumps(out))

if __name__ == "__main__":
    main()
