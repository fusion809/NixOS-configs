function clipf {
	if `ps ax | grep wayland &> /dev/null`; then
		wl-copy < $1
	else
		xclip -sel clip < $1
	fi
}

function sclipf {
	sudo xclip -sel clip < $1
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

function nix-run {
	nix-shell -p "$1" --run "$1 $2"
}
function gist {
	nix-run "gist" "$@"
}

function pstart {
	ps -eo pid,lstart | grep  "$1" | sed "s/\s*$1 //g"
}

function bm3u8 {
	cddf
	for url in "$@"; do
		(
			page=$(wget -cqO- "$url")
			m3u8URL=$(echo "$page" | grep "hlsAuto" | cut -d '"' -f 4 | sed 's/\\//g')
			filename=$(echo "$page" | grep "<title>" | sed 's/<[/]*title>//g' | head -n 1 | sed 's/\s*- [A-Za-z]*.com//g')
			wget -c "$m3u8URL" -O "$filename.m3u8"
		) &
	done
	wait
	download
}

function rename {
	if ls | grep mp4 &> /dev/null; then
		$HOME/.files/rename.sh
	fi
}