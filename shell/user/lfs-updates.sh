source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/08-ssh.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/08-ssh.sh"

# Main
# Pre-parse help to avoid any initial output
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "Usage: updates [options]"
        echo "Options:"
        echo "  -v, --verbose  List all custom packages including up-to-date ones"
        echo "  -h, --help     Show this help message"
        exit 0
    fi
done

verbose=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v|--verbose) verbose=true ;;
    esac
    shift
done

# Get total package count for global progress percentage
total_custom_pkgs=$(ssh_lfs "find ~/lfs_packaging -mindepth 2 -maxdepth 2 -name 'build.sh' 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]\r')
total_custom_pkgs=${total_custom_pkgs:-0}
[[ "$total_custom_pkgs" -lt 1 ]] && total_custom_pkgs=1

# Identify packages with missing file inventories
BROKEN_PKGS=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do if [ $(wc -l < "$f") -le 1 ] || grep -q "BUILD_FAILED" "$f"; then basename "$f"; fi; done' | tr -d '\r')

# Run the parallel Python version checker on the VM, with global progress tracking
CUSTOM_UPDATES_RAW=$(lfs_check_custom_updates \
    --global-offset 0 --global-total "$total_custom_pkgs" --global-weight 1)
CUSTOM_UPDATES=$(echo "$CUSTOM_UPDATES_RAW" | grep -E '^[a-zA-Z0-9._+-]+ [^ ]+ [^ ]+$')

str=""
j=0

while IFS= read -r update_line; do
    [[ -z "$update_line" ]] && continue
    read -r name local_ver remote_ver <<< "$update_line" || continue
    [[ -z "$name" || -z "$local_ver" || -z "$remote_ver" ]] && continue

    local_ver=$(printf '%s\n' "$local_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    remote_ver=$(printf '%s\n' "$remote_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    local_ver=$(echo "$local_ver" | tr -d '[:space:]\r\n')
    remote_ver=$(echo "$remote_ver" | tr -d '[:space:]\r\n')

    # Abbreviate git hashes
    if [[ ${#local_ver} -eq 40 ]]; then local_ver="${local_ver:0:7}"; fi
    if [[ ${#remote_ver} -eq 40 ]]; then remote_ver="${remote_ver:0:7}"; fi

    label="[UPDATE]"
    if echo "$BROKEN_PKGS" | grep -Fxq "$name" 2>/dev/null; then
        label="[FILES MISSING]"
    elif [[ "$remote_ver" == *"FAILED"* ]]; then
        label="[FAILED]"
    elif [[ "$remote_ver" == *"MISSING"* ]]; then
        label="[MISSING]"
    elif [[ "$local_ver" == "$remote_ver" ]]; then
        label=""
    elif [[ "$local_ver" == "none" ]]; then
        label="[UPDATE]"
    else
        # Check if remote version is actually newer than local version
        # Normalize hyphens to periods for sort -V (e.g. 3-6-2 -> 3.6.2)
        local_norm="${local_ver//-/.}"
        remote_norm="${remote_ver//-/.}"
        
        if [[ "$local_norm" == "$remote_norm" ]]; then
            label=""
        elif [[ "$local_ver" =~ ^[0-9a-f]{7,40}$ ]] && [[ "$remote_ver" =~ ^[0-9a-f]{7,40}$ ]]; then
            # Git commit hashes - different hashes indicate a new commit
            label="[UPDATE]"
        else
            higher=$(printf '%s\n%s\n' "$local_norm" "$remote_norm" | sort -V | tail -n 1)
            if [[ "$higher" == "$remote_norm" && "$local_norm" != "$remote_norm" ]]; then
                label="[UPDATE]"
            else
                # Local version is newer than or equal to remote (e.g. ghostscript 10.08.0 vs 10.05.01)
                label=""
            fi
        fi
    fi

    # Skip up-to-date packages unless verbose
    if [[ "$verbose" != "true" ]]; then
        if [[ -z "$label" ]]; then
            continue
        fi
        if [[ "$local_ver" == "$remote_ver" ]] && [[ "$label" != *"MISSING"* ]] && [[ "$label" != *"FAILED"* ]]; then
            continue
        fi
    fi

    str+=$(printf "%-30s | %-15s | %-15s %s" "$name" "$local_ver" "$remote_ver" "$label")
    str+="\n"
    j=$((j + 1))
done <<< "$CUSTOM_UPDATES"

if [[ $j -gt 0 ]]; then
    startStr="--------------------------------------------------------------------------------\n"
    startStr+=$(printf "%-30s | %-15s | %-15s\n" "Package" "Local" "Remote")
    startStr+="\n--------------------------------------------------------------------------------\n"
    sorted_str=$(echo -e "$str" | grep -v "^$" | sort -f)
    str="${startStr}${sorted_str}\n"
fi
if [[ -z "$str" ]]; then
    echo "No updates available"
else
    echo -e "$str"
fi