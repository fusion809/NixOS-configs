function clipf {
  if `ps ax | grep wayland &> /dev/null`; then
    wl-copy < $1
  else
    xclip -sel clip < $1
  fi
}

function rainbowfastfetch {
  hyfetch -p rainbow -b fastfetch --args='--localip-show-ipv4 false'
}

function sclipf {
  sudo xclip -sel clip < $1
}

function aroot {
  sudo $HOME/.local/bin/arch-chroot /arch /bin/zsh -c "/bin/su - fusion809"
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