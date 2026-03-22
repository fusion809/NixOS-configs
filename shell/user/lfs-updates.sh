source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"

# Main
upstream=false
if [[ "$1" == "--upstream" ]]; then
    upstream=true
fi

REMOTE_LIST=$(lfs_get_remote_packages $([[ "$upstream" == "true" ]] && echo "--upstream") | tr -d '\r')
LOCAL_PKGS=$(lfs_get_local_packages | tr -d '\r')
total_local=$(echo "$LOCAL_PKGS" | grep -v "^$" | wc -l)
count=0
tmp_lfs=$(mktemp -d)

while read -r local_pkg; do
    [[ -z "$local_pkg" ]] && continue
    
    (
        name=$(echo "$local_pkg" | sed -E 's#^([-a-zA-Z0-9_\+]+)-[0-9].*#\1#')
        local_ver=$(echo "$local_pkg" | sed -E -e 's#^'"$name"'-##' -e 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##' | tr -d '[:space:]')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && exit 0

        remote_pkg=$(echo "$REMOTE_LIST" | grep -Ei "^${name}-([0-9])" | head -n 1)
        
        if [[ -n "$remote_pkg" ]]; then
            # Strip the name prefix robustly using the known name (case-insensitive)
            remote_ver=$(echo "$remote_pkg" | sed -E 's#^'"$name"'-##I' | tr -d '[:space:]')
            
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
    ) &
    
    count=$((count + 1))
    if (( count % 5 == 0 || count == total_local )); then
        lfs_progress_bar "$count" "$total_local" "Checking LFS/BLFS packages" >&2
    fi
done <<< "$LOCAL_PKGS"
wait

# Collect results
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

    local_ver=$(printf '%s\n' "$local_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    remote_ver=$(printf '%s\n' "$remote_ver" | sed -E 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##')
    
    # Strip any possible hidden characters, ANSI codes, or whitespace
    local_ver=$(echo "$local_ver" | tr -d '[:space:]\r\n')
    remote_ver=$(echo "$remote_ver" | tr -d '[:space:]\r\n')

    [[ "$name" == *"nsis"* ]] && printf "DEBUG: name=%s local=%s remote=%s\n" "$name" "$local_ver" "$remote_ver" >&2

    # Skip if local and remote versions match exactly, or if both are MISSING
    if [[ "$local_ver" == "$remote_ver" ]] || [[ "$local_ver" == *"MISSING"* && "$remote_ver" == *"MISSING"* ]]; then
        # If it failed, we might want to know. Otherwise, skip all matches.
        [[ "$remote_ver" != *"FAILED"* ]] && continue
    fi
    
    # Format git hashes differently if they are 40 chars long
    if [[ ${#local_ver} -eq 40 ]]; then local_ver="${local_ver:0:7}" ; fi
    if [[ ${#remote_ver} -eq 40 ]]; then remote_ver="${remote_ver:0:7}" ; fi
    
    label="[UPDATE]"
    if [[ "$remote_ver" == *"FAILED"* ]]; then
        label="[FAILED]"
    elif [[ "$remote_ver" == *"MISSING"* ]]; then
        label="[MISSING]"
    fi
    
    str+=$(printf "%-30s | %-15s | %-15s %s" "$name" "$local_ver" "$remote_ver" "$label")
    str+="\n"
    j+=1;
done <<< "$CUSTOM_UPDATES"

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