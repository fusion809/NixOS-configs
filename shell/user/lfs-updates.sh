source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"

# Main
upstream=true

# Pre-parse help to avoid any initial output
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "Usage: updates [options]"
        echo "Options:"
        echo "  --no-upstream  Check only LFS/BLFS book versions (disable upstream tracking) [DEFAULT is to track upstream]"
        echo "  -h, --help     Show this help message"
        exit 0
    fi
done

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --no-upstream) upstream=false ;;
    esac
    shift
done

# Synchronize clock to prevent fetch errors from time skew
if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
    echo "Synchronizing LFS guest clock to host..."
    ssh_lfs "sudo date -s '@$(date +%s)'" >/dev/null 2>&1
else
    echo "Synchronizing LFS clock from hardware clock..."
    sudo hwclock -s >/dev/null 2>&1
fi

REMOTE_LIST=$(lfs_get_remote_packages $([[ "$upstream" == "false" ]] && echo "--no-upstream") | tr -d '\r')
LOCAL_PKGS=$(lfs_get_local_packages | tr -d '\r')
# Identify packages with missing file inventories (line count <= 1)
BROKEN_PKGS=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do [ $(wc -l < "$f") -le 1 ] && basename "$f"; done' | tr -d '\r')
total_local=$(echo "$LOCAL_PKGS" | grep -v "^$" | wc -l)
count=0
tmp_lfs=$(mktemp -d)

