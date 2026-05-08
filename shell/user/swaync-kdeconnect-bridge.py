#!/usr/bin/env python3
import pydbus
from gi.repository import GLib
import sys

# This script bridges SwayNC and KDE Connect to allow bidirectional notification dismissal.
# It listens for the 'NotificationClosed' signal from the desktop and tells KDE Connect 
# to dismiss notifications on the phone via DBus.

def dismiss_phone_notifications():
    try:
        bus = pydbus.SessionBus()
        # Get the KDE Connect daemon
        try:
            daemon = bus.get("org.kde.kdeconnect", "/modules/kdeconnect")
        except:
            print("KDE Connect daemon not found on DBus.")
            return

        devices = daemon.devices()
        for device_id in devices:
            device_path = f"/modules/kdeconnect/devices/{device_id}"
            device = bus.get("org.kde.kdeconnect", device_path)
            
            # Only process reachable devices
            if not device.isReachable:
                continue
            
            print(f"Processing device: {device.name} ({device_id})")
            
            # Access the notifications module for this device
            notif_path = f"{device_path}/notifications"
            try:
                notif_manager = bus.get("org.kde.kdeconnect", notif_path)
                active_notifs = notif_manager.activeNotifications()
                
                if not active_notifs:
                    print("No active notifications found on phone.")
                    continue

                for notif_id in active_notifs:
                    child_path = f"{notif_path}/{notif_id}"
                    try:
                        notif = bus.get("org.kde.kdeconnect", child_path)
                        if notif.dismissable:
                            print(f"Dismissing notification {notif_id}: {notif.title}")
                            notif.dismiss()
                        else:
                            print(f"Notification {notif_id} is not dismissable.")
                    except Exception as e:
                        print(f"Error dismissing individual notification {notif_id}: {e}")
            except Exception as e:
                print(f"Error accessing notification manager for {device_id}: {e}")

    except Exception as e:
        print(f"Global error in dismissal logic: {e}")
    sys.stdout.flush()

def on_notification_closed(id, reason):
    print(f"Desktop notification closed: id={id}, reason={reason}")
    sys.stdout.flush()
    # Reason 2 usually means the user dismissed it (clicked 'x' or 'Clear All')
    if reason == 2:
        dismiss_phone_notifications()

def main():
    try:
        print("Connecting to Session Bus...")
        sys.stdout.flush()
        bus = pydbus.SessionBus()
        
        print("Getting Notifications proxy...")
        sys.stdout.flush()
        notifications = bus.get("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
        notifications.NotificationClosed.connect(on_notification_closed)
        
        print("SwayNC-KDEConnect bridge started and listening (DBus mode)...")
        sys.stdout.flush()
        
        loop = GLib.MainLoop()
        loop.run()
    except Exception as e:
        print(f"Failed to start bridge: {e}")
        sys.stdout.flush()
        sys.exit(1)

if __name__ == "__main__":
    main()
