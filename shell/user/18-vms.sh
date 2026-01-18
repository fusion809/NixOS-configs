
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

function listVMs {
	local headerless=false
	local sort_by_time=false
	local sort_by_size=false

	if [[ "$1" == "-h" || "$1" == "--headerless" || "$2" == "-h" || "$2" == "--headerless" ]]; then
		headerless=true
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

	# Awk script to calculate widths and print
	awk_script='
	BEGIN { 
		FS = "|";
		max_no = 2;  # "No"
		max_name = 7; # "Virtual machine name"
		max_date = 16; # "Latest boot time"
		max_size = 4; # "Size"
	}
	{
		# Helper to calculate length
		l_name = length($2);
		l_date = length($3);
		l_size = length($4);

		if (l_name > max_name) max_name = l_name;
		if (l_date > max_date) max_date = l_date;
		if (l_size > max_size) max_size = l_size;

		# Store data
		rows[NR, "name"] = $2;
		rows[NR, "date"] = $3;
		rows[NR, "size"] = $4;
		rows[NR, "size_kb"] = $5;
	}
	END {
		# Update max_no based on number of rows
		l_no = length(NR);
		if (l_no > max_no) max_no = l_no;

		# Construct format string
		fmt = sprintf("%%-%ds | %%-%ds | %%-%ds | %%s\n", max_no, max_name, max_date);
		
		# Print Header if not headerless
		if (headerless != "true") {
			printf fmt, "No", "Virtual machine name", "Latest boot time", "Size"
			
			sep_no = ""; for(i=1;i<=max_no;i++) sep_no = sep_no "-";
			sep_name = ""; for(i=1;i<=max_name;i++) sep_name = sep_name "-";
			sep_date = ""; for(i=1;i<=max_date;i++) sep_date = sep_date "-";
			sep_size = ""; for(i=1;i<=max_size;i++) sep_size = sep_size "-";
			
			# Last column width for separator is max_size
			print sep_no "-+-" sep_name "-+-" sep_date "-+-" sep_size;
		}
		
		# Print Rows
		for (i = 1; i <= NR; i++) {
			printf fmt, i, rows[i, "name"], rows[i, "date"], rows[i, "size"];
			total_kb += rows[i, "size_kb"];
		}

		# Print Total if not headerless
		if (headerless != "true") {
			sep_no = ""; for(i=1;i<=max_no;i++) sep_no = sep_no "-";
			sep_name = ""; for(i=1;i<=max_name;i++) sep_name = sep_name "-";
			sep_date = ""; for(i=1;i<=max_date;i++) sep_date = sep_date "-";
			sep_size = ""; for(i=1;i<=max_size;i++) sep_size = sep_size "-";
			
			print sep_no "-+-" sep_name "-+-" sep_date "-+-" sep_size;
			
			val = total_kb * 1024
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
			
			printf fmt, "", "Total", "", human;
		}
	}'

	if [ "$sort_by_time" = true ]; then
		# Sort by timestamp (column 1) numerically descending (Newest first)
		echo "$raw_output" | sort -n -t '|' -k 1 | awk -v headerless="$headerless" "$awk_script"
	elif [ "$sort_by_size" = true ]; then
		# Sort by size (column 4) human-readable ascending
		echo "$raw_output" | sort -h -t '|' -k 4 | awk -v headerless="$headerless" "$awk_script"
	else
		# Default alphabetical
		echo "$raw_output" | awk -v headerless="$headerless" "$awk_script"
	fi
}

# Count up all VMs
function noVMs {
	listVMs -h | wc -l
}