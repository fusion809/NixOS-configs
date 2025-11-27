function blueRmCon {
    bluetoothctl remove "$1"
    bluetoothctl scan on
    bluetoothctl pair "$1"
    bluetoothctl connect "$1"
}

function blueCon {
    bluetoothctl scan on
    bluetoothctl pair "$1"
    bluetoothctl connect "$1"
}

if [[ -v $HYPRLAND_INSTANCE_SIGNATURE ]]; then
  if `bt-device -l | grep -i "00:A4:1C:F5:00:63"` &> /dev/null; then
    blueCon 00:A4:1C:F5:00:63
  fi
fi
