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

function lastUpdate {
	date -d "@$(cat $HOME/.cache/last_update)"
}

function cpHyprNixScr {
	filename=$(ls $HOME/Pictures/Screenshots/ | grep "Screenshot_" | sort | tail -n 1)
	scrnShotDate=$(echo $filename | cut -d '_' -f 2)
	rm $IM/Hyprland/Hyprland_NixOS_*.png
	cp $HOME/Pictures/Screenshots/$filename $IM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	optipng -o7 $IM/Hyprland/Hyprland_NixOS_$scrnShotDate.png
	pushd -q $IM
	push "Updating Hyprland NixOS screenshot"
	popd -q
}

function oldCommands {
	find ~ -maxdepth 1 -name ".zsh_history*" -exec grep "$@" {} +
}

function latestUpdatesRun {
	if [[ -n $2 ]]; then
		filename=$(ls "$HOME/.cache/updates."* | tail -n $2 | head -n 1)
	else
		filename=$(ls "$HOME/.cache/updates."* | tail -n 1)
	fi
	timestamp="${filename##*.}"
	if ! [[ -n $1 ]]; then
		echo $timestamp
	else
		date -d "@${timestamp}" +"$1"
	fi
}

function updateLog {
	if [[ -n $1 ]]; then
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n $1 | head -n 1)
	else
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n 1)
	fi
	latestUpdatesRun "%r" $1
	if ! ps ax | grep "shell/hyprland/updates" | grep -v grep &> /dev/null; then
		cat $latestUpdateLog
	else
		tail -f $latestUpdateLog
	fi
}
function logNetTransfers {
	duration=$1
	if [[ -z "$duration" ]]; then
		echo "Usage: logNetTransfers <seconds>"
		return 1
	fi
	
	outfile="${2:-$HOME/.cache/network-transfers.$(date +%s)}"
	
	echo "Capturing process activity with nethogs (auto-detecting all interfaces)..."
	# Run nethogs in trace mode monitoring ALL interfaces (-a)
	# We avoid passing specific interfaces because nethogs fails if any of them are in an unexpected state (even with -a).
	sudo timeout "$duration" nethogs -t -a -d 1 > "${outfile}.nethogs" 2> "${outfile}.nethogs.err" &
	nethogs_pid=$!
	
	# Capture interface stats from /proc/net/dev (kernel counters are ground truth for totals)
	cat /proc/net/dev > /tmp/net_start
	
	sleep "$duration"
	
	cat /proc/net/dev > /tmp/net_end
	
	# Cleanup background nethogs
	kill $nethogs_pid 2>/dev/null
	wait $nethogs_pid 2>/dev/null
	
	{
		echo "=== Interface Totals (Duration: ${duration}s) ==="
		awk 'FNR==NR{
			gsub(/:/, " ");
			if ($1 != "Inter-|" && $1 != "face") {
				rx[$1]=$2; 
				tx[$1]=$10;
			}
			next
		} 
		{
			gsub(/:/, " ");
			if ($1 != "Inter-|" && $1 != "face" && ($1 in rx)) {
				r_diff = $2 - rx[$1];
				t_diff = $10 - tx[$1];
				if (r_diff > 0 || t_diff > 0) {
					printf "Interface: %-10s Download: %10d bytes  Upload: %10d bytes\n", $1, r_diff, t_diff
				}
			}
		}' /tmp/net_start /tmp/net_end
		
		echo ""
		echo "=== Process Activity (Estimated from nethogs sampling) ==="
		echo "Process / PID                                                 Upload (KB)   Download (KB)"
		echo "------------------------------------------------------------  -------------  -------------"
		
		if [[ -s "${outfile}.nethogs" ]]; then
			awk '
			/Refreshing:/ {next}
			NF >= 3 {
				# nethogs (trace) format usually: Process_Name<tab>Sent<tab>Recv
				# But whitespace can be variable. 
				# We rely on the fact that the last two fields are numbers.
				
				recv = $NF;
				sent = $(NF-1);
				
				# Reconstruct process name from $1 to $(NF-2)
				proc_name = "";
				for (i=1; i<=NF-2; i++) {
					proc_name = proc_name $i " ";
				}
				
				# Clean up potentially loose nethogs formatting
				if (sent ~ /^[0-9.]+$/ && recv ~ /^[0-9.]+$/) {
					tot_sent[proc_name] += sent;
					tot_recv[proc_name] += recv;
				}
			}
			END {
				for (p in tot_sent) {
					# Filter out negligible traffic (e.g. < 1KB) to keep logs clean
					if (tot_sent[p] > 0 || tot_recv[p] > 0) {
						# Print numbers first for reliable sorting (Recv|Sent|Name)
						printf "%.2f|%.2f|%s\n", tot_recv[p], tot_sent[p], p
					}
				}
			}' "${outfile}.nethogs" | sort -t "|" -rnk1 | head -n 30 | awk -F "|" '{ printf "%-60s %13s %13s\n", $3, $2, $1 }'
			
			echo ""
			echo "(Note: Values are sum of KB/s samples. Precision depends on sampling rate.)"
		else
			echo "No process data captured."
			if [[ -s "${outfile}.nethogs.err" ]]; then
				echo "Nethogs error:"
				cat "${outfile}.nethogs.err"
			fi
		fi
	} > "$outfile"
	
	echo "" >> "$outfile"
	echo "--- Raw Nethogs Trace (First 50 lines) ---" >> "$outfile"
	if [[ -f "${outfile}.nethogs" ]]; then
		head -n 50 "${outfile}.nethogs" >> "$outfile"
	fi
	# Clean up raw file to save space, user can inspect head in main log
	rm "${outfile}.nethogs" "${outfile}.nethogs.err" /tmp/net_start /tmp/net_end
	
	echo "Network stats written to $outfile"
	# Display summary (everything before Raw Trace)
	sed '/--- Raw Nethogs Trace/q' "$outfile"
}

function rmLastUpdatesRun {
	rm $(ls $HOME/.cache/updates.* | tail -n 1)
}