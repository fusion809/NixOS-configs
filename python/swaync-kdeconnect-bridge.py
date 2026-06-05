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

LOG_FILE = "/tmp/swaync-kdeconnect-bridge.log"

def log_msg(msg):
    with open(LOG_FILE, "a") as f:
        f.write(f"{time.ctime()}: {msg}\n")
    print(msg)

class NotificationBridge:
    def __init__(self):
        self.bus = pydbus.SessionBus()
        # Mapping: desktop_id -> (device_id, phone_notif_id, title, body)
        self.desktop_to_phone = {}
        # Mapping: (device_id, phone_notif_id) -> desktop_id
        self.phone_to_desktop = {}
        # Pending calls: serial -> (device_id, phone_id, title, body, urgency, app_name, icon)
        self.pending_notifs = {}
        # Set of desktop_ids currently being closed by this script to avoid feedback loops
        self.closing_by_bridge = set()
        # Desktop IDs that were created by this bridge (re-fires) - don't re-process
        self.bridge_owned_desktops = set()
        # Serials of Notify calls made by this bridge - skip in PARSE_RETURN
        self.upgrade_serials = set()

    def get_device_info(self):
        try:
            daemon = self.bus.get("org.kde.kdeconnect", "/modules/kdeconnect")
            return daemon, daemon.devices()
        except:
            return None, []

    def wakeup_device(self, device_id):
        try:
            ping_path = f"/modules/kdeconnect/devices/{device_id}/ping"
            ping = self.bus.get("org.kde.kdeconnect", ping_path)
            ping.sendPing()
            log_msg(f"Sent wakeup ping to device {device_id}.")
            time.sleep(0.3)
        except: pass

    def dismiss_on_phone(self, device_id, phone_notif_id, title, body):
        self.wakeup_device(device_id)
        try:
            device_path = f"/modules/kdeconnect/devices/{device_id}"
            notif_path = f"{device_path}/notifications/{phone_notif_id}"
            try:
                notif = self.bus.get("org.kde.kdeconnect", notif_path)
                log_msg(f"Dismissing notification {phone_notif_id} on device {device_id}...")
                notif.dismiss()
                # Verify removal after a short delay
                threading.Timer(2.0, lambda: self.verify_and_retry(device_id, phone_notif_id, title, body)).start()
                return True
            except:
                log_msg(f"ID-based dismissal failed for {phone_notif_id}, trying fuzzy match...")
                return self.dismiss_fuzzy(device_id, title, body)
        except Exception as e:
            log_msg(f"Error in phone dismissal: {e}")
        return False

    def verify_and_retry(self, device_id, phone_notif_id, title, body, attempt=1):
        try:
            notif_manager_path = f"/modules/kdeconnect/devices/{device_id}/notifications"
            notif_manager = self.bus.get("org.kde.kdeconnect", notif_manager_path)
            if phone_notif_id in notif_manager.activeNotifications():
                if attempt < 3:
                    log_msg(f"Notification {phone_notif_id} still active on {device_id} (attempt {attempt}), retrying...")
                    self.wakeup_device(device_id)
                    try:
                        notif_path = f"{notif_manager_path}/{phone_notif_id}"
                        notif = self.bus.get("org.kde.kdeconnect", notif_path)
                        notif.dismiss()
                        threading.Timer(3.0, lambda: self.verify_and_retry(device_id, phone_notif_id, title, body, attempt + 1)).start()
                    except:
                        self.dismiss_fuzzy(device_id, title, body)
                else:
                    log_msg(f"Notification {phone_notif_id} persisted after {attempt} attempts. Trying fuzzy match as last resort.")
                    self.dismiss_fuzzy(device_id, title, body)
        except: pass

    def dismiss_fuzzy(self, device_id, title, body, attempt=1):
        log_msg(f"Fuzzy match attempt on device {device_id} (attempt {attempt}): title='{title}', body_len={len(body) if body else 0}")
        try:
            notif_manager_path = f"/modules/kdeconnect/devices/{device_id}/notifications"
            notif_manager = self.bus.get("org.kde.kdeconnect", notif_manager_path)
            active_notifs = notif_manager.activeNotifications()
            
            matched_ids = []
            for nid in active_notifs:
                child_path = f"{notif_manager_path}/{nid}"
                try:
                    notif = self.bus.get("org.kde.kdeconnect", child_path)
                    phone_title = getattr(notif, "title", "")
                    phone_text = getattr(notif, "text", "")
                    phone_app = getattr(notif, "appName", "")
                    
                    title_match = (title and phone_title and (title in phone_title or phone_title in title))
                    body_match = (body and phone_text and (body in phone_text or phone_text in body))
                    app_match = (title and phone_app and (title.lower() in phone_app.lower() or phone_app.lower() in title.lower()))
                    
                    if title_match or body_match or app_match:
                        if getattr(notif, "dismissable", True):
                            log_msg(f"Match found for '{title}', dismissing {nid}...")
                            notif.dismiss()
                            matched_ids.append(nid)
                except: continue
            
            if matched_ids and attempt < 3:
                # Verify and retry fuzzy for all matched IDs
                for mid in matched_ids:
                    threading.Timer(3.0, lambda m=mid: self.verify_and_retry_fuzzy(device_id, m, title, body, attempt)).start()
                return True
            elif matched_ids:
                return True
        except Exception as e:
            log_msg(f"Error in dismiss_fuzzy for device {device_id}: {e}")
        return False

    def verify_and_retry_fuzzy(self, device_id, phone_notif_id, title, body, attempt):
        try:
            notif_manager_path = f"/modules/kdeconnect/devices/{device_id}/notifications"
            notif_manager = self.bus.get("org.kde.kdeconnect", notif_manager_path)
            if phone_notif_id in notif_manager.activeNotifications():
                log_msg(f"Fuzzy-matched notification {phone_notif_id} still active, retrying dismissal...")
                # We don't call dismiss_fuzzy again here, we just retry the specific ID
                try:
                    notif_path = f"{notif_manager_path}/{phone_notif_id}"
                    notif = self.bus.get("org.kde.kdeconnect", notif_path)
                    notif.dismiss()
                    threading.Timer(3.0, lambda: self.verify_and_retry_fuzzy(device_id, phone_notif_id, title, body, attempt + 1)).start()
                except: pass
        except: pass

    def close_in_swaync(self, desktop_id):
        if not desktop_id: return
        log_msg(f"Closing desktop notification {desktop_id}...")
        self.closing_by_bridge.add(desktop_id)
        try:
            notif_server = self.bus.get('org.freedesktop.Notifications', '/org/freedesktop/Notifications')
            notif_server.CloseNotification(desktop_id)
        except Exception as e:
            log_msg(f"Error closing notification: {e}")
        finally:
            # We keep it in the set for a short time to catch the event
            threading.Timer(1.0, lambda: self.closing_by_bridge.discard(desktop_id)).start()

    def upgrade_to_critical(self, orig_desktop_id, app_name, title, body, icon, dev_id, p_id):
        """Close a low-urgency KDE Connect notification and re-fire it as Critical."""
        time.sleep(0.1)
        try:
            notif_server = self.bus.get('org.freedesktop.Notifications', '/org/freedesktop/Notifications')

            # Suppress phone-dismissal feedback for the original notification
            self.closing_by_bridge.add(orig_desktop_id)
            # Remove stale mapping before closing
            self.desktop_to_phone.pop(orig_desktop_id, None)
            if p_id and dev_id:
                self.phone_to_desktop.pop((dev_id, p_id), None)

            try:
                notif_server.CloseNotification(orig_desktop_id)
            except Exception as e:
                log_msg(f"Warning: could not close original notification {orig_desktop_id}: {e}")

            time.sleep(0.05)

            # Re-fire with Critical urgency. Add a bridge marker so the dbus monitor
            # skips re-processing this call and doesn't create a duplicate upgrade loop.
            hints = {
                'urgency': GLib.Variant('y', 2),                    # 2 = Critical
                'x-swaync-bridge-upgraded': GLib.Variant('b', True), # loop-guard
                'desktop-entry': GLib.Variant('s', 'org.kde.kdeconnect.daemon'),
            }

            new_id = notif_server.Notify(
                app_name or 'KDE Connect', 0, icon or 'kdeconnect',
                title or '', body or '', [], hints, 10000
            )

            # Store mapping for the new desktop_id
            self.bridge_owned_desktops.add(new_id)
            self.desktop_to_phone[new_id] = (dev_id, p_id, title, body)
            if p_id and dev_id:
                self.phone_to_desktop[(dev_id, p_id)] = new_id

            log_msg(f"Upgraded low-urgency -> Critical: Desktop {orig_desktop_id} -> {new_id} ('{title}')")
        except Exception as e:
            log_msg(f"Error in upgrade_to_critical for {orig_desktop_id}: {e}")

    def on_desktop_notification_closed(self, id, reason):
        if id in self.closing_by_bridge:
            log_msg(f"Desktop notification {id} closed by bridge (reason={reason}), skipping phone sync.")
            return

        log_msg(f"Desktop notification {id} closed (reason={reason}).")
        # Reasons: 1=Expired, 2=Dismissed, 3=Closed by app, 4=Undefined/ClearAll
        if reason in (2, 3, 4): 
            if id in self.desktop_to_phone:
                dev_id, p_id, title, body = self.desktop_to_phone.pop(id)
                self.phone_to_desktop.pop((dev_id, p_id), None)
                if p_id:
                    self.dismiss_on_phone(dev_id, p_id, title, body)
                else:
                    # Use fuzzy match on all devices
                    log_msg(f"Desktop notification {id} ('{title}') closed, trying fuzzy match on all devices.")
                    daemon, devices = self.get_device_info()
                    for dev in devices:
                        self.dismiss_fuzzy(dev, title, body)
            else:
                log_msg(f"No phone mapping for desktop ID {id}.")

    def on_phone_notification_removed(self, sender, object, iface, signal, params):
        # Params is (id,)
        phone_notif_id = params[0]
        match = re.search(r'/devices/([^/]+)/notifications', object)
        if match:
            device_id = match.group(1)
            log_msg(f"Phone notification removed: device={device_id}, id={phone_notif_id}")
            desktop_id = self.phone_to_desktop.pop((device_id, phone_notif_id), None)
            if desktop_id:
                self.desktop_to_phone.pop(desktop_id, None)
                self.close_in_swaync(desktop_id)

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
        icon_name = None
        urgency = 1       # 0=low, 1=normal, 2=critical
        is_bridge_notif = False
        string_idx = 0
        in_hints = False
        next_is_phone_id = False
        next_is_device_id = False
        next_is_urgency = False

        for line in process.stdout:
            line = line.strip()

            if "member=Notify" in line:
                m = re.search(r"serial=(\d+)", line)
                if m:
                    serial = m.group(1)
                    state = "PARSE_NOTIFY"
                    app_name = device_id = summary = body = phone_id = icon_name = None
                    urgency = 1
                    is_bridge_notif = False
                    string_idx = 0
                    in_hints = False
                    next_is_phone_id = False
                    next_is_device_id = False
                    next_is_urgency = False
                continue

            if "method return" in line:
                m = re.search(r"reply_serial=(\d+)", line)
                if m:
                    reply_serial = m.group(1)
                    state = "PARSE_RETURN"
                    serial = reply_serial
                continue

            if state == "PARSE_NOTIFY":
                # Detect hints array boundaries
                if "array [" in line and not in_hints:
                    in_hints = True
                if in_hints and line == "]":
                    in_hints = False

                if in_hints:
                    # Check for bridge loop-guard marker
                    if 'string "x-swaync-bridge-upgraded"' in line:
                        is_bridge_notif = True
                        continue
                    if 'string "x-kdeconnect-id"' in line:
                        next_is_phone_id = True
                        continue
                    if 'string "x-kde-origin-name"' in line:
                        next_is_device_id = True
                        continue
                    if 'string "urgency"' in line:
                        next_is_urgency = True
                        continue
                    if next_is_phone_id:
                        m = re.search(r'string "(.*)"', line)
                        if m:
                            phone_id = m.group(1)
                            next_is_phone_id = False
                        continue
                    if next_is_device_id:
                        m = re.search(r'string "(.*)"', line)
                        if m:
                            device_id = m.group(1)
                            next_is_device_id = False
                        continue
                    if next_is_urgency:
                        m = re.search(r'byte (\d+)', line)
                        if m:
                            urgency = int(m.group(1))
                            next_is_urgency = False
                        continue
                    continue

                m = re.search(r'string "(.*)"', line)
                if m:
                    val = m.group(1)
                    if string_idx == 0:   app_name = val
                    elif string_idx == 1: icon_name = val
                    elif string_idx == 2: summary = val
                    elif string_idx == 3: body = val
                    string_idx += 1

                if "int32" in line or "uint32" in line:
                    if string_idx >= 3:
                        if is_bridge_notif:
                            # This is our own re-fired notification; don't map it again
                            self.upgrade_serials.add(serial)
                            state = "IDLE"
                        else:
                            log_msg(f"Incoming Notify: app='{app_name}', summary='{summary}', phone_id='{phone_id}', device_hint='{device_id}'")
                            self.pending_notifs[serial] = (device_id, phone_id, summary, body, urgency, app_name, icon_name)
                            state = "IDLE"

            elif state == "PARSE_RETURN":
                m = re.search(r'uint32 (\d+)', line)
                if m:
                    desktop_id = int(m.group(1))
                    if serial in self.upgrade_serials:
                        # Re-fired by bridge - desktop_id already stored in upgrade_to_critical
                        self.upgrade_serials.discard(serial)
                    elif serial in self.pending_notifs:
                        info = self.pending_notifs.pop(serial)
                        dev_id, p_id, title, text, notif_urgency, orig_app, icon = info

                        # Only track KDE Connect notifications for phone sync.
                        # Tracking every app (Discord, etc.) causes false fuzzy-dismiss
                        # of phone notifications when unrelated desktop notifications time out.
                        if orig_app == 'KDE Connect' or p_id:
                            self.desktop_to_phone[desktop_id] = (dev_id, p_id, title, text)
                            if p_id:
                                self.phone_to_desktop[(dev_id, p_id)] = desktop_id
                                log_msg(f"Mapped: Desktop {desktop_id} <-> Phone {p_id} on {dev_id}")
                            else:
                                log_msg(f"Mapped (Fuzzy): Desktop {desktop_id} -> '{title}'")
                        else:
                            log_msg(f"Skipping non-KDE-Connect notification: app='{orig_app}', '{title}'")
                        # NOTE: upgrade_to_critical removed. swaync handles urgency via
                        # override-urgency:Critical in notification-visibility rules.
                        # The old close-then-refire caused a race that prevented popups showing.
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
        
        log_msg("SwayNC-KDEConnect Bridge (Two-Way Sync) started.")
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
