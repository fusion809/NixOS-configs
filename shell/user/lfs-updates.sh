source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/08-ssh.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/08-ssh.sh"

# Main
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "Usage: updates [options]"
        echo "Options:"
        echo "  -v, --verbose          List all custom packages including up-to-date ones"
        echo "  --global-offset <n>    Global offset for progress percentage"
        echo "  --global-total <n>     Global total for progress percentage"
        echo "  --global-weight <n>    Global weight for progress percentage"
        echo "  -h, --help             Show this help message"
        exit 0
    fi
done

verbose=false
global_offset=0
global_total=0
global_weight=1

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v|--verbose) verbose=true ;;
        --global-offset) global_offset="$2"; shift ;;
        --global-total)  global_total="$2";  shift ;;
        --global-weight) global_weight="$2"; shift ;;
    esac
    shift
done

# Python handles: BROKEN_PKGS detection, version comparison, labeling, and table formatting.
# TOTAL: is reported by the script itself.
py_args=""
[[ "$verbose" == "true" ]] && py_args="--verbose"

table=""
in_table=false
count=0
total=1  # sensible default until TOTAL: arrives

while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ $line == TOTAL:* ]]; then
        total="${line#TOTAL:}"
        [[ "$total" -lt 1 ]] && total=1
    elif [[ $line == PROGRESS:* ]]; then
        count=$((count + 1))
        if (( global_total > 0 )); then
            gpct=$(( 100 * (global_offset + count * global_weight) / global_total ))
        else
            gpct=$(( 100 * count / total ))
        fi
        lfs_progress_bar "$count" "$total" "Checking ~/lfs_packaging     [Global ${gpct}%]" >&2
    elif [[ $line == TABLE_START ]]; then
        in_table=true
    elif [[ $line == TABLE_END ]]; then
        in_table=false
    elif [[ $line == TABLE_EMPTY ]]; then
        table=""
    elif [[ $line == RESULT:* ]]; then
        : # forwarded to lfs-update.sh consumers; ignored here
    elif [[ "$in_table" == true ]]; then
        table+="$line"$'\n'
    fi
done < <(ssh_lfs "python3 ~/.lfs_scripts/lfs-custom-updates.py $py_args" 2>/dev/null)

if [ "$total" -gt 0 ]; then
    lfs_progress_bar "$total" "$total" "~/lfs_packaging checks complete [Global 100%]" >&2
    echo "" >&2
fi

if [[ -z "$table" ]]; then
    echo "No updates available"
else
    printf '%s' "$table"
fi
