# LFS/BLFS update management logic
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LFS_DEV_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_DEV_BOOK="https://linuxfromscratch.org/blfs/view/systemd"

# When SSH helpers are unavailable (e.g. running inside the VM), define ssh_lfs as a local passthrough
if ! declare -f ssh_lfs >/dev/null 2>&1; then
    ssh_lfs() {
        local cmd="$1"; shift
        case "$cmd" in
            "bash -s") bash -s "$@" ;;
            *) eval "$cmd" "$@" ;;
        esac
    }
fi

lfs_sync_to_vm() {
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    echo "Syncing LFS scripts to VM..."
    ssh_lfs "mkdir -p ~/.lfs_scripts"
    ssh_lfs "cat > ~/.lfs_scripts/21-lfs.sh" < "$NIXCFG/shell/user/21-lfs.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-updates.sh && chmod +x ~/.lfs_scripts/lfs-updates.sh" \
        < "$NIXCFG/shell/user/lfs-updates.sh"
    ssh_lfs "cat > ~/.lfs_scripts/lfs-vm-bootstrap.sh" \
        < "$NIXCFG/shell/user/lfs-vm-bootstrap.sh"
    ssh_lfs "cat > ~/.lfs_autobuild.sh && chmod +x ~/.lfs_autobuild.sh" \
        < "$NIXCFG/shell/user/lfs-autobuild.sh"
    ssh_lfs "cat > ~/.lfs_scripts/xorg_loop.awk" \
        < "$NIXCFG/shell/user/xorg_loop.awk"

    # Hook into ~/.bashrc if not already present
    ssh_lfs "grep -q 'lfs-vm-bootstrap.sh' ~/.bashrc || echo '# LFS update helpers' >> ~/.bashrc && echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.bashrc"
    ssh_lfs "touch ~/.zshrc && (grep -q 'lfs-vm-bootstrap.sh' ~/.zshrc || echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.zshrc)"
    echo "Sync complete. 'updates', 'update', and 'lfs_commit' are now available on the VM."
}

lfs_autobuild() {
    local logfile="/tmp/lfs-autobuild.log"
    # Truncate log if it exceeds 100MB to keep searches fast
    if [[ -f "$logfile" ]] && [[ $(stat -c%s "$logfile") -gt 104857600 ]]; then
        echo "--- Log truncated at $(date) (over 100MB) ---" > "$logfile"
    fi
    echo "--- Build session starting at $(date) ---" | tee -a "$logfile" >/dev/null
    
    # Only source SSH helpers and sync scripts when running on the host
    if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
        source "$NIXCFG/shell/user/08-ssh.sh"
        source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
        # Sync the latest host scripts to the VM, then execute it there.
        # This ensures the VM always uses the host's current version.
        ssh_lfs "cat > ~/.lfs_autobuild.sh && chmod +x ~/.lfs_autobuild.sh" \
            < "$NIXCFG/shell/user/lfs-autobuild.sh"
        ssh_lfs "cat > ~/.lfs_scripts/xorg_loop.awk" \
            < "$NIXCFG/shell/user/xorg_loop.awk"
        # Also keep lfs update scripts in sync
        ssh_lfs "mkdir -p ~/.lfs_scripts"
        ssh_lfs "cat > ~/.lfs_scripts/21-lfs.sh" < "$NIXCFG/shell/user/21-lfs.sh"
        ssh_lfs "cat > ~/.lfs_scripts/lfs-updates.sh && chmod +x ~/.lfs_scripts/lfs-updates.sh" \
            < "$NIXCFG/shell/user/lfs-updates.sh"
        ssh_lfs "cat > ~/.lfs_scripts/lfs-vm-bootstrap.sh" \
            < "$NIXCFG/shell/user/lfs-vm-bootstrap.sh"
        ssh_lfs "grep -q 'lfs-vm-bootstrap.sh' ~/.bashrc || echo 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null' >> ~/.bashrc"
        echo "Building $@..." | tee -a "$logfile" >/dev/null
        ssh_lfs "bash ~/.lfs_autobuild.sh $(printf '%q ' "$@")" 2>&1 | tee -a "$logfile"
        return ${PIPESTATUS[0]}
    else
        # Running directly on the VM, no syncing needed, just execute it locally
        echo "Building $@..." | tee -a "$logfile" >/dev/null
        bash ~/.lfs_autobuild.sh "$@" 2>&1 | tee -a "$logfile"
        return ${PIPESTATUS[0]}
    fi
}



lfs_progress_bar() {
    local current=$1
    local total=$2
    local prefix=$3
    local width=30
    local percent=$(( 100 * current / total ))
    local filled=$(( width * current / total ))
    local empty=$(( width - filled ))
    local bar=$(printf "%${filled}s" | tr ' ' '#')$(printf "%${empty}s" | tr ' ' '-')
    # Use fixed-width prefix and clear to end of line
    printf "\r%-45s [%s] %3d%% \033[K" "$prefix" "$bar" "$percent" >&2
}

# Function to clean up duplicate library versions in the LFS VM
cleanup_old_libraries() {
    ssh_lfs "source ~/.zshrc ; cleanup_old_libraries_gpt"
}

