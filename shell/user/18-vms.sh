
# Compactify VMs
function get_vm_icon {
	local name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	case "$name_lower" in
		*debian*) echo "" ;;
		*alpine*) echo "" ;;
		*alma*) echo "";;
		*arch*|*bedrock*) echo "" ;;
		*crux*) echo "󰇥";;
		*fedora*) echo "" ;;
		*freebsd*) echo "" ;;
		*gentoo*) echo "" ;;
		*linux*mint*) echo "" ;;
		*mageia*) echo "" ;;
		*openbsd*) echo "" ;;
		*aeryn*) echo "";;
		*pld*) echo "";;
		*rhino*) echo "";;
		*netbsd*) echo "";;
		*haiku*) echo "󰌪";;
		*gobo*) echo "";;
		*aosc*) echo "";;
		*rlxos*) echo "󰬙";;
		*dragon*) echo "";;
		*q4os*) echo "";;
		*4mlinux*) echo "󱓸";; # DW screenshot wallpaper looked like a light pole
		*mocaccino*) echo "";;
		*openmamba*) echo "󱔎";; # snake logo as reminds me of black mamba snake
		*alt*|*pclinuxos*|*openmandriva*|*rosa*) echo "";;
		*red*) echo "";;
		*opensuse*|*tumbleweed*|*leap*) echo "" ;;
		*pop!_os*|*pop-os*) echo "" ;;
		*rocky*) echo "" ;;
		*slackware*) echo "" ;;
		*openindiana*|*smart*) echo "";; # Solaris family denoted with a solar eclipse logo
		*chimera*) echo "";; # Blender logo as it blends aspects of FreeBSD and Linux
		*solus*) echo "" ;;
		*ubuntu*) echo "" ;;
		*void*) echo "" ;;
		*zorin*) echo "" ;;
		*nixos*) echo "" ;;
		*manjaro*) echo "" ;;
		*kali*) echo "" ;;
		*centos*) echo "" ;;
		*raspbian*) echo "" ;;
		*elementary*) echo "" ;;
		*guix*) echo "" ;;
		*deepin*) echo "" ;;
		*devuan*) echo "" ;;
		*vanilla*) echo "";;
		*illumos*) echo "" ;;
		*redos*) echo "";;
		*reactos*) echo "";;
		*sabayon*) echo "" ;;
		*windows*) echo "" ;;
		*vine*) echo "";;
		*adelie*) echo "󰻀";;
		*venom*) echo "";;
		*pisi*) echo "";;
		*milis*) echo "󱜛";;
		*kolibri*) echo "󱗆";;
		*apple*|*macos*|*osx*) echo "" ;;
		*android*) echo "" ;;
		*exherbo*) echo "󰆚";;
		*gnome*) echo "" ;;
		*kde*) echo "" ;;
		*) echo "" ;; # Generic Linux/Unix
	esac
}