while read -r local_pkg; do
    [[ -z "$local_pkg" ]] && continue
    
    (
        name=$(echo "$local_pkg" | sed -E 's#^([-a-zA-Z0-9_\+]+)-[0-9].*#\1#')
        # Fallback: handle VERSION_MISSING sentinel (lfs_get_local_packages emits name-VERSION_MISSING
        # for packages whose registry file is empty; the digit regex above won't match those).
        if [[ -z "$name" || "$name" == "$local_pkg" ]]; then
            name=$(echo "$local_pkg" | sed -E 's#-(VERSION_MISSING)$##')
        fi
        local_ver=$(echo "$local_pkg" | sed -E -e 's#^'"$name"'-##' -e 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##' | tr -d '[:space:]')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && exit 0
        is_broken=false
        if [[ "$local_ver" == "VERSION_MISSING" ]]; then
            is_broken=true
        elif echo "$BROKEN_PKGS" | grep -Fxq "$name" 2>/dev/null; then
            is_broken=true
        fi

        # is_broken already set above


        remote_pkg=$(echo "$REMOTE_LIST" | grep -Ei "^${name}-([0-9]|FAILED)" | head -n 1)
        if [[ -z "$remote_pkg" ]]; then
            # Try fuzzy match: strip numeric suffix like 6 in qt6 and try matching Qt- or qt6-
            name_base=$(echo "$name" | sed -E 's/[0-9]+$//')
            [[ -n "$name_base" ]] && remote_pkg=$(echo "$REMOTE_LIST" | grep -Ei "^${name_base}[0-9]?-([0-9]|FAILED)" | head -n 1)
        fi
        
        if [[ "$is_broken" == "true" ]]; then
            remote_ver="${local_ver}"
            if [[ -n "$remote_pkg" ]]; then
                remote_ver=$(echo "$remote_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*|FAILED)/\1/' | tr -d '[:space:]')
            fi
            label="[FILES MISSING]"
            [[ "$local_ver" == "VERSION_MISSING" ]] && label="[VERSION MISSING]"
            printf "%-30s | %-15s | %-15s %s\n" "$name" "$local_ver" "$remote_ver" "$label" > "$tmp_lfs/$name"
        elif [[ -n "$remote_pkg" ]]; then
            # Strip everything before the first hyphen followed by a digit or FAILED to get the version
            remote_ver=$(echo "$remote_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*|FAILED)/\1/' | tr -d '[:space:]')
            
            if [[ "$remote_ver" == "FAILED" ]]; then
                printf "%-30s | %-15s | %-15s [FAILED]\n" "$name" "$local_ver" "$remote_ver" > "$tmp_lfs/$name"
            else
                # Strip variant suffixes (e.g. -extra, -source) before numeric comparison
                local_base=$(echo "$local_ver" | sed -E 's#-[-a-zA-Z]+$##')
                remote_base=$(echo "$remote_ver" | sed -E 's#-[-a-zA-Z]+$##')

                if [[ "$local_base" != "$remote_base" ]]; then
                    higher=$(echo -e "$local_base\n$remote_base" | tr -d '\r' | sort -V | tail -n 1)
                    if [[ "$higher" == "$remote_base" ]]; then
                        printf "%-30s | %-15s | %-15s [UPDATE]\n" "$name" "$local_ver" "$remote_ver" > "$tmp_lfs/$name"
                    fi
                fi
            fi
        fi
    ) &
    
    count=$((count + 1))
    if (( count % 5 == 0 || count == total_local )); then
        lfs_progress_bar "$count" "$total_local" "Checking LFS/BLFS packages" >&2
    fi
done <<< "$LOCAL_PKGS"
wait

# Collect results
j=0
for f in "$tmp_lfs"/*; do
    if [[ -f "$f" ]]; then
        str+="$(cat "$f")"$'\n'
        j=$((j + 1))
    fi
done
rm -rf "$tmp_lfs"
lfs_progress_bar "$total_local" "$total_local" "LFS/BLFS checks complete" >&2
echo "" >&2
CUSTOM_UPDATES_RAW=$(lfs_check_custom_updates)
# Filter to only get lines that look like package updates (3 fields)
CUSTOM_UPDATES=$(echo "$CUSTOM_UPDATES_RAW" | grep -E '^[a-zA-Z0-9._+-]+ [^ ]+ [^ ]+$')
while IFS= read -r update_line; do
    [[ -z "$update_line" ]] && continue
    # Parse three fields
    read -r name local_ver remote_ver <<< "$update_line" || continue
    [[ -z "$name" || -z "$local_ver" || -z "$remote_ver" ]] && continue

    # Skip if this package was already reported by the book-package loop above
    # (avoids duplicates for packages that exist in both ~/lfs_packaging and BLFS book)
    if echo -e "$str" | grep -qE "^${name}[[:space:]]*\|" 2>/dev/null; then
        continue
    fi

    local_ver=$(printf '%s\n' "$local_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    remote_ver=$(printf '%s\n' "$remote_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    
    # Strip any possible hidden characters, ANSI codes, or whitespace
    local_ver=$(echo "$local_ver" | tr -d '[:space:]\r\n')
    remote_ver=$(echo "$remote_ver" | tr -d '[:space:]\r\n')


    # Skip if local and remote versions match exactly, or if both are MISSING
    if [[ "$local_ver" == "$remote_ver" ]] || [[ "$local_ver" == *"MISSING"* && "$remote_ver" == *"MISSING"* ]]; then
        # If it failed, we might want to know. Otherwise, skip all matches.
        [[ "$remote_ver" != *"FAILED"* ]] && continue
    fi
    
    # Format git hashes differently if they are 40 chars long
    if [[ ${#local_ver} -eq 40 ]]; then local_ver="${local_ver:0:7}" ; fi
    if [[ ${#remote_ver} -eq 40 ]]; then remote_ver="${remote_ver:0:7}" ; fi
    
    label="[UPDATE]"
    if echo "$BROKEN_PKGS" | grep -Fxq "$name" 2>/dev/null; then
        label="[FILES MISSING]"
    elif [[ "$remote_ver" == *"FAILED"* ]]; then
        label="[FAILED]"
    elif [[ "$remote_ver" == *"MISSING"* ]]; then
        label="[MISSING]"
    fi
    
    str+=$(printf "%-30s | %-15s | %-15s %s" "$name" "$local_ver" "$remote_ver" "$label")
    str+="\n"
    j=$((j + 1))
done <<< "$CUSTOM_UPDATES"

# Append any broken packages (missing inventories) that are not already in the list
while read -r bp; do
    [[ -z "$bp" ]] && continue
    bp=$(echo "$bp" | tr -d '[:space:]')
    [[ -z "$bp" ]] && continue
    
    # Check if already in the output list (avoid duplicate entries)
    if ! echo -e "$str" | grep -qE "^${bp}[[:space:]]*\|" 2>/dev/null; then
        local_ver=$(ssh_lfs "[ -f /var/lib/book-packages/$bp ] && head -n 1 /var/lib/book-packages/$bp; [ -f /var/lib/custom-packages/$bp ] && head -n 1 /var/lib/custom-packages/$bp" 2>/dev/null | tr -d '\r\n[:space:]')
        [[ -z "$local_ver" ]] && local_ver="none"
        remote_ver="$local_ver"
        
        # Check if there is an official remote version
        remote_pkg=$(echo "$REMOTE_LIST" | grep -Ei "^${bp}-([0-9]|FAILED)" | head -n 1)
        if [[ -n "$remote_pkg" ]]; then
            remote_ver=$(echo "$remote_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*|FAILED)/\1/' | tr -d '[:space:]')
        fi
        
        label="[FILES MISSING]"
        [[ "$local_ver" == "VERSION_MISSING" || "$local_ver" == "none" ]] && label="[VERSION MISSING]"
        
        str+=$(printf "%-30s | %-15s | %-15s %s" "$bp" "$local_ver" "$remote_ver" "$label")
        str+="\n"
        j=$((j + 1))
    fi
done <<< "$BROKEN_PKGS"

if [[ $j -gt 0 ]]; then
    startStr="--------------------------------------------------------------------------------\n"
    startStr+=$(printf "%-30s | %-15s | %-15s\n" "Package" "Local" "Remote")
    startStr+="\n--------------------------------------------------------------------------------\n"
    str="${startStr}$str"
fi
if [[ -z "$str" ]]; then
    echo "No updates available"
else
    echo -e "$str"
fi