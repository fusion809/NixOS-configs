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

# Get total installed package count for the progress bar denominator
total_custom_pkgs=$(ssh_lfs "find /var/lib/custom-packages /var/lib/book-packages -maxdepth 1 -type f ! -name '.*' 2>/dev/null | grep -vE '/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$' | wc -l" 2>/dev/null | tr -d '[:space:]\r')
total_custom_pkgs=${total_custom_pkgs:-1}
[[ "$total_custom_pkgs" -lt 1 ]] && total_custom_pkgs=1

# Python now handles: BROKEN_PKGS detection, version comparison, labeling, and table formatting.
# We just stream its output and print the pre-built table — no bash per-package loop needed.
py_args=""
[[ "$verbose" == "true" ]] && py_args="--verbose"

table=""
in_table=false
count=0
total=$total_custom_pkgs

while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ $line == TOTAL:* ]]; then
        total="${line#TOTAL:}"
    elif [[ $line == PROGRESS:* ]]; then
        count=$((count + 1))
        n="${line#PROGRESS:}"
        lfs_progress_bar "$count" "$total" "Checking ~/lfs_packaging: $n" >&2
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

lfs_progress_bar "$total" "$total" "~/lfs_packaging checks complete" >&2
echo "" >&2

if [[ -z "$table" ]]; then
    echo "No updates available"
else
    printf '%s' "$table"
fi
