# Source the common logic
source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"

# Main
upstream=false
if [[ "$1" == "--upstream" ]]; then
    upstream=true
fi

REMOTE_LIST=$(lfs_get_remote_packages $([[ "$upstream" == "true" ]] && echo "--upstream") | tr -d '\r')
LOCAL_PKGS=$(lfs_get_local_packages | tr -d '\r')

j=0;
while read -r local_pkg; do
    [[ -z "$local_pkg" ]] && continue
    
    name=$(echo "$local_pkg" | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
    local_ver=$(echo "$local_pkg" | sed -E "s/^$name-//")

    [[ -z "$name" || "$name" == "$local_pkg" ]] && continue

    remote_pkg=$(echo "$REMOTE_LIST" | grep -Ei "^${name}-([0-9])" | head -n 1)
    
    if [[ -n "$remote_pkg" ]]; then
        remote_ver=$(echo "$remote_pkg" | sed -E "s/^.{${#name}}-//I" | tr -d '\r')
        
        # Strip variant suffixes (e.g. -extra, -source) before numeric comparison
        local_base=$(echo "$local_ver" | sed -E 's/-[a-zA-Z]+$//')
        remote_base=$(echo "$remote_ver" | sed -E 's/-[a-zA-Z]+$//')

        if [[ "$local_base" != "$remote_base" ]]; then
            higher=$(echo -e "$local_base\n$remote_base" | tr -d '\r' | sort -V | tail -n 1)
            if [[ "$higher" == "$remote_base" ]]; then
                j+=1;
                str+=$(printf "%-30s | %-15s | %-15s [UPDATE]" "$name" "$local_ver" "$remote_ver")
                str+="\n"
            fi
        fi
    fi
done <<< "$LOCAL_PKGS"

CUSTOM_UPDATES=$(lfs_check_custom_updates)
while read -r update_line; do
    update_line=$(echo "$update_line" | tr -d '\r')
    [[ -z "$update_line" ]] && continue
    # Ensure there are exactly 3 fields (name local_ver remote_ver)
    fields=($(echo "$update_line"))
    if [[ ${#fields[@]} -ne 3 ]]; then continue; fi

    # update_line is "pkg_name local_ver remote_ver"
    name="${fields[0]}"
    local_ver="${fields[1]}"
    remote_ver="${fields[2]}"
    
    # Format git hashes differently if they are 40 chars long
    if [[ ${#local_ver} -eq 40 ]]; then local_ver="${local_ver:0:7}" ; fi
    if [[ ${#remote_ver} -eq 40 ]]; then remote_ver="${remote_ver:0:7}" ; fi
    
    str+=$(printf "%-30s | %-15s | %-15s [UPDATE]" "$name" "$local_ver" "$remote_ver")
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