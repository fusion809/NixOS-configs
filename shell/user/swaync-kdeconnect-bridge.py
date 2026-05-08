#!/usr/bin/env python3
import pydbus
from gi.repository import GLib, Gio
import sys
import threading
import subprocess
import re

# This script bridges SwayNC and KDE Connect for specific notification dismissal.
# It monitors DBus calls to build a mapping between desktop notification IDs 
# and their content, allowing it to dismiss only the specific notification 
# on the phone when it is closed on the desktop.

# Mapping: desktop_id -> (title, body)
desktop_map = {}
# Pending calls: serial -> (title, body)
pending_calls = {}

def get_device_info(bus):
    try:
        daemon = bus.get("org.kde.kdeconnect", "/modules/kdeconnect")
        devices = daemon.devices()
        return daemon, devices
    except:
        return None, []

def dismiss_specific_phone_notification(title, body):
    try:
        bus = pydbus.SessionBus()
        daemon, devices = get_device_info(bus)
        if not daemon:
            return

        for device_id in devices:
            device_path = f"/modules/kdeconnect/devices/{device_id}"
            device = bus.get("org.kde.kdeconnect", device_path)
            
            if not device.isReachable:
                continue
            
            notif_path = f"{device_path}/notifications"
            try:
                notif_manager = bus.get("org.kde.kdeconnect", notif_path)
                active_notifs = notif_manager.activeNotifications()
                
                for notif_id in active_notifs:
                    child_path = f"{notif_path}/{notif_id}"
                    try:
                        notif = bus.get("org.kde.kdeconnect", child_path)
                        # Match by title and body
                        # Note: body might be truncated or have extra info, so we do a fuzzy match
                        if notif.title == title and (body in notif.text or notif.text in body):
                            if notif.dismissable:
                                print(f"Dismissing specific notification on {device.name}: {notif.title}")
                                notif.dismiss()
                                return True # Found and dismissed
                    except:
                        continue
            except:
                continue
    except Exception as e:
        print(f"Error in specific dismissal: {e}")
    return False

def dbus_monitor_thread():
    # We use dbus-monitor to catch the Notify calls and their returns
    # to map desktop IDs to notification content.
    cmd = ["dbus-monitor", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
           "type='method_return',sender='org.freedesktop.Notifications'"]
    
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    current_serial = None
    current_summary = None
    current_body = None
    
    # State machine for parsing dbus-monitor output
    state = "IDLE"
    
    for line in process.stdout:
        line = line.strip()
        
        # Detect method call
        if "member=Notify" in line:
            match = re.search(r"serial=(\d+)", line)
            if match:
                current_serial = match.group(1)
                state = "PARSE_NOTIFY"
                continue
        
        # Detect method return
        if "method return" in line:
            match = re.search(r"reply_serial=(\d+)", line)
            if match:
                reply_serial = match.group(1)
                state = "PARSE_RETURN"
                current_serial = reply_serial
                continue

        if state == "PARSE_NOTIFY":
            # The 4th and 5th strings are summary and body
            # We look for strings
            match = re.search(r'string "(.*)"', line)
            if match:
                val = match.group(1)
                if current_summary is None:
                    # Skip app_name (1st string)
                    if "KDE Connect" in val or state == "PARSE_NOTIFY_SUMMARY":
                         state = "PARSE_NOTIFY_SUMMARY"
                    continue
                elif state == "PARSE_NOTIFY_SUMMARY":
                    current_summary = val
                    state = "PARSE_NOTIFY_BODY"
                elif state == "PARSE_NOTIFY_BODY":
                    current_body = val
                    pending_calls[current_serial] = (current_summary, current_body)
                    print(f"Captured pending Notify: serial={current_serial}, summary={current_summary}")
                    current_serial = current_summary = current_body = None
                    state = "IDLE"
                    
        elif state == "PARSE_RETURN":
            match = re.search(r'uint32 (\d+)', line)
            if match:
                desktop_id = int(match.group(1))
                if current_serial in pending_calls:
                    desktop_map[desktop_id] = pending_calls.pop(current_serial)
                    print(f"Mapped desktop ID {desktop_id} to content")
                state = "IDLE"

def on_notification_closed(id, reason):
    print(f"Desktop notification closed: id={id}, reason={reason}")
    sys.stdout.flush()
    
    if reason == 2: # User dismissed
        if id in desktop_map:
            title, body = desktop_map.pop(id)
            print(f"Attempting specific dismissal for: {title}")
            if not dismiss_specific_phone_notification(title, body):
                print("Specific dismissal failed, notification might already be gone or no match found.")
        else:
            print(f"No mapping found for desktop ID {id}, falling back to 'refresh' (not recommended for specific).")
            # If we don't have a mapping, we could fall back to refreshing but that might clear all.
            # For now, we do nothing to fulfill the user's request of NOT clearing all.

def main():
    try:
        # Start the monitor thread
        threading.Thread(target=dbus_monitor_thread, daemon=True).start()
        
        print("Connecting to Session Bus...")
        sys.stdout.flush()
        bus = pydbus.SessionBus()
        
        print("Getting Notifications proxy...")
        sys.stdout.flush()
        notifications = bus.get("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
        notifications.NotificationClosed.connect(on_notification_closed)
        
        print("SwayNC-KDEConnect bridge started (Specific Mode)...")
        sys.stdout.flush()
        
        loop = GLib.MainLoop()
        loop.run()
    except Exception as e:
        print(f"Failed to start bridge: {e}")
        sys.stdout.flush()
        sys.exit(1)

if __name__ == "__main__":
    main()
