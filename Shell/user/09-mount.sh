function umount_arch {
  if `mountpoint -q /arch/boot`; then
    sudo umount /arch/boot -l
    sudo umount /arch -l
    touch ~/.cache/umount_arch
  fi
}

function mount_arch {
  if ! `mountpoint -q /arch` && ! [[ -f $HOME/.cache/umount_arch ]]; then
    sudo mount /dev/disk/by-label/arch /arch
    sudo mount /dev/disk/by-label/ARCHEFI /arch/boot
  elif [[ -f $HOME/.cache/umount_arch ]]; then
    echo '$HOME/.cache/umount_arch exists, so a Nix rebuild is likely happening...'
  fi
}

mount_arch

function mount_data {
  if ! `mountpoint -q /data`; then
    sudo mount '/dev/disk/by-label/Data\x20partition' /data
  fi
}

mount_data