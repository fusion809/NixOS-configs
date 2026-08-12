function aroot {
	sudo $HOME/.local/bin/arch-chroot /arch /bin/zsh -c "/bin/su - fusion809"
}

function cpHyprNixScr {
	filename=$(ls $HOME/Pictures/Screenshots/ | grep -v "Pop" | grep -v "Gentoo" | grep "Screenshot_" | sort | tail -n 1)
	scrnShotDate=$(echo $filename | cut -d '_' -f 2)
	rm $ARCHIM/Hyprland/Hyprland_NixOS_*.png
	cp $HOME/Pictures/Screenshots/$filename $ARCHIM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	optipng -o7 $ARCHIM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	pushd -q $ARCHIM
	push "Updating Hyprland NixOS screenshot"
	popd -q
}

# Find an old command in zsh_history
# Arguments:
# Regex to find the command
function oldCommands {
	find ~ -maxdepth 1 -name ".zsh_history*" -exec grep "$@" {} +
}

# Sort files by size
# Arguments:
# File extension
# Optional, or -d, --descend or --descending for descending order
function sortFiles {
	list=$(find . -maxdepth 1 -name "*.$1" -exec ls -lh {} +)
	if [[ "$2" == "-d" || "$2" == "--descend" || "$2" == "--descending" ]]; then
		list=$(echo $list | sort -k5 -rh)
	else
		list=$(echo $list | sort -k5 -h)
	fi
	echo $list
}

function prunedf {
	find ~/.files/ -name .git -prune -o -type d -print0 | xargs -0 fdupes -d -N
}

function compress_bike_rides() {
	local base_dir="$HOME/Pictures/Phone/Bike rides"
	if [ ! -d "$base_dir" ]; then
		base_dir="$HOME/Pictures/Phone/Bike Rides"
	fi

	local date="$1"
	if [ -z "$date" ]; then
		date=$(date +%Y-%m-%d)
		if [ ! -d "$base_dir/$date" ]; then
			local latest_dir=$(ls -1d "$base_dir"/*/ 2>/dev/null | sort -Vr | head -n 1)
			if [ -n "$latest_dir" ]; then
				date=$(basename "$latest_dir")
				echo "No folder found for today. Using most recent folder: $date"
			else
				echo "Error: No date provided and no folders found in $base_dir."
				return 1
			fi
		else
			echo "No date provided. Using today's date: $date"
		fi
	fi

	local original_dir="$base_dir/$date/Original/Best"
	local compressed_dir="$base_dir/$date/Compressed"

	if [ ! -d "$original_dir" ]; then
		echo "Error: Directory not found - $original_dir"
		return 1
	fi

	mkdir -p "$compressed_dir"

	cd "$original_dir" || exit 1
	find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" 2>/dev/null | while IFS= read -r img; do
		[ -n "$img" ] && [ -e "$img" ] || continue
		
		# Get file size in bytes
		size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img" 2>/dev/null)
		
		# 10MB = 10485760 bytes
		if [ "$size" -gt 10485760 ]; then
			echo "Compressing $img ($size bytes) to just under 10MB..."
			magick "$img" -define jpeg:extent=10400KB "$compressed_dir/$img"
		else
			echo "Skipping $img ($size bytes) - already under 10MB. Copying original."
			cp -n "$img" "$compressed_dir/$img"
		fi
	done
	echo 'Compression complete!'
}

function compress_walks() {
	local base_dir="$HOME/Pictures/Phone/Walks"
	if [ ! -d "$base_dir" ]; then
		base_dir="$HOME/Pictures/Phone/Walks"
	fi

	local date="$1"
	if [ -z "$date" ]; then
		date=$(date +%Y-%m-%d)
		if [ ! -d "$base_dir/$date" ]; then
			local latest_dir=$(ls -1d "$base_dir"/*/ 2>/dev/null | sort -Vr | head -n 1)
			if [ -n "$latest_dir" ]; then
				date=$(basename "$latest_dir")
				echo "No folder found for today. Using most recent folder: $date"
			else
				echo "Error: No date provided and no folders found in $base_dir."
				return 1
			fi
		else
			echo "No date provided. Using today's date: $date"
		fi
	fi

	local original_dir="$base_dir/$date/Original/Best"
	local compressed_dir="$base_dir/$date/Compressed"

	if [ ! -d "$original_dir" ]; then
		echo "Error: Directory not found - $original_dir"
		return 1
	fi

	mkdir -p "$compressed_dir"

	cd "$original_dir" || exit 1
	find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" 2>/dev/null | while IFS= read -r img; do
		[ -n "$img" ] && [ -e "$img" ] || continue
		
		# Get file size in bytes
		size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img" 2>/dev/null)
		
		# 10MB = 10485760 bytes
		if [ "$size" -gt 10485760 ]; then
			echo "Compressing $img ($size bytes) to just under 10MB..."
			magick "$img" -define jpeg:extent=10400KB "$compressed_dir/$img"
		else
			echo "Skipping $img ($size bytes) - already under 10MB. Copying original."
			cp -n "$img" "$compressed_dir/$img"
		fi
	done
	echo 'Compression complete!'
}

