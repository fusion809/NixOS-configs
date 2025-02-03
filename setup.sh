#!/run/current-system/sw/bin/bash
disk=$1
parted $disk --script mklabel msdos   # Create a DOS (MBR) partition table
parted $disk --script mkpart primary ext4 1MiB 100%  # Create a primary partition using the whole disk
parted $disk --script set 1 boot on   # Set the partition as bootable
root="${disk}1"
root_label=$(cat hardware-configuration.nix | grep by-label | cut -d '/' -f 5)
mkfs.ext4 -L $root_label $root
mount $root /mnt
mkdir -p /mnt/etc/nixos
cp *.nix /mnt/etc/nixos
VERSION=$(cat configuration.nix | grep "system.stateVersion" | cut -d '"' -f 2)
nix-channel --remove nixos
nix-channel --add https://nixos.org/channels/nixos-${VERSION} nixos
nix-channel --add https://github.com/nix-community/home-manager/archive/release-${VERSION}.tar.gz home-manager
nix-channel --update
nixos-install
