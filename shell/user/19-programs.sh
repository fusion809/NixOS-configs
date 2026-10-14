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
			# Try hlsAuto first (old site format)
			m3u8URL=$(echo "$page" | grep "hlsAuto" | cut -d '"' -f 4 | sed 's/\\//g')
			# Fallback: grep for a src="..._TPL_.mp4..." or any src .mp4 URL (new site format)
			if [[ -z "$m3u8URL" ]]; then
				m3u8URL=$(echo "$page" | grep '.mp4"' | grep src | cut -d '"' -f 4 | sed 's/\\//g' | head -n 1)
				# Normalise protocol-relative URLs
				if [[ "$m3u8URL" == //* ]]; then
					m3u8URL="https:$m3u8URL"
				fi
			fi
			filename=$(echo "$page" | grep "<title>" | sed 's/<[/]*title>//g' | head -n 1 | python3 -c "import html,sys;print(html.unescape(sys.stdin.read().strip()))" | sed 's/\s*[-|]\s*[A-Za-z0-9]*\(.com\)\?\s*$//g')
			if [[ -z "$m3u8URL" ]]; then
				echo "ERROR: Could not find stream URL for $url" >&2
			else
				wget -c "$m3u8URL" -O "$filename.m3u8"
			fi
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

# Usage: from_tpl "My Video Title.mp4"
# The argument is the _TPL_.mp4 master playlist file you've already renamed.
# It picks the highest-bandwidth stream, downloads all segments via ffmpeg,
# and writes a final MP4 with a duration stamp, then removes the playlist file.
function from_tpl {
	local input="$1"
	if [[ -z "$input" || ! -f "$input" ]]; then
		echo "Usage: from_tpl <renamed_TPL_file.mp4>" >&2
		return 1
	fi

	local stem="${input%.*}"

	# Pick the URL of the highest-bandwidth variant from the master playlist
	local best_sub
	best_sub=$(awk '
		/^#EXT-X-STREAM-INF/ {
			match($0, /BANDWIDTH=([0-9]+)/, a)
			bw = a[1]+0
			getline url
			if (bw > max_bw) { max_bw = bw; best = url }
		}
		END { print best }
	' "$input")

	# Normalise protocol-relative URLs (//host/...) to https:
	if [[ "$best_sub" == //* ]]; then
		best_sub="https:$best_sub"
	fi

	if [[ -z "$best_sub" || "$best_sub" != http* ]]; then
		echo "ERROR: Could not find a valid stream URL in $input" >&2
		return 1
	fi

	echo "Best stream: $best_sub"

	local tmp_mp4="${stem}.tmp.$$.mp4"
	ffmpeg -protocol_whitelist file,http,https,tcp,tls,crypto \
		-i "$best_sub" -c copy -movflags +faststart "$tmp_mp4" || {
		echo "ERROR: ffmpeg failed." >&2
		rm -f "$tmp_mp4"
		return 1
	}

	# Stamp duration into filename if not already present
	local regex='\([0-9]{1,2}[:\-][0-9]{1,2}([:\-][0-9]{1,2})?\)'
	if [[ ! "$stem" =~ $regex ]]; then
		local duration
		duration=$(ffprobe -v error -show_entries format=duration \
			-of default=noprint_wrappers=1:nokey=1 -sexagesimal "$tmp_mp4" \
			| sed 's/\..*//' \
			| awk -F: '{ if ($1 == 0) print $2"-"$3; else print $0 }' \
			| sed 's/:/-/g')
		if [[ -n "$duration" ]]; then
			mv "$tmp_mp4" "$stem ($duration).mp4"
			echo "Done: $stem ($duration).mp4"
		else
			mv "$tmp_mp4" "$stem.mp4"
			echo "Done: $stem.mp4"
		fi
	else
		mv "$tmp_mp4" "$stem.mp4"
		echo "Done: $stem.mp4"
	fi

	# Remove the master playlist file
	rm -f "$input"
}