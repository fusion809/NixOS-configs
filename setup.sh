#!/run/current-system/sw/bin/bash
disk=$1
parted $disk --script mklabel msdos   # Create a DOS (MBR) partition table
parted $disk --script mkpart primary ext4 1MiB 100%  # Create a primary partition using the whole disk
parted $disk --script set 1 boot on   # Set the partition as bootable
root="${disk}1"
root_label=$(cat hardware-configuration.nix | grep by-label | cut -d '/' -f 5 | cut -d '"' -f 1)
mkfs.ext4 -L $root_label $root
mount $root /mnt
mkdir -p /mnt/etc/nixos
cp *.nix /mnt/etc/nixos
VERSION=$(cat .git/HEAD | cut -d '/' -f 3)
if [[ $VERSION == "unstable" ]]; then
	HOMEVER="master"
else
	HOMEVER="release-${VERSION}"
fi
nix-channel --remove nixos
nix-channel --add https://nixos.org/channels/nixos-${VERSION} nixos
nix-channel --add https://github.com/nix-community/home-manager/archive/$HOMEVER.tar.gz home-manager
nix-channel --update
nixos-install
cp -r ../NixOS-configs /mnt/home/fusion809
nixos-enter -c "chown fusion809 /home/fusion809/NixOS-configs; chown fusion809 -R /home/fusion809/NixOS-configs"
nixos-enter -c "nix-channel --add https://github.com/nix-community/home-manager/archive/$HOMEVER.tar.gz home-manager" 
nixos-enter -c "nix-channel --update"
rm /mnt/etc/nixos/*
nixos-enter -c "ln -sf /home/fusion809/NixOS-configs/*.nix /etc/nixos"

