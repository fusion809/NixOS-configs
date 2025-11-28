#!/run/current-system/sw/bin/bash
# Assuming we're installing to the whole specified disk.
export disk="$1"
echo "Disk is $disk..."
export suffix=$(echo $disk | sed 's|/dev/||g')
echo "Suffix is $suffix..."
export HOME=/home/fusion809
export CFG=$HOME/GitHub/mine/config
export NIXCFG=$CFG/NixOS-configs
export MNT_NIXCFG=/mnt$NIXCFG

function check_and_get_repo {
	if ( [[ -f ../.git/config ]] && `cat ../.git/config | grep url = git@github.com:fusion809/NixOS-configs &> /dev/null` ); then
		echo "Seems we are in a copy of NixOS-configs..." && return
	else
		echo "We are not in a copy of the repo."
		echo "Cloning..."
		git clone https://github.com/fusion809/NixOS-configs
		cd NixOS-configs/Shell
	fi
}
function backup_home {
	echo "Baking up home folder..."
	mkdir /data
	mount '/dev/disk/by-label/Data\x20partition' /data || echo "No data partition." && return
	mount "${disk}2" /mnt || echo "Unable to mount ${disk}2." && return
	cp -r /mnt$HOME /data/home-fusion809 || echo "Unable to copy home folder." && return
	umount /mnt -l
}

function partition_disk {
	# Wipe existing partition table and create GPT
	parted "$disk" --script mklabel gpt

	# Create 1GB EFI partition (1-1024 MiB)
	parted "$disk" --script mkpart ESP fat32 1MiB 1025MiB
	parted "$disk" --script set 1 esp on

	# Create Linux partition with remaining space
	parted "$disk" --script mkpart primary ext4 1025MiB 100%
}

function make_filesystems {
	mkfs.fat -F32 -n NIXOSEFI "${disk}1"      # EFI partition
	mkfs.ext4 -L nixos "${disk}2"  
}

function set_user_perms {
	chown fusion809:users "$1"
	chmod 700 "$1"
}

function setup_mounts_and_dirs {
	mount "${disk}2" /mnt
	mkdir -p /mnt/boot
	mkdir /mnt/home
	cp -r /data/home-fusion809 /mnt$HOME
	mkdir -p /mnt$CFG
	set_user_perms /mnt$HOME
	mount "${disk}1" /mnt/boot
}

function disk_uuid_path {
	ls -ld /dev/disk/by-uuid/* | grep "$1" | cut -d ' ' -f 9
}
function update_hwcfg {
	root=$(disk_uuid_path "${suffix}1")
	boot=$(disk_uuid_path "${suffix}2")
	sed -i \
    -e "22s|device = \"/dev/disk/by-uuid/[0-9a-z-]*\";|device = \"$root\";|g" \
    -e "26s|device = \"/dev/disk/by-uuid/[0-9A-Z-]*\";|device = \"$boot\";|g" \
    ../nix/hardware-configuration.nix
}

function install_nixos {
	if [[ -d $MNT_NIXCFG ]]; then
		rm -rf $MNT_NIXCFG
	fi
	cp -r ../../NixOS-configs $MNT_NIXCFG
	nixos-install --flake $MNT_NIXCFG/nix#nixos
}

if [[ $EUID -eq 0 ]]; then
	echo "Script is running as root..."
	check_and_get_repo
	backup_home
	read -p "Do you want to use auto-partitioning of the entire specified disk?" yn
	if [[ $yn == "y" || $yn == "Y" ]]; then
		partition_disk

		# Format the file systems
		make_filesystems
	else
		echo "Okay, assuming you've set up your partitions and file systems already."
		echo "The file systems can be created with mkfs.fat -F32 -n NIXOSEFI ${disk}1"
		echo "and mkfs.ext4 -L nixos ${disk}2"
	fi
	setup_mounts_and_dirs
	update_hwcfg
	install_nixos
	set_user_perms $MNT_NIXCFG
	ln -sf $NIXCFG/desktop/*.desktop /home/fusion809/.local/share/applications/
	echo "Installation should be finished now."
fi
