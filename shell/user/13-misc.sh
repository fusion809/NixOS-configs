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

# Show the timestamp of the update run
# Arguments:
# The format to show the timestamp in. %r is the default and corresponds to the 
# The update run you want (optional); 1 (default) corresponds to the latest 
# update run. 
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

# Show updateLog
# Arguments:
# The number of the log to show. 1 is the default and corresponds to the latest 
# update log file. 2 is the second most recent log file and so far.
function updateLog {
	if ( [[ -n $1 ]] && [[ "$1" != "1" ]] ); then
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n $1 | head -n 1)
	else
		latestUpdateLog=$(ls $HOME/.cache/updates.* | tail -n 1)
	fi
	latestUpdatesRun "%r" $1
	if [[ ( -z "$1" || "$1" == "1" ) ]] && pgrep -f "shell/hyprland/updates" > /dev/null; then
		pid=$(pgrep -f "shell/hyprland/updates" | head -n 1)
		tail -n +1 -f ${pid:+--pid=$pid} "$latestUpdateLog"
	else
		cat "$latestUpdateLog"
	fi
}

# Log network transfers
# Arguments:
# duration in seconds
# output file (optional)
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

# Remove the $HOME/.cache/updates.* file for the most recent run of the 
# shell/hyprland/updates script
function rmLastUpdatesRun {
	rm $(ls $HOME/.cache/updates.* | tail -n 1)
}

# Compactify VMs
function compactVMs {
	# Requires psmisc (for fuser)
	find /data/VirtMachines -name "*.qcow2" -print0 | while IFS= read -r -d '' file; do
		if sudo fuser "$file" >/dev/null 2>&1; then
			echo "Skipping being-used image: $file"
		else
			echo "Compacting $file..."
			sudo virt-sparsify --in-place "$file"
		fi
	done
}

# List virtual machines in a table
# Arguments:
# -h, --headerless: Don't print header
# -t, --time: Sort by boot time
# -s, --size: Sort by size
function listVMs {
	local sort_by_time=false
	local sort_by_size=false
	if ! [[ "$1" == "-h" || "$1" == "--headerless" || "$2" == "-h" || "$2" == "--headerless" ]]; then
		printf "%-35s | %-26s | %s\n" "VM name" "Latest boot time" "Size"
		printf "%s\n" "------------------------------------+----------------------------+----------"
	fi
	if [[ "$1" == "-t" || "$1" == "--time" || "$2" == "-t" || "$2" == "--time" ]]; then
		sort_by_time=true
	elif [[ "$1" == "-s" || "$1" == "--size" || "$2" == "-s" || "$2" == "--size" ]]; then
		sort_by_size=true
	fi

	# Capture data for potentially sorting
	raw_output=$(
		{ sudo virsh list --all --name; virsh list --all --name; } | grep -v "^$" | sort | uniq | while read -r vm_name; do 
			log_file=""
			cmd_prefix=""

			# Check system log first
			if sudo test -f "/var/log/libvirt/qemu/${vm_name}.log"; then
				log_file="/var/log/libvirt/qemu/${vm_name}.log"
				cmd_prefix="sudo"
			# Check user log
			elif [ -f "$HOME/.cache/libvirt/qemu/log/${vm_name}.log" ]; then
				log_file="$HOME/.cache/libvirt/qemu/log/${vm_name}.log"
			fi
			
			ts=0
			formatted_date="No Log Found"
			
			if [ -n "$log_file" ]; then
				# Get last start time
				# Log format: 2026-01-04 02:29:01.116+0000: starting up ...
				raw_line=$($cmd_prefix grep "starting up libvirt version" "$log_file" | tail -n 1)
				
				if [ -n "$raw_line" ]; then
					# Extract timestamp: 2026-01-04 02:29:01.116+0000
					ts_str=$(echo "$raw_line" | awk '{print $1, $2}' | sed 's/:$//')
					# Convert to epoch for sorting
					ts=$(date -d "$ts_str" "+%s")
					
					# Format date: DayOfWeek DD/MM/YY HH:MM AM/PM
					# e.g., Sun 04/01/26 05:22 PM
					formatted_date=$(date -d "$ts_str" "+%I:%M:%S %p %a %d/%m/%y")
				else
					formatted_date="Never/Log Empty"
				fi
			fi

			# Get Disk Size
			disk_size="N/A"
			
			# Parse domblklist output line by line
			# Skip the first 2 lines (header)
			disk_path=""
			while read -r target source; do
				# source might be empty or "-" if valid path not found
				# skip empty, "-", or .iso (CD-ROM)
				if [[ -z "$source" ]] || [[ "$source" == "-" ]] || [[ "$source" == *.iso ]]; then
					continue
				fi
				
				# Check if file exists (using local checking or sudo if remote/root)
				# Note: source contains the full path from virsh, read puts the rest of the line in source
				if $cmd_prefix test -f "$source"; then
					disk_path="$source"
					break # Found first valid disk
				fi
			done < <($cmd_prefix virsh domblklist "$vm_name" | tail -n +3)

			if [ -n "$disk_path" ]; then
				disk_size=$($cmd_prefix du -hL "$disk_path" | cut -f1)
			fi
			
			# Separator: | (Time | Name | Display | Size)
			echo "${ts}|${vm_name}|${formatted_date}|${disk_size}"
		done
	)

	if [ "$sort_by_time" = true ]; then
		# Sort by timestamp (column 1) numerically ascending (Oldest first)
		echo "$raw_output" | sort -n -t '|' -k 1 | awk -F '|' '{ printf "%-35s | %-26s | %s\n", $2, $3, $4 }'
	elif [ "$sort_by_size" = true ]; then
		# Sort by size (column 4) human-readable ascending
		echo "$raw_output" | sort -h -t '|' -k 4 | awk -F '|' '{ printf "%-35s | %-26s | %s\n", $2, $3, $4 }'
	else
		# Default alphabetical (already sorted by input loop)
		echo "$raw_output" | awk -F '|' '{ printf "%-35s | %-26s | %s\n", $2, $3, $4 }'
	fi
}

function noVMs {
	listVMs -h | wc -l
}
# First argument is file extension
# Second is either empty or -d for descending order
function sortFiles {
	list=$(find . -maxdepth 1 -name "*.$1" -exec ls -lh {} +)
	if [[ "$2" == "-d" ]]; then
		list=$(echo $list | sort -k5 -rh)
	else
		list=$(echo $list | sort -k5 -h)
	fi
	echo $list
}

function download {
	cddf
	../download.py
}