function compress_trike() {
	local base_dir="$HOME/Pictures/Phone/Trike rides"
	if [ ! -d "$base_dir" ]; then
		base_dir="$HOME/Pictures/Phone/Trike rides"
	fi

	local date="$1"
	if [ -z "$date" ]; then
		date=$(date +%Y-%m-%d)
		if [ ! -d "$base_dir/$date" ]; then
			local latest_dir=$(ls -1d "$base_dir"/*/ 2>/dev/null | sort -Vr | head -n 1)
			if [ -n "$latest_dir" ]; then
				date=$(basename "$latest_dir")
				echo "No folder found for today. Using most recent folder: $date"
			else
				echo "Error: No date provided and no folders found in $base_dir."
				return 1
			fi
		else
			echo "No date provided. Using today's date: $date"
		fi
	fi

	local original_dir="$base_dir/$date/Original/Best"
	local compressed_dir="$base_dir/$date/Compressed"

	if [ ! -d "$original_dir" ]; then
		echo "Error: Directory not found - $original_dir"
		return 1
	fi

	mkdir -p "$compressed_dir"

	cd "$original_dir" || exit 1
	find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -printf "%f\n" 2>/dev/null | while IFS= read -r img; do
		[ -n "$img" ] && [ -e "$img" ] || continue
		
		# Get file size in bytes
		size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img" 2>/dev/null)
		
		# 10MB = 10485760 bytes
		if [ "$size" -gt 10485760 ]; then
			echo "Compressing $img ($size bytes) to just under 10MB..."
			magick "$img" -define jpeg:extent=10400KB "$compressed_dir/$img"
		else
			echo "Skipping $img ($size bytes) - already under 10MB. Copying original."
			cp -n "$img" "$compressed_dir/$img"
		fi
	done
	echo 'Compression complete!'
}

function send_walk {
	source "$NIXCFG/shell/user/08-ssh.sh"
	source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

	local base_dir="$HOME/Pictures/Phone/Walks"
	local date="$1"

	if [ -z "$date" ]; then
		date=$(date +%Y-%m-%d)
		if [ ! -d "$base_dir/$date/Original/Best" ]; then
			local latest_dir=$(ls -1d "$base_dir"/*/ 2>/dev/null | sort -Vr | head -n 1)
			if [ -n "$latest_dir" ]; then
				date=$(basename "$latest_dir")
				echo "No Best folder found for today. Using most recent folder: $date"
			else
				echo "Error: No date provided and no walk folders found in $base_dir."
				return 1
			fi
		else
			echo "No date provided. Using today's date: $date"
		fi
	fi

	local src_dir="$base_dir/$date/Original/Boo_Best"
	find $src_dir -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) \
		-exec jpegoptim --strip-all --all-progressive {} +

	if [ ! -d "$src_dir" ]; then
		echo "Error: Directory not found - $src_dir"
		return 1
	fi

	echo "Sending contents of $src_dir to LFS VM ~/wallpapers..."
	local vm_name="Linux From Scratch"
	start_qemu_vm "$vm_name" || return 1
	local ip
	ip=$(get_vm_ip "$vm_name")
	local scp_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -O)
	if [ -f "$HOME/.config/vm_pass" ]; then
		sshpass -f "$HOME/.config/vm_pass" scp "${scp_opts[@]}" "$src_dir"/* "${USER}@${ip}:wallpapers/"
	else
		scp "${scp_opts[@]}" "$src_dir"/* "${USER}@${ip}:wallpapers/"
	fi
}

function send_trikes {
	source "$NIXCFG/shell/user/08-ssh.sh"
	source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

	local base_dir="$HOME/Pictures/Phone/Trike rides"
	local date="$1"

	if [ -z "$date" ]; then
		date=$(date +%Y-%m-%d)
		if [ ! -d "$base_dir/$date/Original/Best" ]; then
			local latest_dir=$(ls -1d "$base_dir"/*/ 2>/dev/null | sort -Vr | head -n 1)
			if [ -n "$latest_dir" ]; then
				date=$(basename "$latest_dir")
				echo "No Best folder found for today. Using most recent folder: $date"
			else
				echo "Error: No date provided and no walk folders found in $base_dir."
				return 1
			fi
		else
			echo "No date provided. Using today's date: $date"
		fi
	fi

	local src_dir="$base_dir/$date/Original/Boo_Best"
	find $src_dir -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) \
		-exec jpegoptim --strip-all --all-progressive {} +

	if [ ! -d "$src_dir" ]; then
		echo "Error: Directory not found - $src_dir"
		return 1
	fi

	echo "Sending contents of $src_dir to LFS VM ~/wallpapers..."
	local vm_name="Linux From Scratch"
	start_qemu_vm "$vm_name" || return 1
	local ip
	ip=$(get_vm_ip "$vm_name")
	local scp_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -O)
	if [ -f "$HOME/.config/vm_pass" ]; then
		sshpass -f "$HOME/.config/vm_pass" scp "${scp_opts[@]}" "$src_dir"/* "${USER}@${ip}:wallpapers/"
	else
		scp "${scp_opts[@]}" "$src_dir"/* "${USER}@${ip}:wallpapers/"
	fi
}

function walloptim {
	find ~/Pictures/ -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) \
		-exec jpegoptim --strip-all --all-progressive {} +
	sudo find /arch/usr/share/wallpapers -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) \
		-exec sudo jpegoptim --strip-all --all-progressive {} +
	sudo find /arch/usr/share/backgrounds -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) \
		-exec sudo jpegoptim --strip-all --all-progressive {} +
}
