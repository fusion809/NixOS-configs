# Source the common logic
source "$(dirname "${BASH_SOURCE[0]}")/21-lfs.sh"

# Main
REMOTE_LIST=$(lfs_get_remote_packages | tr -d '\r')
LOCAL_PKGS=$(lfs_get_local_packages | tr -d '\r')

echo "Checking for updates..."
echo "--------------------------------------------------------------------------------"
printf "%-30s | %-15s | %-15s\n" "Package" "Local" "Remote"
echo "--------------------------------------------------------------------------------"

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
                printf "%-30s | %-15s | %-15s [UPDATE]\n" "$name" "$local_ver" "$remote_ver"
            fi
        fi
    fi
done <<< "$LOCAL_PKGS"
