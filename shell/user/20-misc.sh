function aroot {
	sudo $HOME/.local/bin/arch-chroot /arch /bin/zsh -c "/bin/su - fusion809"
}

function clipf {
	if `ps ax | grep wayland &> /dev/null`; then
		wl-copy < $1
	else
		xclip -sel clip < $1
	fi
}

function notif {
	lenOfStr=$(echo "$1" | awk -F ":" '{print NF-1}')
	while :
	do
		if ( [[ $lenOfStr == 1 ]] && [[ $(date +"%H:%M") == "$1" ]] ); then
			zenity --error --title="$2" --text "$2" && return
		elif ( [[ $lenOfStr == 2 ]] && [[ $(date +"$H:$M:$S") == "$1" ]] ); then
			zenity --error --title="$2" --text "$2" && return
		fi
	done
}

function octe {
	octave --eval "$@"
}

function rainbowfastfetch {
	hyfetch -p rainbow -b fastfetch --args='--localip-show-ipv4 false'
}

function sclipf {
	sudo xclip -sel clip < $1
}

function cpHyprNixScr {
	filename=$(ls $HOME/Pictures/Screenshots/ | grep -v "Pop" | grep -v "Gentoo" | grep "Screenshot_" | sort | tail -n 1)
	scrnShotDate=$(echo $filename | cut -d '_' -f 2)
	rm $IM/Hyprland/Hyprland_NixOS_*.png
	cp $HOME/Pictures/Screenshots/$filename $IM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	optipng -o7 $IM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	pushd -q $IM
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