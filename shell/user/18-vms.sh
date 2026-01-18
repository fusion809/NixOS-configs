
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
# -t, --time: Sort by most recent boot time
# -s, --size: Sort by size
function listVMs {
	local sort_by_time=false
	local sort_by_size=false
	local fmt="%-2s | %-31s | %-24s | %s\n"
	if ! [[ "$1" == "-h" || "$1" == "--headerless" || "$2" == "-h" || "$2" == "--headerless" ]]; then
		printf "$fmt" "No" "VM name" "Latest boot time" "Size"
		# Auto-calculate separator: replace spaces with - and | with +
		local sep=$(printf "$fmt" "" "" "" "          " | tr ' |' '-+')
		printf "%s\n" "$sep"
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
			disk_size_kb=0
			
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
				disk_size_kb=$($cmd_prefix du -kL "$disk_path" | cut -f1)
			fi
			
			# Separator: | (Timestamp | Name | Display | Size | SizeKB)
			echo "${ts}|${vm_name}|${formatted_date}|${disk_size}|${disk_size_kb}"
		done
	)

	# Awk script to print rows and calculate total
	awk_script='
	{ 
		sum += $5 * 1024; 
		printf fmt, NR, $2, $3, $4 
	} 
	END { 
		print "---+---------------------------------+--------------------------+-----------"
		
		val = sum
		split("B K M G T P", units, " ")
		u = 1
		while (val >= 1024 && u < 6) {
			val /= 1024
			u += 1
		}
		
		if (val < 10 && u > 1) {
			human = sprintf("%.1f%s", val, units[u])
		} else {
			human = sprintf("%.0f%s", val, units[u])
		}
		
		printf fmt, "", "Total", "", human
	}'

	if [ "$sort_by_time" = true ]; then
		# Sort by timestamp (column 1) numerically descending (Newest first)
		echo "$raw_output" | sort -nr -t '|' -k 1 | awk -F '|' -v fmt="$fmt" "$awk_script"
	elif [ "$sort_by_size" = true ]; then
		# Sort by size (column 4) human-readable ascending
		echo "$raw_output" | sort -h -t '|' -k 4 | awk -F '|' -v fmt="$fmt" "$awk_script"
	else
		# Default alphabetical (already sorted by input loop)
		echo "$raw_output" | awk -F '|' -v fmt="$fmt" "$awk_script"
	fi
}

# Count up all VMs
function noVMs {
	listVMs -h | wc -l
}