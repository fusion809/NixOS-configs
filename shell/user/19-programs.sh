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
			filename=$(echo "$page" | grep "<title>" | sed 's/<[/]*title>//g' | head -n 1 | python3 -c "import html,sys;print(html.unescape(sys.stdin.read().strip()))" | sed 's/\s*[-|]\s*[A-Za-z0-9]*\(.com\)\?\s*$//g')
			wget -c "$m3u8URL" -O "$filename.m3u8"
		) &
	done
	wait
	download
	# Stamp duration onto any mp4 files that don't already have one
	for mp4 in *.mp4; do
		[[ -f "$mp4" ]] || continue
		stem="${mp4%.*}"
		if [[ ! "$stem" =~ \([0-9]{1,2}[:\-][0-9]{1,2}([:\-][0-9]{1,2})?\) ]]; then
			duration=$(ffprobe -v error -show_entries format=duration \
				-of default=noprint_wrappers=1:nokey=1 -sexagesimal "$mp4" \
				| sed 's/\..*//' \
				| awk -F: '{ if ($1 == 0) print $2"-"$3; else print $0 }' \
				| sed 's/:/-/g')
			[[ -n "$duration" ]] && mv "$mp4" "$stem ($duration).mp4"
		fi
	done
}

function rename {
	if ls | grep mp4 &> /dev/null; then
		$HOME/.files/rename.sh
	fi
}