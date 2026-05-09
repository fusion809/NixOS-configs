#!/usr/bin/env python3
import pydbus
from gi.repository import GLib, Gio
import sys
import threading
import subprocess
import re
import json
import time

# This script bridges SwayNC and KDE Connect for TWO-WAY notification dismissal.
# 1. SwayNC -> Phone: Clicking 'x' in SwayNC dismisses on the phone.
# 2. Phone -> SwayNC: Dismissing on phone (or opening on PC) clears in SwayNC.

class NotificationBridge:
    def __init__(self):
        self.bus = pydbus.SessionBus()
        # Mapping: desktop_id -> (device_id, phone_notif_id, title, body)
        self.desktop_to_phone = {}
        # Mapping: (device_id, phone_notif_id) -> desktop_id
        self.phone_to_desktop = {}
        # Pending calls: serial -> (device_id, phone_id, title, body)
        self.pending_notifs = {}
        # Set of desktop_ids currently being closed by this script to avoid feedback loops
        self.closing_by_bridge = set()

    def get_device_info(self):
        try:
            daemon = self.bus.get("org.kde.kdeconnect", "/modules/kdeconnect")
            return daemon, daemon.devices()
        except:
            return None, []

    def dismiss_on_phone(self, device_id, phone_notif_id, title, body):
        try:
            device_path = f"/modules/kdeconnect/devices/{device_id}"
            notif_path = f"{device_path}/notifications/{phone_notif_id}"
            try:
                notif = self.bus.get("org.kde.kdeconnect", notif_path)
                print(f"Dismissing notification {phone_notif_id} on device {device_id}...")
                notif.dismiss()
                return True
            except:
                # Fallback to fuzzy match if ID-based dismissal fails
                print(f"ID-based dismissal failed for {phone_notif_id}, trying fuzzy match...")
                return self.dismiss_fuzzy(device_id, title, body)
        except Exception as e:
            print(f"Error in phone dismissal: {e}")
        return False

    def dismiss_fuzzy(self, device_id, title, body):
        try:
            notif_manager_path = f"/modules/kdeconnect/devices/{device_id}/notifications"
            notif_manager = self.bus.get("org.kde.kdeconnect", notif_manager_path)
            active_notifs = notif_manager.activeNotifications()
            for nid in active_notifs:
                child_path = f"{notif_manager_path}/{nid}"
                try:
                    notif = self.bus.get("org.kde.kdeconnect", child_path)
                    if notif.title == title and (notif.text in body or body in notif.text):
                        if notif.dismissable:
                            print(f"Fuzzy match found for '{title}', dismissing...")
                            notif.dismiss()
                            return True
                except: continue
        except: pass
        return False

    def close_in_swaync(self, desktop_id):
        if not desktop_id: return
        print(f"Closing desktop notification {desktop_id}...")
        self.closing_by_bridge.add(desktop_id)
        try:
            subprocess.run(["swaync-client", "-close-notification", str(desktop_id)], check=False)
        finally:
            # We keep it in the set for a short time to catch the event
            threading.Timer(1.0, lambda: self.closing_by_bridge.discard(desktop_id)).start()

    def on_desktop_notification_closed(self, id, reason):
        if id in self.closing_by_bridge:
            print(f"Desktop notification {id} closed by bridge, skipping phone sync.")
            return

        print(f"Desktop notification {id} closed (reason={reason}).")
        if reason in (2, 3): # 2=Dismissed, 3=Closed by app/ClearAll
            if id in self.desktop_to_phone:
                dev_id, p_id, title, body = self.desktop_to_phone.pop(id)
                self.phone_to_desktop.pop((dev_id, p_id), None)
                self.dismiss_on_phone(dev_id, p_id, title, body)
            else:
                print(f"No phone mapping for desktop ID {id}.")

    def on_phone_notification_removed(self, sender, object, iface, signal, params):
        # Params is (id,)
        phone_notif_id = params[0]
        # We need to know which device sent this. The object path contains it.
        # Path: /modules/kdeconnect/devices/{device_id}/notifications
        match = re.search(r'/devices/([^/]+)/notifications', object)
        if match:
            device_id = match.group(1)
            print(f"Phone notification removed: device={device_id}, id={phone_notif_id}")
            desktop_id = self.phone_to_desktop.pop((device_id, phone_notif_id), None)
            if desktop_id:
                self.desktop_to_phone.pop(desktop_id, None)
                self.close_in_swaync(desktop_id)
            else:
                print(f"No desktop mapping for phone notification {phone_notif_id} on {device_id}.")

    def dbus_monitor_thread(self):
        cmd = ["stdbuf", "-o", "L", "dbus-monitor", 
               "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
               "type='method_return',sender='org.freedesktop.Notifications'"]
        
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)
        
        state = "IDLE"
        serial = None
        app_name = None
        device_id = None
        summary = None
        body = None
        phone_id = None
        string_idx = 0
        in_hints = False
        next_is_phone_id = False

        for line in process.stdout:
            line = line.strip()
            
            if "member=Notify" in line:
                m = re.search(r"serial=(\d+)", line)
                if m:
                    serial = m.group(1)
                    state = "PARSE_NOTIFY"
                    app_name = device_id = summary = body = phone_id = None
                    string_idx = 0
                    in_hints = False
                    next_is_phone_id = False
                continue

            if "method return" in line:
                m = re.search(r"reply_serial=(\d+)", line)
                if m:
                    reply_serial = m.group(1)
                    state = "PARSE_RETURN"
                    serial = reply_serial
                continue

            if state == "PARSE_NOTIFY":
                print(f"DEBUG: {line.strip()}") # Enable extreme debugging
                # Check for hints
                if "array [" in line: in_hints = True
                if "]" in line: in_hints = False
                
                if in_hints:
                    if 'string "x-kdeconnect-id"' in line:
                        next_is_phone_id = True
                    elif next_is_phone_id:
                        m = re.search(r'string "(.*)"', line)
                        if m: 
                            phone_id = m.group(1)
                            next_is_phone_id = False
                    continue

                m = re.search(r'string "(.*)"', line)
                if m:
                    val = m.group(1)
                    if string_idx == 0: app_name = val
                    elif string_idx == 1: device_id = val # app_icon param
                    elif string_idx == 2: summary = val
                    elif string_idx == 3: body = val
                    string_idx += 1
                
                # If we see the end of the Notify call (uint32 or int32 at the end)
                if "int32" in line or "uint32" in line:
                    if string_idx >= 3:
                        # Log and store now that hints are (potentially) parsed
                        print(f"Incoming Notify: app='{app_name}', summary='{summary}', phone_id='{phone_id}'")
                        if phone_id or app_name == "KDE Connect":
                            self.pending_notifs[serial] = (device_id, phone_id, summary, body)
                        state = "IDLE"

            elif state == "PARSE_RETURN":
                m = re.search(r'uint32 (\d+)', line)
                if m:
                    desktop_id = int(m.group(1))
                    if serial in self.pending_notifs:
                        info = self.pending_notifs.pop(serial)
                        dev_id, p_id, title, text = info
                        # If phone_id wasn't in hints, we might need to wait or it might not exist
                        if p_id:
                            self.desktop_to_phone[desktop_id] = (dev_id, p_id, title, text)
                            self.phone_to_desktop[(dev_id, p_id)] = desktop_id
                            print(f"Mapped: Desktop {desktop_id} <-> Phone {p_id} on {dev_id}")
                    state = "IDLE"

    def run(self):
        # Start monitor thread
        threading.Thread(target=self.dbus_monitor_thread, daemon=True).start()
        
        # Connect to desktop closure signals
        notif_proxy = self.bus.get("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
        notif_proxy.NotificationClosed.connect(self.on_desktop_notification_closed)
        
        # Subscribe to phone removal signals
        # We subscribe to all signals on this interface from this sender
        self.bus.subscribe(sender="org.kde.kdeconnect", 
                          iface="org.kde.kdeconnect.device.notifications", 
                          signal="notificationRemoved", 
                          signal_fired=self.on_phone_notification_removed)
        
        print("SwayNC-KDEConnect Bridge (Two-Way Sync) started.")
        sys.stdout.flush()
        
        loop = GLib.MainLoop()
        try:
            loop.run()
        except KeyboardInterrupt:
            pass

def main():
    bridge = NotificationBridge()
    bridge.run()

if __name__ == "__main__":
    main()