function get_vm_category {
	local name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	case "$name_lower" in
		# BSD
		*bsd*|*dragonfly*) echo "BSD" ;;
		
		# Solaris
		*solaris*|*illumos*|*omnios*|*smartos*|*openindiana*) echo "Solaris" ;;
		
		# Windows-like
		*windows*|*reactos*) echo "Windows-like" ;;

		# Linux - Debian-based
		*debian*|*ubuntu*|*mint*|*pop*|*kali*|*deepin*|*devuan*|*elementary*|*raspbian*|*zorin*|*vanilla*|*parrot*|*pureos*|*tails*|*rhino*|*q4os*) echo "Linux~Debian-based" ;;
		
		# Linux - Fedora-based
		*fedora*|*centos*|*rocky*|*alma*|*oracle*|*scientific*|*amazon*|*clear*|*qubes*) echo "Linux~Fedora-based" ;;
		
		# Linux - openSUSE-based
		*opensuse*|*tumbleweed*|*leap*|*gecko*) echo "Linux~openSUSE-based" ;;
		
		# Linux - Mandriva-based
		*mageia*|*pclinuxos*|*alt*|*openmandriva*|*rosa*) echo "Linux~Mandriva-based" ;;
		
		# Linux - Others that utilize DNF
		*openmamba*|*mariner*|*azure*|*red*) echo "Linux~Others that utilize DNF" ;;

		# Linux - Independent
		*arch*|*gentoo*|*slackware*|*nixos*|*vine*|*pisi*|*venom*|*adelie*|*void*|*solus*|*alpine*|*bedrock*|*crux*|*kiss*|*lfs*|*aosc*|*rlxos*|*chimera*|*4mlinux*|*gobo*|*aeryn*|*mocaccino*|*guix*|*gnome*) echo "Linux~Independent" ;;
		
		# Linux - Catch-all for others (assume independent or unknown Linux if it has linux/tux icon but not matched above? Or just 'Linux~Independent' fallback?)
		# For now, if we missed it but get_vm_icon returns linux icon, maybe?
		# But better to check name.
		*linux*|*tux*|*gnu*) echo "Linux~Independent" ;; 
		
		# Other
		*kolibri*) echo "Other" ;;
		
		# Other Unix-like (Haiki, Redox, Minix)
		*haiku*|*redox*|*minix*) echo "Other Unix-like" ;;

		# Fallback
		*) echo "Other Unix-like" ;;
	esac
}

# Helper to perform the compaction
function compactVM {
	local file="$1"
	# Check if in use
	if sudo fuser "$file" >/dev/null 2>&1; then
		echo "Skipping being-used image: $file"
	else
		echo "Compacting $file..."
		sudo virt-sparsify --in-place "$file"
	fi
}

function compactVMs {
	# Requires psmisc (for fuser)
	if [ "$#" -eq 0 ]; then
		find /data/VirtMachines -name "*.qcow2" -print0 | while IFS= read -r -d '' file; do
			compactVM "$file"
		done
	else
		for arg in "$@"; do
			local vm_name="$arg"
			# Check if mapping exists in vms array (sourced from 08-ssh.sh)
			if [ -n "${vms[$arg]}" ]; then
				vm_name="${vms[$arg]}"
			fi
			
			local file="/data/VirtMachines/${vm_name}.qcow2"
			if [ ! -f "$file" ]; then
				echo "Disk image not found: $file"
				continue
			fi
			
			compactVM "$file"
		done
	fi
}