# Remove /usr/share/doc directories belonging to superseded package versions.
# A directory is deleted only when BOTH conditions hold:
#   1. A newer versioned directory for the same package base name exists in
#      /usr/share/doc  (e.g. cmake-3.29.0 alongside cmake-3.28.1)
#   2. The directory path is NOT listed in any file under
#      /var/lib/book-packages or /var/lib/custom-packages
#
# Examples:
#   zsh-5.9  alone (no zsh-5.10 present)  → always kept, regardless of registry
#   cmake-3.28.1 alongside cmake-3.29.0, not in registry → deleted
#   cmake-3.28.1 alongside cmake-3.29.0, listed in registry → kept
#
# Run directly inside the LFS VM, or use cleanup_old_doc_dirs from the host.
cleanup_old_doc_dirs_gpt() {
    local doc_root="/usr/share/doc"
    local dry_run=false
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=true ;;
            /*) doc_root="$arg" ;;
        esac
    done
    [[ "$dry_run" == "true" ]] && echo "[DRY RUN] No files will be deleted."
    echo "Scanning $doc_root for stale old-version directories..."

    # Pass 1: determine the newest versioned dir for each package base name.
    declare -A latest=()
    local dir base pkg_base
    while IFS= read -r dir; do
        base=$(basename "$dir")
        pkg_base=$(echo "$base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
        [[ "$pkg_base" == "$base" ]] && continue   # no version suffix → skip
        latest["$pkg_base"]="$dir"                 # sort -V: last wins = newest
    done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d | sort -V)

    # Pass 2: for every versioned dir that is NOT the newest for its base,
    # delete it only if it is not listed in any package registry file.
    local removed=0 kept_registered=0
    while IFS= read -r dir; do
        base=$(basename "$dir")
        pkg_base=$(echo "$base" | sed -E 's/-[0-9][0-9a-zA-Z._+-]*$//')
        [[ "$pkg_base" == "$base" ]] && continue

        # Condition 1: is there a newer dir for this package?
        [[ "${latest[$pkg_base]}" == "$dir" ]] && continue   # this IS the newest → keep

        # Condition 2: is this dir listed in any registry file?
        if grep -qrl "^${dir}" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null; then
            echo "Keeping $base (older but listed in registry)"
            kept_registered=$((kept_registered + 1))
            continue
        fi

        # Older AND not in registry → stale, safe to delete.
        echo "Removing stale: $base  (newer: $(basename "${latest[$pkg_base]}"))"
        if [[ "$dry_run" == "false" ]]; then
            sudo rm -rf -- "$dir"
        fi
        removed=$((removed + 1))
    done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -type d | sort -V)

    echo "---"
    echo "Removed          : $removed"
    echo "Kept (registered): $kept_registered"
}

# Host-side wrapper: ships the function to the LFS VM and runs it there.
cleanup_old_doc_dirs() {
    ssh_lfs "$(declare -f cleanup_old_doc_dirs_gpt); cleanup_old_doc_dirs_gpt $*"
}


cleanup_old_libraries_gpt() {
    local dep_cache="/tmp/lfs_dep_cache.txt"
    local pkg_cache="/tmp/lfs_pkg_cache.txt"
    
    echo "[LFS-AUTOBUILD] Generating dependency and package caches. This ensures accurate and fast cleanup..."
    
    # 1. Generate system-wide dependency cache (File -> Shared Libs)
    # We use -executable OR -name "*.so*" to catch both binaries and libs.
    # readelf -d extracts the (NEEDED) entries.
    find /usr/bin /usr/lib /lib /opt -type f \( -executable -o -name "*.so*" \) 2>/dev/null | \
    xargs -P$(nproc) -I{} sh -c "readelf -d '{}' 2>/dev/null | grep -q '(NEEDED)' && printf '%s: ' '{}' && readelf -d '{}' 2>/dev/null | grep '(NEEDED)' | sed -E 's/.*\[(.*)\].*/\1/' | tr '\n' ' ' && echo" > "$dep_cache"
    
    # 2. Generate package inventory mapping (File -> Package)
    # This maps every installed file back to the package that registered it in /var/lib/*-packages/
    grep -r "^/" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | sed -E 's|/var/lib/[^/]+-packages/([^:]+):(.*)|\2:\1|' > "$pkg_cache"

    echo "[LFS-AUTOBUILD] Caches generated. Evaluating system libraries..."

    # 3. Identify old versions (files only)
    # A version is old if a newer version with the same base name exists.
    local old_libs=($(find /usr/lib /lib -type f -name "lib*.so.[0-9]*" ! -name "*.dbg" ! -name "*-gdb.py" 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        sub(/\.so\.[0-9.]+$/, ".so", base)
        if (prev_base && base != prev_base) {
            for (i=1; i < prev_count; i++) print prev[i]
            prev_count = 0
        }
        prev[++prev_count] = $0
        prev_base = base
    }
    END {
        for (i=1; i < prev_count; i++) print prev[i]
    }'))

    # 3b. Identify old versions (directories only)
    local old_dirs=($(find /usr/lib /lib -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort -V \
    | awk '
    {
        base=$0
        sub(/-[0-9]+(\.[0-9]+)*$/, "", base)
        if (base != $0) {
            if (prev_base && base == prev_base) {
                for (i=1; i <= prev_count; i++) print prev[i]
                prev_count = 0
            } else {
                prev_count = 0
            }
            prev[++prev_count] = $0
            prev_base = base
        }
    }'))

    local old_items=("${old_libs[@]}" "${old_dirs[@]}")

    if [ ${#old_items[@]} -eq 0 ]; then
        echo "No old library versions found to clean up."
        rm -f "$dep_cache" "$pkg_cache"
        return
    fi

    # Track packages already rebuilt this session to avoid rebuilding the same
    # package dozens of times (e.g. once per old boost .so variant)
    declare -A rebuilt_packages=()

    for i in "${old_items[@]}"; do
        [ -e "$i" ] || continue
        echo "------------------------------------------------"
        
        local all_names=()
        if [ -d "$i" ]; then
            echo "Checking obsolete version (directory): $(basename "$i")"
            echo "Path: $i"
            local dir_basename=$(basename "$i")
            all_names=($(find "$i" -name "*.so*" -printf "%f\n" 2>/dev/null | sort -u))
            local outside_libs=($(find /usr/lib /lib -maxdepth 1 -name "lib${dir_basename}*.so*" -printf "%f\n" 2>/dev/null))
            all_names+=("${outside_libs[@]}")
        else
            echo "Checking obsolete version (file): $(basename "$i")"
            echo "Path: $i"
            local lib_basename=$(basename "$i")
            local link_names=($(find /usr/lib /lib -maxdepth 1 -type l -printf "%p %l\n" 2>/dev/null | grep -w "$lib_basename$" | awk '{print $1}'))
            all_names=("$lib_basename")
            for link in "${link_names[@]}"; do
                all_names+=($(basename "$link"))
            done
        fi
        
        # Ensure unique all_names and avoid empty checks
        all_names=($(printf "%s\n" "${all_names[@]}" | sort -u | grep -v "^$"))

        # 4. FAST dependency check for ANY of these names in the cache
        local deps=()
        if [ ${#all_names[@]} -gt 0 ]; then
            for name in "${all_names[@]}"; do
                # The cache format is "FILE: lib1 lib2 lib3 "
                local matches=($(grep " $name " "$dep_cache" | cut -d: -f1))
                [ ${#matches[@]} -gt 0 ] && deps+=("${matches[@]}")
            done
        fi
        # Unique list
        deps=($(printf "%s\n" "${deps[@]}" | sort -u))

        # Filter out deps that are inside the old directory itself
        if [ -d "$i" ] && [ ${#deps[@]} -gt 0 ]; then
            local outside_deps=()
            for d in "${deps[@]}"; do
                if [[ "$d" != "$i/"* ]]; then
                    outside_deps+=("$d")
                fi
            done
            deps=("${outside_deps[@]}")
        fi

        if [ ${#deps[@]} -eq 0 ]; then
            if [ -d "$i" ]; then
                echo "Result: Unused. Deleting directory $i..."
                sudo rm -rf -- "$i"
            else
                if [ ${#all_names[@]} -gt 1 ]; then
                    echo "Result: Unused (including symlinks: ${all_names[@]:1}). Deleting $i and its symlinks..."
                    for name in "${all_names[@]:1}"; do
                       sudo rm -f "/usr/lib/$name" "/lib/$name" 2>/dev/null
                    done
                else
                    echo "Result: Unused. Deleting $i..."
                fi
                sudo rm -f -- "$i"
            fi
            continue
        fi

        echo "Status: Library (or its symlinks) has ${#deps[@]} remaining dependents."
        echo "Names tracked: ${all_names[@]}"
        echo "Example dependents: ${deps[@]:0:3} ..."
        
        # 5. Robust package identification using the inventory cache
        local found_pkgs=()
        for d in "${deps[@]}"; do
            local p=$(grep "^$d:" "$pkg_cache" | cut -d: -f2)
            [ -n "$p" ] && found_pkgs+=("$p")
        done
        
        # Get unique package names
        local pkgs=($(printf "%s\n" "${found_pkgs[@]}" | sort -u))
        
        if [ ${#pkgs[@]} -eq 0 ]; then
            echo "Warning: No parent package found for ANY of the ${#deps[@]} dependents."
            echo "Checking if we should keep $i for safety."
            continue
        fi

        echo "Identified parent packages to rebuild: ${pkgs[@]}"
        
        local rebuild_success=true
        for pkg in "${pkgs[@]}"; do
            if [[ -n "${rebuilt_packages[$pkg]+x}" ]]; then
                echo "Skipping rebuild of '$pkg' (already rebuilt in this session)."
                continue
            fi
            echo "Action: Rebuilding $pkg to switch to newer library..."
            if lfs_autobuild --force "$pkg"; then
                rebuilt_packages[$pkg]=1
            else
                local item_name=$(basename "$i")
                echo "Error: Failed to rebuild $pkg. Cannot delete $item_name."
                rebuild_success=false
                break
            fi
        done

        if [ "$rebuild_success" = true ]; then
             echo "Verification: Re-checking dependencies for $(IFS=, ; echo "${all_names[*]}") after rebuilds..."
             local remaining=0
             local remaining_outsiders=()
             # Re-scan binaries from DISK (not stale cache) to get up-to-date ELF info.
             for d in "${deps[@]}"; do
                 [ -f "$d" ] || continue
                 for name in "${all_names[@]}"; do
                     if readelf -d "$d" 2>/dev/null | grep -q "\[$name\]"; then
                         # Check whether the binary belongs to a package we just rebuilt.
                         # If it does, the dependency is legitimate (the rebuilt package
                         # still needs this library, e.g. OpenSSL 4 ships libcrypto.so.3).
                         local owner=$(grep -rl "^$d$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | head -n1 | xargs basename 2>/dev/null)
                         if [ -n "$owner" ] && [[ -n "${rebuilt_packages[$owner]+x}" ]]; then
                             echo "Note: $d still depends on $name but '$owner' was just rebuilt — dependency is current."
                         else
                             echo "Persistence: $d still depends on $name"
                             remaining=1
                             remaining_outsiders+=("$d")
                         fi
                         break
                     fi
                 done
             done
             
             if [ $remaining -eq 0 ]; then
                 if [ -d "$i" ]; then
                     echo "Final Action: All dependencies cleared. Deleting directory $i."
                     sudo rm -rf -- "$i"
                 else
                     echo "Final Action: All dependencies cleared. Deleting $i and its symlinks."
                     for name in "${all_names[@]:1}"; do
                        sudo rm -f "/usr/lib/$name" "/lib/$name" 2>/dev/null
                     done
                     sudo rm -f -- "$i"
                 fi
             else
                 local blocker_pkgs=()
                 for d in "${remaining_outsiders[@]}"; do
                     local p=$(grep -rl "^$d$" /var/lib/book-packages /var/lib/custom-packages 2>/dev/null | head -n1 | xargs basename 2>/dev/null)
                     [ -n "$p" ] && blocker_pkgs+=("$p")
                 done
                 blocker_pkgs=($(printf "%s\n" "${blocker_pkgs[@]}" | sort -u))
                 echo "Final Action: Keeping $i (non-rebuilt binaries still linked: ${blocker_pkgs[*]:-unknown})."
             fi
        else
            echo "Final Action: Keeping $i (rebuilds incomplete or blocked)."
        fi
    done
    
    rm -f "$dep_cache" "$pkg_cache"
}

lfs_get_upstream_version() {
    local pkg="$1"
    case "$pkg" in
        rustc)
            curl -s https://static.rust-lang.org/dist/channel-rust-stable.toml | perl -ne 'if (/^\[pkg\.rust\]/) { $in=1 } elsif ($in && /^version\s*=\s*"([0-9.]+)/) { print $1; exit }'
            ;;
        llvm)
            local ver=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for rel in data:
        tag = rel.get("tag_name", "")
        if tag.startswith("llvmorg-"):
            v = tag.split("-")[1]
            if any(a.get("name") == f"llvm-project-{v}.src.tar.xz" for a in rel.get("assets", [])):
                print(v)
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
' 2>/dev/null)
            if [[ -z "$ver" ]]; then
                ver=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases/latest | perl -nle 'while (m{"tag_name":\s*"llvmorg-([0-9.]+)"}g) { print $1 }' | head -n 1)
                [[ -z "$ver" || "$ver" == "22.1.6" ]] && ver="22.1.5"
            fi
            echo "$ver"
            ;;
        libuv)
            curl -s -H "User-Agent: bash" https://api.github.com/repos/libuv/libuv/releases/latest | perl -nle 'while (m{"tag_name":\s*"v([0-9.]+)"}g) { print $1 }' | head -n 1
            ;;
        appstream)
            curl -s -H "User-Agent: bash" https://api.github.com/repos/ximion/appstream/tags | perl -nle 'while (m{"name":"v([0-9.]+)"}g) { print $1 }' | sort -V | tail -n 1
            ;;
        frameworks|frameworks6|extra-cmake-modules|breeze-icons)
            curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+(\.[0-9]+)?(?=/")}g) { my $v=$&; $v.=".0" if $v =~ /^\d+\.\d+$/; print $v }' | sort -V | tail -n 1
            ;;
        plasma|plasma-all)
            curl -sL https://download.kde.org/stable/plasma/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)
            curl -sL https://download.kde.org/stable/release-service/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        linux)
            curl -s -H "User-Agent: bash" https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | perl -nle 'while (m{[0-9.]+}g) { print $& }' | sort -Vr | head -n 1
            ;;
        libpeas)
            # Use GitLab API to fetch the latest guaranteed 1.x stable tag by strictly filtering for 'libpeas-' prefix
            curl -sL "https://gitlab.gnome.org/api/v4/projects/GNOME%2Flibpeas/repository/tags" | perl -nle 'while (m{"name":"libpeas-([0-9.]+)"}g) { print $1 }' | sort -V | tail -n 1
            ;;
        gnome-*|gsettings-desktop-schemas|yelp|mutter|nautilus|libpeas|gjs|glycin|tecla|gvfs|gexiv2|dconf|baobab|evince|gedit|epiphany|totem|tracker*|grilo*|folks|evolution*|gtksourceview*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|gjs|glib|glib2|glib-networking|glibmm|gmime|gnome-online-accounts|gnome-video-effects|graphene|gsound|gtk-doc|gtkmm*|harfbuzz|json-glib|libadwaita|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|libpeas|librsvg|libsecret|libsoup|mm-common|pango|pangomm|phodav|pygobject|rest|vte|xdg-desktop-portal-gnome|tinysparql|localsearch|dconf-editor|polkit-gnome|geocode-glib|libshumate|libsecret)
            local gnome_pkg="$pkg"
            [[ "$gnome_pkg" == "glib2" ]] && gnome_pkg="glib"
            local base_url="https://download.gnome.org/sources/$gnome_pkg"
            # Some packages might have different names on GNOME servers
            [[ "$gnome_pkg" == "libxml2" ]] && base_url="https://download.gnome.org/sources/libxml2"
            [[ "$gnome_pkg" == "libxslt" ]] && base_url="https://download.gnome.org/sources/libxslt"
            
            local major=$(curl -sL "$base_url/" | perl -nle 'while (m{href="\K[0-9]+(\.[0-9]+)*(?=/?")}sg) { print $& }' | sort -V | tail -n 1)
            if [[ -n "$major" ]]; then
                curl -sL "$base_url/$major/" | perl -nle 'while (m{href="\K'"$gnome_pkg"'-([0-9.]+)\.tar}sg) { print $1 }' | sort -V | tail -n 1
            fi
            ;;
        libgweather)
            # libgweather uses directory '40' on GNOME servers but actual tarballs are 4.x.x
            local base_url="https://download.gnome.org/sources/libgweather"
            local ldir=$(curl -sL "$base_url/" | perl -nle 'while (m{href="\K(?!3)[0-9]+(?=/?")}sg) { print $& }' | sort -V | tail -n 1)
            if [[ -n "$ldir" ]]; then
                curl -sL "$base_url/$ldir/" | perl -nle 'while (m{href="\Klibgweather-([0-9.]+)\.tar}sg) { print $1 }' | sort -V | tail -n 1
            fi
            ;;
        gtk3)
            # Use BLFS book directly for current version
            curl -s https://linuxfromscratch.org/blfs/view/systemd/x/gtk3.html | perl -nle 'while (m{GTK-([0-9]+\.[0-9]+\.[0-9]+)}g) { print $1; exit }'
            ;;
        libdisplay-info)
            curl -sL "https://gitlab.freedesktop.org/api/v4/projects/emersion%2Flibdisplay-info/repository/tags" | perl -nle 'while (m{"name":"([0-9.]+)"}g) { print $1 }' | sort -V | tail -n 1
            ;;
        libjxl)
            curl -s -H "User-Agent: bash" https://api.github.com/repos/libjxl/libjxl/releases/latest | perl -nle 'while (m{"tag_name":"v([0-9.]+)"}g) { print $1 }' | head -n 1
            ;;
    esac | grep -E '^[0-9]+(\.[0-9]+)+$' | head -n 1
}

lfs_get_remote_packages() {
    local upstream=true
    if [[ "$1" == "--no-upstream" ]]; then
        upstream=false
    fi

    KERNEL_VER=$(curl -s -H "User-Agent: bash" https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -Vr | head -n 1)
    JDK_MAJOR=$(curl -s https://jdk.java.net/ | perl -nle 'while (m{href="\./([0-9]+)}g) { print $1 }' | sort -rn | head -n 1)
    if [[ -n "$JDK_MAJOR" ]]; then
        JDK_TARBALL=$(curl -s "https://jdk.java.net/${JDK_MAJOR}/" | perl -nle 'while (m{(https://download\.java\.net/java/[^ "]+/openjdk-[0-9]+[^ "]*_linux-x64_bin\.tar\.gz)}g) { print $1 }' | head -n 1)
        JDK_VER=$(echo "$JDK_TARBALL" | perl -nle 'while (m{openjdk-([0-9a-zA-Z\+\.\-]+)_linux-x64_bin}g) { print $1 }')
        JDK_REMOTE="openjdk-${JDK_VER}_linux-x64_bin"
    fi
    # LFS packages scraping: Fix regex to include dots in versions (e.g. libxcrypt-4.5.2)
    local lfs_remote=$(curl -s "$LFS_DEV_BOOK/chapter03/packages.html" | tr -d '\r' | \
        grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.(tar\.[a-z0-9]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | \
        sed "s|^linux-[0-9.]*$|linux-${KERNEL_VER}|g" |\
        sort -u)

    # BLFS individual packages from long index
    local blfs_remote=$(curl -s "$BLFS_DEV_BOOK/longindex.html" | tr -d '\r' | \
        perl -0777 -ne 'while (/SpiderMonkey:.*?firefox-([0-9.]+)/gs) { print "spidermonkey-$1\n" } while (/>([a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+)<\/a>/gs) { print "$1\n" }' | \
        sed "/[Vv]im-[0-9.]*$/d" | \
        sort -u)

    # BLFS meta-pages for extra coverage (Xorg, KDE, etc.)
    local blfs_metapages=("x/x7lib.html" "x/x7app.html" "x/x7font.html" "x/x7driver.html" "kde/frameworks6.html" "kde/plasma-all.html" "kde/plasma.html")
    local blfs_extra=""
    local plasma_pkg_names=""
    local frameworks_pkg_names=""
    for page in "${blfs_metapages[@]}"; do
        local page_pkgs="$(curl -s "$BLFS_DEV_BOOK/$page" | tr -d '\r' | \
            grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.(tar\.[a-z0-9]+|zip)' | \
            sed 's/\.tar.*//; s/\.zip//' | sort -u)"
        blfs_extra+="${page_pkgs}"$'\n'
        
        if [[ "$page" == "kde/plasma"* ]]; then
            plasma_pkg_names+=$(echo "$page_pkgs" | sed -E 's/-[0-9].*//')
            plasma_pkg_names+=$'\n'
        elif [[ "$page" == "kde/frameworks6.html" ]]; then
            frameworks_pkg_names+=$(echo "$page_pkgs" | sed -E 's/-[0-9].*//')
            frameworks_pkg_names+=$'\n'
        fi
    done
    
    local all_pkgs=$(echo -e "${lfs_remote}\n${blfs_remote}\n${blfs_extra}\n${JDK_REMOTE}" | grep -v "^$" | sort -u | tr -d '\r')

    if [[ "$upstream" == "true" ]]; then
        local upstream_list=("linux" "rustc" "llvm" "libuv" "frameworks" "frameworks6" "extra-cmake-modules" "breeze-icons" "plasma" "konsole" "dolphin" "dolphin-plugins" "gwenview" "libkdcraw" "okular" "kdenlive" "gtk3" "gnome-shell" "glycin" "gjs" "nautilus" "libpeas" "tecla" "gnome-desktop" "gnome-shell-extensions" "gnome-session" "gnome-tweaks" "mutter" "yelp" "dconf" "gvfs" "gnome-control-center" "gnome-settings-daemon" "gnome-keyring" "gnome-bluetooth" "gnome-backgrounds" "gnome-user-docs" "xdg-desktop-portal-gnome" "gexiv2" "adwaita-icon-theme" "baobab" "evince" "gedit" "gnome-terminal" "pango" "glib2" "gsettings-desktop-schemas" "gnome-online-accounts" "gnome-menus" "gnome-autoar" "dconf-editor" "polkit-gnome" "geocode-glib" "evolution-data-server" "tracker" "tinysparql" "localsearch" "tracker-miners" "libshumate" "libjxl" "libdisplay-info" "appstream")
        local total=${#upstream_list[@]}
        local count=0
        local tmp_upstream=$(mktemp -d)
        
        for p in "${upstream_list[@]}"; do
            (
                uv=$(lfs_get_upstream_version "$p")
                if [[ -n "$uv" ]]; then
                    echo "${p}-${uv}" > "$tmp_upstream/$p"
                else
                    echo "${p}-FAILED" > "$tmp_upstream/$p"
                fi
            ) &
            
            # Show progress based on jobs started
            count=$((count + 1))
            lfs_progress_bar "$count" "$total" "Starting upstream check: $p" >&2
        done
        wait
        
        # Update progress to 100% on the SAME line
        lfs_progress_bar "$total" "$total" "Upstream checks complete" >&2
        echo "" >&2
        
        # Expand metapackage versions (plasma, frameworks) to all their constituent packages
        if [[ -f "$tmp_upstream/plasma" ]]; then
            local plasma_up_ver=$(cat "$tmp_upstream/plasma" | cut -d- -f2)
            # Scrape the directory listing directly to get the REAL list of components for this version
            local remote_dir_url="https://download.kde.org/stable/plasma/${plasma_up_ver}/"
            local tmp_listing="/tmp/plasma_listing.html"
            local http_code=$(curl -sL -w "%{http_code}" "$remote_dir_url" -o "$tmp_listing")
            if [[ "$http_code" == "200" ]]; then
                local dir_pkgs=$(grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.tar\.xz' "$tmp_listing" | sed -E 's/-[0-9].*//' | sort -u)
                if [[ -n "$dir_pkgs" ]]; then
                    plasma_pkg_names="$dir_pkgs"
                fi
            fi
            rm -f "$tmp_listing"
            for p in $(echo "$plasma_pkg_names" | sort -u); do
                [[ -n "$p" ]] && echo "${p}-${plasma_up_ver}" > "$tmp_upstream/$p"
            done
        fi
        
        if [[ -f "$tmp_upstream/frameworks6" || -f "$tmp_upstream/frameworks" ]]; then
            local fw_up_ver=""
            [[ -f "$tmp_upstream/frameworks6" ]] && fw_up_ver=$(cat "$tmp_upstream/frameworks6" | cut -d- -f2)
            [[ -z "$fw_up_ver" && -f "$tmp_upstream/frameworks" ]] && fw_up_ver=$(cat "$tmp_upstream/frameworks" | cut -d- -f2)
            if [[ -n "$fw_up_ver" ]]; then
                # Fetch frameworks directory listing
                local fw_mm=$(echo "$fw_up_ver" | cut -d. -f1,2)
                local remote_dir_url="https://download.kde.org/stable/frameworks/${fw_mm}/"
                local tmp_listing="/tmp/fw_listing.html"
                local http_code=$(curl -sL -w "%{http_code}" "$remote_dir_url" -o "$tmp_listing")
                if [[ "$http_code" == "200" ]]; then
                    local dir_pkgs=$(grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.tar\.xz' "$tmp_listing" | sed -E 's/-[0-9].*//' | sort -u)
                    if [[ -n "$dir_pkgs" ]]; then
                        frameworks_pkg_names="$dir_pkgs"
                    fi
                fi
                rm -f "$tmp_listing"
                for p in $(echo "$frameworks_pkg_names" | sort -u); do
                    [[ -n "$p" ]] && echo "${p}-${fw_up_ver}" > "$tmp_upstream/$p"
                done
            fi
        fi

        # Efficiently merge upstream updates by filtering out original versions in one pass if possible
        # or at least avoiding the quadratic echo/grep re-assignments.
        local replacements_regex=""
        for f in "$tmp_upstream"/*; do
            if [[ -f "$f" ]]; then
                local p=$(basename "$f")
                # Escape dots and other chars for safe regex
                local safe_p=$(echo "$p" | sed 's/\./\\./g')
                replacements_regex+="^${safe_p}-([0-9])|"
            fi
        done
        replacements_regex="${replacements_regex%|}"
        
        if [[ -n "$replacements_regex" ]]; then
            all_pkgs=$(echo "$all_pkgs" | grep -vEi "$replacements_regex")
            all_pkgs=$(echo -e "${all_pkgs}\n$(cat "$tmp_upstream"/* 2>/dev/null)")
        fi
        rm -rf "$tmp_upstream"
        all_pkgs=$(echo "$all_pkgs" | sort -u)
    fi

    echo "$all_pkgs" | grep -v "^$"
}

lfs_rebuild_missing_inventories() {
    # This function identifies packages in /var/lib/book-packages and /var/lib/custom-packages
    # that only contain the version (1 line) and lack a file list.
    # It then triggers lfs_autobuild -f to restore the inventory.
    
    [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]] && source "$NIXCFG/shell/user/08-ssh.sh"
    [[ -f "$NIXCFG/shell/user/18-vms.sh" ]] && source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    echo "Scanning for packages with missing file inventories..."
    # 1. Use -maxdepth 1 to avoid entering subdirectories like .git
    # 2. Match ! -name ".*" to ignore hidden files
    # 3. Exclude known metadata files via grep
    local missing_pkgs=$(ssh_lfs '
        find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | 
        grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | 
        while read -r f; do
            pkg_name=$(basename "$f")
            # Only consider it missing if it has <= 1 line AND no build is currently in progress for it
            if [ $(wc -l < "$f") -le 1 ]; then
                echo "$pkg_name"
            fi
        done
    ' | tr -d '\r')

    if [[ -z "$missing_pkgs" ]]; then
        echo "All packages have inventories recorded. No action needed."
        return 0
    fi

    echo "The following packages are missing inventories and will be rebuilt:"
    echo "$missing_pkgs"
    echo "--------------------------------------------------------------------------------"

    # Use a private file descriptor (9) to read the package list.
    # This prevents ssh (inside lfs_autobuild) from consuming the loop's stdin.
    while read -u 9 -r pkg; do
        [[ -z "$pkg" ]] && continue
        echo ">>> Restoring inventory for: $pkg"
        
        # Metapackage mapping
        actual_pkg="$pkg"
        case "$pkg" in
            # KDE components often part of frameworks6 or plasma
            kquickimageeditor|kquickimageditor|kirigami-addons|purpose|qqc2-desktop-style)
                actual_pkg="plasma-all"
                echo "  Mapping $pkg to metapackage: $actual_pkg"
                ;;
            xdg-desktop-portal-kde|plasma-desktop|plasma-workspace|kglobalacceld|kwayland-integration|plymouth-kcm|ocean-sound-theme|ksshaskpass|print-manager|plasma-disks|plasma-pa)
                actual_pkg="plasma-all"
                echo "  Mapping $pkg to metapackage: $actual_pkg"
                ;;
            # Xorg libraries/apps/fonts
            libX11|libXext|libXrender|libXft|libXi|libXau|libXdmcp|libxcb|xcb-util*)
                actual_pkg="xorg-lib"
                echo "  Mapping $pkg to metapackage: $actual_pkg"
                ;;
            xterm|xclock|xinit|xauth|iceauth|sessreg|setxkbmap|xauth|xbacklight|xcmsdb|xcursorgen|xdpyinfo|xdriinfo|xev|xgamma|xhost|xinput|xkbcomp|xkbevd|xkbutils|xkill|xlsatoms|xlsclients|xmodmap|xpr|xprop|xrandr|xrdb|xrefresh|xset|xsetroot|xvinfo|xwd|xwininfo|xwud)
                actual_pkg="xorg-app"
                echo "  Mapping $pkg to metapackage: $actual_pkg"
                ;;
            font-*)
                actual_pkg="xorg-font"
                echo "  Mapping $pkg to metapackage: $actual_pkg"
                ;;
        esac

        lfs_autobuild -f "$actual_pkg" --upstream
    done 9<<< "$missing_pkgs"
}

lfs_get_local_packages() {
    # Only source SSH helpers when running on the host (not inside the VM)
    [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]] && source "$NIXCFG/shell/user/08-ssh.sh"
    [[ -f "$NIXCFG/shell/user/18-vms.sh" ]] && source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    
    # Extract name-version from new inventory directories
    ssh_lfs '
        # 1. Official book packages (version is on the first line)
        if [ -d /var/lib/book-packages ]; then
            for f in /var/lib/book-packages/*; do
                [ -f "$f" ] || continue
                name=$(basename "$f")
                ver=$(head -n 1 "$f" | grep -v "^#" | tr -d "[:space:]")
                if [ -z "$ver" ]; then ver="VERSION_MISSING"; fi
                echo "${name}-${ver}"
            done
        fi
        # 2. Custom packages (version is the file content)
        if [ -d /var/lib/custom-packages ]; then
            for f in /var/lib/custom-packages/*; do
                [ -f "$f" ] || continue
                name=$(basename "$f")
                ver=$(head -n 1 "$f" | tr -d "[:space:]")
                if [ -z "$ver" ]; then ver="VERSION_MISSING"; fi
                echo "${name}-${ver}"
            done
        fi
    ' | sort -u | tr -d '\r'
}

lfs_pkg_dump() {
    local LOCAL_PKGS=$(lfs_get_local_packages | tr -d '\r')
    if [[ -z "$LOCAL_PKGS" ]]; then
        echo "No LFS packages found."
        return
    fi

    echo "------------------------------------------------------------"
    printf "%-35s | %-20s\n" "Package" "Version"
    echo "------------------------------------------------------------"

    while read -r local_pkg; do
        [[ -z "$local_pkg" ]] && continue
        
        name=$(echo "$local_pkg" | sed -E 's#^([-a-zA-Z0-9_\+]+)-[0-9].*#\1#')
        if [[ -z "$name" || "$name" == "$local_pkg" ]]; then
            name=$(echo "$local_pkg" | sed -E 's#-(VERSION_MISSING)$##')
        fi
        local_ver=$(echo "$local_pkg" | sed -E -e 's#^'"$name"'-##' -e 's#\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$##' | tr -d '[:space:]')

        printf "%-35s | %-20s\n" "$name" "$local_ver"
    done <<< "$LOCAL_PKGS"
    echo "------------------------------------------------------------"
}

lfs_map_bin_to_pkg() {
    local bin_path="$1"
    local bin_name=$(basename "$bin_path")
    
    # Heuristic 1: Exact match with bin name
    local local_pkgs=$(lfs_get_local_packages)
    local match=$(echo "$local_pkgs" | grep -Ei "^${bin_name}-([0-9])" | head -n 1 | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
    if [[ -n "$match" ]]; then
        echo "$match"
        return 0
    fi
    
    # Heuristic 2: Strip common suffixes/prefixes and match
    local base_name=$(echo "$bin_name" | sed -E 's/^lib//; s/\.so(\.[0-9]+)*$//; s/[-.0-9]+$//')
    if [[ -n "$base_name" ]]; then
        match=$(echo "$local_pkgs" | grep -Ei "^${base_name}[a-zA-Z0-9_\+\-]*-[0-9]" | head -n 1 | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
        if [[ -n "$match" ]]; then
            echo "$match"
            return 0
        fi
    fi

    # Heuristic 3: Special cases
    case "$bin_name" in
        gnome-terminal) echo "gnome-terminal" ;;
        vte-*) echo "vte" ;;
        python*) echo "python" ;;
        perl*) echo "perl" ;;
        *) echo "" ;;
    esac
}

lfs_strip() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    echo "Running binary stripping on LFS VM..."

    local strip_script=$(cat <<'EOF'
save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
             libc.so.6
             libthread_db.so.1
             libquadmath.so.0.0.0
             libstdc++.so.6.0.34
             libitm.so.1.0.0
             libatomic.so.1.2.0"

cd /usr/lib

for LIB in $save_usrlib; do
    objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
    cp $LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

online_usrbin="bash find strip"
online_usrlib="$(cd /usr/lib; find libbfd-*.so libsframe.so* libhistory.so* libncursesw.so* libm.so* libreadline.so* libz.so* libzstd.so* libnss*.so* -type f 2>/dev/null)"

for BIN in $online_usrbin; do
    cp /usr/bin/$BIN /tmp/$BIN
    strip --strip-debug /tmp/$BIN
    install -vm755 /tmp/$BIN /usr/bin
    rm /tmp/$BIN
done

for LIB in $online_usrlib; do
    cp /usr/lib/$LIB /tmp/$LIB
    strip --strip-debug /tmp/$LIB
    install -vm755 /tmp/$LIB /usr/lib
    rm /tmp/$LIB
done

for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
         $(find /usr/lib -type f -name \*.a)                 \
         $(find /usr/{bin,sbin,libexec} -type f); do
    case "$online_usrbin $online_usrlib $save_usrlib" in
        *$(basename $i)* )
            ;;
        * ) strip --strip-debug $i
            ;;
    esac
done

unset BIN LIB save_usrlib online_usrbin online_usrlib
EOF
)

    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: Would execute the following stripping commands on VM:"
        echo "$strip_script"
    else
        ssh_lfs "sudo bash -c '$(echo "$strip_script" | sed "s/'/'\\\\''/g")'"
    fi
}

lfs_check_custom_updates() {
    # Only source SSH helpers when running on the host
    [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]] && source "$NIXCFG/shell/user/08-ssh.sh"
    [[ -f "$NIXCFG/shell/user/18-vms.sh" ]] && source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    local script=$(cat <<'EOF'
    sudo mkdir -p /var/lib/custom-packages 2>/dev/null || true
    
    scripts=($(find ~/lfs_packaging -mindepth 2 -maxdepth 2 -name "build.sh" 2>/dev/null))
    total=${#scripts[@]}
    echo "TOTAL:$total"
    count=0
    max_jobs=100
    
    # We need a shared counter and results file
    mkdir -p /tmp/lfs_updates_parallel
    rm -f /tmp/lfs_updates_parallel/*
    echo 0 > /tmp/lfs_updates_parallel/counter

    for build_script in "${scripts[@]}"; do
        (
            pkg_dir=$(dirname "$build_script")
            pkg_basename=$(basename "$pkg_dir")
            
            # Output progress marker for local script to intercept
            echo "PROGRESS:$pkg_basename"

            name_line=$(grep -iE '^[a-zA-Z_]*name=' "$build_script" | head -n 1)
            if [ -n "$name_line" ]; then
                pkg_name=$(echo "$name_line" | cut -d= -f2 | tr -d '"' | tr -d "'")
            else
                pkg_name="$pkg_basename"
            fi
            
            local_ver="none"
            if [ -f "/var/lib/custom-packages/$pkg_name" ]; then
                local_ver=$(head -n 1 "/var/lib/custom-packages/$pkg_name" 2>/dev/null | tr -d '\r\n[:space:]' || echo "none")
            fi
            
            remote_ver=""
            status="OK"
            version_line_num=$(grep -niE '^[a-z_]*version=' "$build_script" | head -n 1 | cut -d: -f1)
            var_name=$(grep -iE '^[a-z_]*version=' "$build_script" | head -n 1 | cut -d= -f1)
            if [ -n "$version_line_num" ]; then
                eval_script="/tmp/eval_ver_${pkg_basename}_$$.sh"
                # Add PATH and other common environment variables to eval script
                # Use a safe default path plus existing path
                echo 'set +e' > "$eval_script"
                echo 'export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> "$eval_script"
                head -n "$version_line_num" "$build_script" | tr -d '\r' >> "$eval_script"
                echo "echo \"\$$var_name\"" >> "$eval_script"
                for attempt in 1 2 3; do
                    remote_ver=$(cd "$pkg_dir" && bash "$eval_script" 2>/dev/null | tail -n 1 | tr -d '\r\n[:space:]')
                    [ -n "$remote_ver" ] && break
                    [ "$attempt" -lt 3 ] && sleep 2
                done
                rm -f "$eval_script"
                if [ -z "$remote_ver" ]; then status="FAILED"; fi
            fi
            
            if [ -z "$remote_ver" ] && [ "$status" == "OK" ] && grep -q "git clone" "$build_script"; then
                repo_url=$(perl -nle 'while (m{git clone ([^ ]+)}g) { print $1 }' "$build_script" | head -n 1)
                if [ -n "$repo_url" ]; then
                    for attempt in 1 2 3; do
                        remote_ver=$(git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}')
                        [ -n "$remote_ver" ] && break
                        [ "$attempt" -lt 3 ] && sleep 2
                    done
                    if [ -z "$remote_ver" ]; then status="FAILED"; fi
                fi
            fi

            if [ -z "$remote_ver" ] && [ "$status" == "OK" ]; then status="MISSING"; fi
            
            if [ "$status" != "OK" ]; then
                echo "RESULT:$pkg_name $status $status"
            elif [ -n "$remote_ver" ]; then
                if [ "$local_ver" == "none" ]; then
                    if [ -f "/var/lib/custom-packages/$pkg_basename" ]; then
                        local_ver=$(head -n 1 "/var/lib/custom-packages/$pkg_basename" 2>/dev/null | tr -d '\r\n[:space:]' || echo "none")
                    fi
                fi
                if [ "$local_ver" != "$remote_ver" ]; then
                    if [[ "${#local_ver}" -ge 7 && "${#local_ver}" -le 12 && "${remote_ver#$local_ver}" != "$remote_ver" ]]; then
                        : # same
                    else
                        echo "RESULT:$pkg_name $local_ver $remote_ver"
                    fi
                fi
            fi
        ) &
        
        # Limit jobs
        while [ $(jobs -r | wc -l) -ge $max_jobs ]; do
            sleep 0.1
        done
    done
    wait
    rm -rf /tmp/lfs_updates_parallel
EOF
)
    local results=""
    local total=0
    local count=0

    while read -r line; do
        line=$(echo "$line" | tr -d '\r')
        if [[ $line == TOTAL:* ]]; then
            total="${line#TOTAL:}"
        elif [[ $line == PROGRESS:* ]]; then
            count=$((count + 1))
            local n="${line#PROGRESS:}"
            lfs_progress_bar "$count" "$total" "Checking ~/lfs_packaging $n" >&2
        elif [[ $line == RESULT:* ]]; then
            local result_data="${line#RESULT:}"
            # Format: pkg_name local_ver remote_ver -> strip extensions
            read -r pkg_name local_ver remote_ver <<< "$result_data"
            local_ver="${local_ver%.tar.xz}"
            local_ver="${local_ver%.tar.bz2}"
            local_ver="${local_ver%.tar.gz}"
            local_ver="${local_ver%.tar.lz}"
            local_ver="${local_ver%.tar.lzma}"
            local_ver="${local_ver%.tar.zst}"
            local_ver="${local_ver%.zip}"
            local_ver="${local_ver%.tgz}"
            local_ver="${local_ver%.tbz2}"
            local_ver="${local_ver%.patch}"
            
            remote_ver="${remote_ver%.tar.xz}"
            remote_ver="${remote_ver%.tar.bz2}"
            remote_ver="${remote_ver%.tar.gz}"
            remote_ver="${remote_ver%.tar.lz}"
            remote_ver="${remote_ver%.tar.lzma}"
            remote_ver="${remote_ver%.tar.zst}"
            remote_ver="${remote_ver%.zip}"
            remote_ver="${remote_ver%.tgz}"
            remote_ver="${remote_ver%.tbz2}"
            remote_ver="${remote_ver%.patch}"
            
            results+="$pkg_name $local_ver $remote_ver"$'\n'
        fi
    done < <(printf '%s\n' "$script" | ssh_lfs "bash -s")
    
    if [ "$total" -gt 0 ]; then
        lfs_progress_bar "$total" "$total" "~/lfs_packaging checks complete" >&2
        echo "" >&2
    fi
    # Build output line by line to avoid any formatting issues
    while read -r line; do
        [[ -z "$line" ]] && continue
        printf '%s\n' "$line"
    done <<< "$results"
}

lfs_update() {
    local dry_run=false
    local upstream=true
    
    # Pre-parse help to avoid any initial output
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            echo "Usage: update [options]"
            echo "Options:"
            echo "  --dry-run      Show what would be updated without downloading/building"
            echo "  --no-upstream  Check only LFS/BLFS book versions (disable upstream tracking) [DEFAULT is to track upstream]"
            echo "  -h, --help     Show this help message"
            return 0
        fi
    done

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --no-upstream) upstream=false ;;
            --upstream) upstream=true ;; # Hidden compatibility flag
        esac
        shift
    done

    # Synchronize clock to prevent build errors from time skew
    if [[ "$dry_run" == "false" ]]; then
        if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
            # Running from host: sync VM clock to host time
            echo "Synchronizing LFS guest clock to host..."
            [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]] && source "$NIXCFG/shell/user/08-ssh.sh"
            ssh_lfs "sudo date -s '@$(date +%s)'" >/dev/null 2>&1
        else
            # Running on VM: try to sync from hardware clock
            echo "Synchronizing LFS clock from hardware clock..."
            sudo hwclock -s >/dev/null 2>&1
        fi
    fi

    echo "Fetching remote package list $([[ "$upstream" == "true" ]] && echo "including upstream " )from Development books..."
    local remote_list=$(lfs_get_remote_packages $([[ "$upstream" == "false" ]] && echo "--no-upstream") | tr -d '\r')
    echo "Fetching local package list from VM..."
    local local_list=$(lfs_get_local_packages | sed 's/.tar.*//g' | tr -d '\r')
    
    # Packages with missing file inventories (≤1 line) need a forced rebuild regardless of version
    echo "Checking for packages with missing file inventories..."
    local broken_pkgs_raw=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do [ $(wc -l < "$f") -le 1 ] && basename "$f"; done' 2>/dev/null | tr -d '\r')
    local broken_pkgs=()
    while IFS= read -r bp; do
        [[ -z "$bp" ]] && continue
        broken_pkgs+=("$bp")
    done <<< "$broken_pkgs_raw"
    if [[ ${#broken_pkgs[@]} -gt 0 ]]; then
        echo "Packages with missing inventories that will be force-rebuilt: ${broken_pkgs[*]}"
    fi

    # DEBUG: echo "Remote list size: $(echo "$remote_list" | wc -l), Local list size: $(echo "$local_list" | wc -l)"

    echo "Checking for updates..."
    local updates=()
    local update_msgs=()

    while read -r local_pkg; do
        [[ -z "$local_pkg" ]] && continue
        
        # Exclude auxiliary texlive archives to prevent false positive updates against texlive-*-source
        if [[ "$local_pkg" == texlive-*-texmf* ]] || [[ "$local_pkg" == texlive-*-extra* ]]; then
            continue
        fi

        local name=$(echo "$local_pkg" | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
        local local_ver=$(echo "$local_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*)/\1/; s/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//' | tr -d '[:space:]')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && continue

        # Find matching package in remote list (case-insensitive)
        local remote_pkg=$(echo "$remote_list" | grep -Ei "^${name}-([0-9]|FAILED)" | head -n 1)
        if [[ -z "$remote_pkg" ]]; then
            # Try fuzzy match: strip numeric suffix like 3 in gtk3 and try matching GTK-
            local name_base=$(echo "$name" | sed -E 's/[0-9]+$//')
            [[ -n "$name_base" ]] && remote_pkg=$(echo "$remote_list" | grep -Ei "^${name_base}[0-9]?-([0-9]|FAILED)" | head -n 1)
        fi
        
        # if [[ "$name" =~ "gnome" ]] || [[ "$name" == "adwaita-icon-theme" ]] || [[ "$name" == "mutter" ]] || [[ "$name" == "nautilus" ]]; then
        #      echo "DEBUG: Checked $name. Local: $local_ver, Remote Pkg Found: ${remote_pkg:-NONE}"
        # fi

        if [[ -n "$remote_pkg" ]]; then
            # Extract version carefully (anything after the first hyphen followed by a digit or FAILED)
            local remote_ver=$(echo "$remote_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*|FAILED)/\1/; s/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//' | tr -d '[:space:]')
            
            if [[ "$remote_ver" == "FAILED" ]]; then
                echo "Failed to get upstream version for: $name"
                continue
            fi
            
            # Strip variant suffixes (e.g. -extra, -source) before numeric comparison
            local local_base=$(echo "$local_ver" | sed -E 's/-[a-zA-Z]+$//')
            local remote_base=$(echo "$remote_ver" | sed -E 's/-[a-zA-Z]+$//')

            if [[ "$local_base" != "$remote_base" ]]; then
                local higher=$(echo -e "$local_base\n$remote_base" | sort -V | tail -n 1)
                if [[ "$higher" == "$remote_base" ]]; then
                    echo "Found update: $name: $local_ver->$remote_ver"
                    # Exclude metapackages from updates to prevent redundant build cycles
                    if [[ "$name" != "plasma-all" && "$name" != "plasma" && "$name" != "frameworks6" && "$name" != "frameworks" ]]; then
                        updates+=("$name")
                        update_msgs+=("${name}: ${local_ver}->${remote_ver}")
                    fi
                fi
            fi
        fi
    done <<< "$local_list"

    # Also check custom updates
    local custom_updates_list=()
    # Call function and capture output, suppressing stderr
    local custom_updates=$(lfs_check_custom_updates 2>/dev/null)
    
    # Process each line of output
    while IFS= read -r update_line; do
        # Skip empty lines
        [[ -z "$update_line" ]] && continue
        
        # Use read to split fields cleanly
        local name local_ver remote_ver
        read -r name local_ver remote_ver <<< "$update_line" || continue
        
        # Validate we got all three fields
        [[ -z "$name" || -z "$local_ver" || -z "$remote_ver" ]] && continue
        
        # Skip if both are MISSING (not an update)
        if [[ "$local_ver" == "MISSING" && "$remote_ver" == "MISSING" ]]; then
            continue
        fi
        
        # Strip file extensions
        local_ver=$(printf '%s\n' "$local_ver" | sed -E 's/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//')
        remote_ver=$(printf '%s\n' "$remote_ver" | sed -E 's/\.(tar\.(xz|bz2|gz|lz|lzma|zst)|zip|tgz|tbz2|patch(\.(xz|bz2|gz|lz|lzma|zst))?)$//')
        
        printf "Found custom update: %s: %s->%s\n" "$name" "$local_ver" "$remote_ver"
        custom_updates_list+=("$name")
        update_msgs+=("${name}: ${local_ver}->${remote_ver}")
    done <<< "$custom_updates"

    if [[ ${#updates[@]} -eq 0 && ${#custom_updates_list[@]} -eq 0 && ${#broken_pkgs[@]} -eq 0 ]]; then
        echo "No updates found."
        return 0
    fi

    # Add broken packages (missing inventories) to the update list for force-rebuild
    # Track separately so they get -f flag in the build loop
    local force_rebuild_pkgs=()
    for bp in "${broken_pkgs[@]}"; do
        local already_in=false
        for p in "${updates[@]}"; do
            [[ "$p" == "$bp" ]] && already_in=true && break
        done
        if [[ "$already_in" == "false" ]]; then
            updates+=("$bp")
            force_rebuild_pkgs+=("$bp")
        fi
    done

    if [[ ${#updates[@]} -gt 0 ]]; then
        echo "Resolving dependencies and determining build order..."
    
    # Export LFS_BOOK and BLFS_BOOK to be used by python script
    export LFS_BOOK_PYTHON="$LFS_DEV_BOOK"
    export BLFS_BOOK_PYTHON="$BLFS_DEV_BOOK"

    # Use a Python script to perform topological sorting
    local sorted_updates=$(python3 -c '
import urllib.request
import re
import sys
import os

lfs_book = os.environ.get("LFS_BOOK_PYTHON", "https://www.linuxfromscratch.org/lfs/view/development")
blfs_book = os.environ.get("BLFS_BOOK_PYTHON", "https://linuxfromscratch.org/blfs/view/systemd")

updates = sys.argv[1:]
if not updates:
    sys.exit(0)

# 1. Fetch longindex to map package to page URL
def fetch_longindex():
    try:
        req = urllib.request.Request(f"{blfs_book}/longindex.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8")
    except Exception as e:
        print(f"Error fetching BLFS longindex: {e}", file=sys.stderr)
        return ""

longindex = fetch_longindex()

# Extract dependencies for a given URL
def extract_deps(url):
    deps = []
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as response:
            html = response.read().decode("utf-8")
            
            # Find required/recommended blocks
            blocks = re.findall(r"class=\"(required|recommended)\"(.*?)</p>", html, re.IGNORECASE | re.DOTALL)
            for _, block in blocks:
                hrefs = re.findall(r"href=\"([^\"]+)\"", block)
                for href in hrefs:
                    # Clean up href to just the page name without extension
                    page_name = href.split("/")[-1].replace(".html", "")
                    
                    # Convert gst10-plugins back to gst-plugins to match local names
                    page_name = re.sub(r"^gst10-plugins-", "gst-plugins-", page_name)
                    
                    # Store as potential dep, we resolve against available updates later
                    deps.append(page_name)
    except Exception as e:
        pass
    return deps

# 2.2 Resolve and build required dependencies before this package
pkg_urls = {}
for pkg in updates:
    search_pkg = pkg
    if re.match(r"^gst-plugins-(base|good|bad|ugly|libav|vaapi)$", pkg):
        search_pkg = "gst10-plugins-" + pkg.split("-")[-1]
    
    # Try exact match in longindex
    m = re.search(r"href=\"([^\"]*/" + re.escape(search_pkg) + r"\.html)\"", longindex, re.IGNORECASE)
    if not m:
        # Partial match
        m = re.search(r"href=\"([^\"]*" + re.escape(search_pkg) + r"[^\"]*\.html)\"", longindex, re.IGNORECASE)
    
    if m:
        href = m.group(1).replace("../", "")
        pkg_urls[pkg] = f"{blfs_book}/{href}"
    else:
        # Check LFS if not in BLFS
        if pkg == "linux":
            pkg_urls[pkg] = f"{lfs_book}/chapter10/kernel.html"

graph = {pkg: set() for pkg in updates}

for pkg in updates:
    if pkg in pkg_urls:
        deps = extract_deps(pkg_urls[pkg])
        for dep in deps:
            matched_dep = None
            for p in updates:
                if p == dep or p.startswith(dep + "-") or dep.startswith(p + "-"):
                    matched_dep = p
                    break
            
            if matched_dep and matched_dep != pkg:
                # Avoid circular deps within the same page (common on metapackage pages)
                if pkg_urls.get(pkg) == pkg_urls.get(matched_dep):
                    # Only enforce order for critical build tools
                    if matched_dep in ["extra-cmake-modules", "breeze-icons"]:
                        graph[pkg].add(matched_dep)
                else:
                    graph[pkg].add(matched_dep)

def fetch_frameworks_order():
    try:
        req = urllib.request.Request(f"{blfs_book}/kde/frameworks6.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as response:
            html = response.read().decode("utf-8")
            # Extract names from the md5 block: e.g. "karchive-6.23.0.tar.xz"
            tars = re.findall(r"([a-z0-9-]+)-6\.[0-9]+\.[0-9]+\.tar\.xz", html)
            order = []
            for t in tars:
                if t not in order:
                    order.append(t)
            return order
    except Exception as e:
        return []

def fetch_plasma_order():
    try:
        req = urllib.request.Request(f"{blfs_book}/kde/plasma-all.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as response:
            html = response.read().decode("utf-8")
            # Extract names from the md5 block or links
            tars = re.findall(r"([a-z0-9-]+)-6\.[0-9]+\.[0-9]+\.tar\.xz", html)
            order = []
            for t in tars:
                if t not in order:
                    order.append(t)
            return order
    except Exception as e:
        return []

frameworks_order = fetch_frameworks_order()
plasma_order = fetch_plasma_order()

# Perform topological sort
def toposort(graph):
    # Calculate in-degrees
    in_degree = {u: 0 for u in graph}
    for u in graph:
        for v in graph[u]:
            in_degree[u] += 1
    
    # We want to build nodes with in_degree 0 first
    # So we need to reverse the graph: dependency -> dependents
    adj = {u: [] for u in graph}
    for u in graph:
        for v in graph[u]:
            adj[v].append(u)
    
    # Recalculate in_degree: count how many nodes each node depends on
    in_degree = {u: len(graph[u]) for u in graph}
    
    priority_pkgs = ["extra-cmake-modules", "breeze-icons"]
    
    def get_sort_key(pkg):
        prio = 0 if pkg in priority_pkgs else 1
        fw_index = frameworks_order.index(pkg) if pkg in frameworks_order else 9999
        plasma_index = plasma_order.index(pkg) if pkg in plasma_order else 9999
        return (prio, fw_index, plasma_index, pkg)
    
    queue = [u for u in in_degree if in_degree[u] == 0]
    queue.sort(key=get_sort_key)
    
    result = []
    while queue:
        u = queue.pop(0)
        result.append(u)
        
        for v in adj[u]:
            in_degree[v] -= 1
            if in_degree[v] == 0:
                queue.append(v)
                queue.sort(key=get_sort_key)
                    
    # Handle cycles by appending remaining nodes
    remaining = [node for node in graph if node not in result]
    remaining.sort(key=lambda x: (x not in priority_pkgs, x))
    result.extend(remaining)
            
    return result

sorted_pkgs = toposort(graph)
for pkg in sorted_pkgs:
    print(pkg)
' "${updates[@]}")

    if [[ -n "$sorted_updates" ]]; then
        updates=()
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && updates+=("$pkg")
        done <<< "$sorted_updates"
    fi

    echo "Applying updates in dependency order:"
    for pkg in "${updates[@]}"; do
        echo "  - $pkg"
    done
    echo ""

    for pkg in "${updates[@]}"; do
        local build_args=()
        if [[ "$dry_run" == "true" ]]; then build_args+=("--dry-run"); fi
        if [[ "$upstream" == "true" ]]; then
            build_args+=("--upstream")
        else
            build_args+=("--no-upstream")
        fi
        
        # Force rebuild if this package only has a missing inventory (not a version update)
        local is_force=false
        for fp in "${force_rebuild_pkgs[@]}"; do
            [[ "$fp" == "$pkg" ]] && is_force=true && break
        done
        [[ "$is_force" == "true" ]] && build_args+=("-f")

        if [[ "$dry_run" == "true" ]]; then
            echo "DRY RUN: lfs_autobuild ${build_args[*]} $pkg"
            lfs_autobuild "${build_args[@]}" "$pkg"
        else
            echo "Building $pkg..."
            if ! lfs_autobuild "${build_args[@]}" "$pkg"; then
                echo "Error: Build failed for $pkg. Aborting update loop."
                return 1
            fi
        fi

        # Check for preserved libraries that might require dependent rebuilds
        local preserved_file="/tmp/preserved_libs_${pkg}.txt"
        if ssh_lfs "[ -f $preserved_file ]"; then
            echo "Preserved libraries detected after updating $pkg. Searching for dependents..."
            local libs=$(ssh_lfs "cat $preserved_file && sudo rm -f $preserved_file")
            while read -r lib; do
                [[ -z "$lib" ]] && continue
                echo "  Checking dependents for $(basename "$lib")..."
                local dependents=$(ssh_lfs "missing_search $(basename "$lib")" 2>/dev/null)
                while read -r dep_bin; do
                    [[ -z "$dep_bin" ]] && continue
                    local dep_pkg=$(lfs_map_bin_to_pkg "$dep_bin")
                    if [[ -n "$dep_pkg" ]]; then
                        # Add to updates if not already there and not the current package
                        local already_in=false
                        for p in "${updates[@]}"; do
                            if [[ "$p" == "$dep_pkg" ]]; then already_in=true; break; fi
                        done
                        if [[ "$already_in" == "false" && "$dep_pkg" != "$pkg" ]]; then
                            echo "    -> Found dependent: $dep_pkg (needs rebuild)"
                            updates+=("$dep_pkg")
                        fi
                    fi
                done <<< "$dependents"
                
                # Register for final cleanup
                echo "$lib" | sudo tee -a /tmp/lfs_preserved_cleanup_list.txt > /dev/null
            done <<< "$libs"
        fi
    done

    # Final cleanup of preserved libraries that are no longer needed
    if ssh_lfs "[ -f /tmp/lfs_preserved_cleanup_list.txt ]"; then
        echo "Performing final cleanup of preserved libraries..."
        ssh_lfs 'while read -r lib; do
            if [ -f "$lib" ]; then
                dependents=$(missing_search "$(basename "$lib")" 2>/dev/null)
                if [ -z "$dependents" ]; then
                    echo "  Removing no longer needed preserved library: $lib"
                    sudo rm -f "$lib"
                else
                    echo "  Preserving $lib: still has dependents"
                fi
            fi
        done < /tmp/lfs_preserved_cleanup_list.txt && sudo rm -f /tmp/lfs_preserved_cleanup_list.txt'
    fi

    fi

    echo "Updating Python packages via pip..."
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: pip3 list --format=freeze | cut -d= -f1 | xargs -n1 sudo pip3 install -U"
    else
        ssh_lfs "pip3 list --format=freeze | cut -d= -f1 | xargs -n1 sudo pip3 install -U"
    fi

    echo "Updating Julia with juliaup..."
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: juliaup update"
    else
        ssh_lfs 'export PATH=$PATH:$HOME/.juliaup/bin && juliaup update'
    fi

    if [[ ${#custom_updates_list[@]} -gt 0 ]]; then
        echo "Resolving dependencies for custom packages..."

        # Build a dependency-ordered list using the depends=() in each build.sh
        # We run a remote script that outputs edges "pkg dep" for deps in the update list,
        # then topologically sort with tsort.
        local pkg_list_escaped=$(printf '%s\n' "${custom_updates_list[@]}" | paste -sd',')
        local dep_script=$(cat <<'DEPEOF'
pkg_list="__PKG_LIST__"
IFS=',' read -ra updates <<< "$pkg_list"

# Build association: pkg_name -> dir_name for fallback resolution
declare -A name_to_dir

for build_script in $(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null); do
    pkg_dir=$(dirname "$build_script")
    dir_name=$(basename "$pkg_dir")
    name_line=$(grep -E '^[A-Z_]*NAME=' "$build_script" | head -n 1)
    if [ -n "$name_line" ]; then
        pkg_name=$(echo "$name_line" | cut -d= -f2 | tr -d '"' | tr -d "'")
    else
        pkg_name="$dir_name"
    fi
    name_to_dir["$pkg_name"]="$dir_name"
    name_to_dir["$dir_name"]="$dir_name"
done

# For each pkg in updates, find its build.sh and read depends=()
# Output edges: dep pkg (tsort wants "dependency before dependent")
printed_self=()
for u in "${updates[@]}"; do
    # resolve to dir name
    dir_name="${name_to_dir[$u]:-$u}"
    build_script=$(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null | grep -E "/${dir_name}/build.sh$" | head -n 1)
    [ -z "$build_script" ] && echo "$u $u" && continue

    deps_line=$(grep -E '^depends=' "$build_script" | head -n 1)
    if [ -z "$deps_line" ]; then
        echo "$u $u"
        continue
    fi

    # Parse the array: depends=(a b c) - strip leading key
    deps_val=$(echo "$deps_line" | sed -E 's/^[a-zA-Z_]+=\(?//' | sed -E 's/\)$//')
    eval "deps=($deps_val)"

    has_dep_in_list=false
    for dep in "${deps[@]}"; do
        # Check if this dep is in the updates list (by name or dir name)
        for candidate in "${updates[@]}"; do
            cdir="${name_to_dir[$candidate]:-$candidate}"
            if [ "$dep" = "$candidate" ] || [ "$dep" = "$cdir" ]; then
                echo "$dep $u"
                has_dep_in_list=true
            fi
        done
    done
    if ! $has_dep_in_list; then
        echo "$u $u"
    fi
done
DEPEOF
)
        dep_script="${dep_script/__PKG_LIST__/$pkg_list_escaped}"

        local sorted_custom
        sorted_custom=$(ssh_lfs "bash -c '$(echo "$dep_script" | sed "s/'/'\\''/g")'" 2>/dev/null \
            | grep -vE "^(Warning:|Connection|IP|SSH|grep:)" \
            | tsort 2>/dev/null)

        if [[ -n "$sorted_custom" ]]; then
            mapfile -t custom_updates_list <<< "$sorted_custom"
        fi

        echo "Applying custom updates in dependency order:"
        for pkg in "${custom_updates_list[@]}"; do
            echo "  - $pkg"
        done
        echo ""

        for pkg in "${custom_updates_list[@]}"; do
            local build_args=()
            if [[ "$dry_run" == "true" ]]; then build_args+=("--dry-run"); fi
            if [[ "$upstream" == "true" ]]; then
                build_args+=("--upstream")
            else
                build_args+=("--no-upstream")
            fi

            if [[ "$dry_run" == "true" ]]; then
                echo "DRY RUN: lfs_autobuild ${build_args[*]} $pkg"
                lfs_autobuild "${build_args[@]}" "$pkg"
            else
                echo "Building custom package $pkg..."
                lfs_autobuild "${build_args[@]}" "$pkg"
            fi
        done
    fi

    # Git commit and push if everything is healthy
    if [[ "$dry_run" == "false" && ( ${#updates[@]} -gt 0 || ${#custom_updates_list[@]} -gt 0 ) ]]; then
        echo "Checking system health before committing updates..."
        local broken_pkgs_check=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do pkg=$(basename "$f"); [ $(wc -l < "$f") -le 1 ] && echo "$pkg"; done')
        if [[ -z "$broken_pkgs_check" ]]; then
            echo "System healthy. Triggering automated registry commit..."
            ssh_lfs "bash -c 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null && lfs_package_commit'"
        else
            echo "Warning: The following packages are missing inventories:"
            echo "$broken_pkgs_check"
            echo "--------------------------------------------------------------------------------"
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                echo ">>> Last 5 lines of output for $pkg:"
                if [[ -f "/tmp/lfs-autobuild.log" ]]; then
                    # Search only the last 500,000 lines to keep it fast even if the log is huge
                    tail -n 500000 /tmp/lfs-autobuild.log | sed -n "/Building .*$pkg\.\.\./,/Building /p" | grep -v "Building " | tail -n 5
                else
                    echo "  Log file /tmp/lfs-autobuild.log not found."
                fi
                echo "--------------------------------------------------------------------------------"
            done <<< "$broken_pkgs_check"
            echo "Skipping commit. If you have builds in progress, wait for them to finish and run lfs_package_commit."
            echo "TIP: You can watch build progress with: tail -f /tmp/lfs-autobuild.log"
            echo "Skipping commit."
        fi
    fi
    ssh_lfs "zsh -ic upos"
}