function listVMs {
	local headerless=false
	local sort_by_time=false
	local sort_by_size=false
	local categorize=false
	local exclude_empty=false

	while [[ "$#" -gt 0 ]]; do
		case "$1" in
			--headerless) headerless=true ;;
			--time) sort_by_time=true ;;
			--size) sort_by_size=true ;;
			--categorize) categorize=true ;;
			--exclude-empty) exclude_empty=true ;;
			-*)
				for (( i=1; i<${#1}; i++ )); do
					case "${1:$i:1}" in
						c) categorize=true ;;
						e) exclude_empty=true ;;
						h) headerless=true ;;
						s) sort_by_size=true ;;
						t) sort_by_time=true ;;
					esac
				done
				;;
		esac
		shift
	done

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
			
			if [ "$exclude_empty" = true ] && [ "$disk_size_kb" -gt 0 ] && [ "$disk_size_kb" -le 25000 ]; then # 25000KB ~= 24MB, covers the ~21MB empty images
				continue
			fi

			# Separator: | (Timestamp | Name | Display | Size | SizeKB | Icon | Category)
			icon=$(get_vm_icon "$vm_name")
			category=$(get_vm_category "$vm_name")
			echo "${ts}|${vm_name}|${formatted_date}|${disk_size}|${disk_size_kb}|${icon}|${category}"
		done
	)

	# Awk script to calculate widths and print
	awk_script='
	BEGIN { 
		FS = "|";
		max_no = 2;  # "No"
		max_icon = 2; # "OS"
		max_name = 7; # "Virtual machine name"
		max_date = 16; # "Latest boot time"
		max_size = 4; # "Size"
	}
	{
		# Helper to calculate length
		l_name = length($2);
		l_date = length($3);
		l_size = length($4);
		l_icon = length($6);

		if (l_name > max_name) max_name = l_name;
		if (l_date > max_date) max_date = l_date;
		if (l_size > max_size) max_size = l_size;
		if (l_icon > max_icon) max_icon = l_icon;

		# Store data
		rows[NR, "ts"] = $1;
		rows[NR, "name"] = $2;
		rows[NR, "date"] = $3;
		rows[NR, "size"] = $4;
		rows[NR, "size_kb"] = $5;
		rows[NR, "icon"] = $6;
		rows[NR, "cat"] = $7;
	}
	END {
		# Update max_no based on number of rows
		l_no = length(NR);
		if (l_no > max_no) max_no = l_no;

		# Construct format string
		fmt = sprintf("%%-%ds | %%-%ds | %%-%ds | %%-%ds | %%s\n", max_no, max_icon, max_name, max_date);
		
		# Print Header if not headerless AND not categorized (categorized has its own headers)
		# Actually, lets keep main header always, but add category headers if needed?
		
		if (headerless != "true") {
			printf fmt, "No", "OS", "Virtual machine name", "Latest boot time", "Size"
			
			sep_no = ""; for(i=1;i<=max_no;i++) sep_no = sep_no "-";
			sep_icon = ""; for(i=1;i<=max_icon;i++) sep_icon = sep_icon "-";
			sep_name = ""; for(i=1;i<=max_name;i++) sep_name = sep_name "-";
			sep_date = ""; for(i=1;i<=max_date;i++) sep_date = sep_date "-";
			sep_size = ""; for(i=1;i<=max_size;i++) sep_size = sep_size "-";
			
			print sep_no "-+-" sep_icon "-+-" sep_name "-+-" sep_date "-+-" sep_size;
		}
		
		last_top_cat = "";
		last_sub_cat = "";

		# Print Rows
		for (i = 1; i <= NR; i++) {
			if (categorize == "true") {
				current_cat = rows[i, "cat"]
				split(current_cat, cat_parts, "~")
				top_cat = cat_parts[1]
				sub_cat = cat_parts[2]
				
				if (top_cat != last_top_cat) {
					print ""
					print "== " top_cat " =="
					last_top_cat = top_cat
					last_sub_cat = "" 
				}
				
				if (sub_cat != "" && sub_cat != last_sub_cat) {
					print "  -- " sub_cat " --"
					last_sub_cat = sub_cat
				}
			}

			printf fmt, i, rows[i, "icon"], rows[i, "name"], rows[i, "date"], rows[i, "size"];
			total_kb += rows[i, "size_kb"];
		}

		# Print Total if not headerless
		if (headerless != "true") {
			sep_no = ""; for(i=1;i<=max_no;i++) sep_no = sep_no "-";
			sep_icon = ""; for(i=1;i<=max_icon;i++) sep_icon = sep_icon "-";
			sep_name = ""; for(i=1;i<=max_name;i++) sep_name = sep_name "-";
			sep_date = ""; for(i=1;i<=max_date;i++) sep_date = sep_date "-";
			sep_size = ""; for(i=1;i<=max_size;i++) sep_size = sep_size "-";
			
			print sep_no "-+-" sep_icon "-+-" sep_name "-+-" sep_date "-+-" sep_size;
			
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
			
			printf fmt, "", "", "Total", "", human;
		}
	}'


	if [ "$categorize" = true ]; then
		if [ "$sort_by_time" = true ]; then
			# Category (7) -> Timestamp (1)
			echo "$raw_output" | sort -t '|' -k 7,7 -k 1,1n | awk -v headerless="$headerless" -v categorize="true" "$awk_script"
		elif [ "$sort_by_size" = true ]; then
			# Category (7) -> Size (4)
			echo "$raw_output" | sort -t '|' -k 7,7 -k 4,4h | awk -v headerless="$headerless" -v categorize="true" "$awk_script"
		else
			# Category (7) -> Name (2)
			echo "$raw_output" | sort -t '|' -k 7,7 -k 2,2 | awk -v headerless="$headerless" -v categorize="true" "$awk_script"
		fi
	elif [ "$sort_by_time" = true ]; then
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