#!/usr/bin/env bash

aver() {
    wget -cqO- -T 10 "https://gitlab.archlinux.org/archlinux/packaging/packages/$1/-/raw/main/PKGBUILD" | grep "^pkgver=" | cut -d '=' -f 2
}

gn_ver() {
    local pkg="$1"
    local arch_name="${2:-$1}"

    # 1. Try GNOME download server cache.json (fastest, most reliable)
    local gnome_ver=$(curl -sL --max-time 15 "https://download.gnome.org/sources/$pkg/cache.json" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    pkg = sys.argv[1]
    versions = data[1].get(pkg, [])
    stable = []
    for v in versions:
        parts = v.split(".")
        if not all(p.isdigit() for p in parts): continue
        ints = [int(p) for p in parts]
        if ints[0] < 40 and len(ints) >= 2 and ints[1] % 2 != 0: continue
        if any(p >= 90 for p in ints[1:]): continue
        stable.append(v)
    if stable:
        stable.sort(key=lambda x: [int(p) for p in x.split(".")])
        print(stable[-1])
except Exception:
    pass
' "$pkg" 2>/dev/null)
    if [[ -n "$gnome_ver" ]]; then
        echo "$gnome_ver"
        return 0
    fi

    # 2. Map packages with non-standard GitLab locations (namespace or project name differs)
    local gl_pkg="$pkg"
    local gl_namespace="GNOME"
    local tag_filter="grep -v 'alpha\|beta\|\.rc'"
    case "$pkg" in
        gtk3)            gl_pkg="gtk"; tag_filter="grep '\-3\.' | grep -v 'alpha\|beta\|\.rc'" ;;
        polkit-gnome)    gl_namespace="Archive"; gl_pkg="policykit-gnome" ;;
    esac

    # 3. Try GNOME GitLab web tags page
    local up_ver=$(wget -cqO- "https://gitlab.gnome.org/${gl_namespace}/${gl_pkg}/-/tags" | grep "tags/" | cut -d '/' -f 6 | sed 's/".*//g' | eval "$tag_filter" | sort -V | tail -n 1 | sed 's/^v//g')
    if echo "$up_ver" | grep -q "[0-9]\.[0-9]"; then
        echo "$up_ver"
        return 0
    fi

    # 4. Try GNOME GitLab REST API (avoids git ls-remote auth errors on missing/private repos)
    local gl_encoded="${gl_namespace}%2F${gl_pkg}"
    local api_ver=$(curl -s --max-time 15 "https://gitlab.gnome.org/api/v4/projects/${gl_encoded}/repository/tags" | \
        perl -nle 'while (m{"name":"v?([0-9][0-9.]+)"}g) { print $1 }' | \
        grep -v "alpha\|beta\|rc" | sort -V | tail -n 1)
    [[ "$pkg" == "gtk3" ]] && api_ver=$(echo "$api_ver" | grep "^3\." | tail -n 1)
    if echo "$api_ver" | grep -q "[0-9]\.[0-9]"; then
        echo "$api_ver"
        return 0
    fi

    # 5. Arch PKGBUILD fallback
    local arch_ver=$(aver "$arch_name")
    if echo "$arch_ver" | grep -qP "[0-9]"; then
        echo "$arch_ver"
        return 0
    fi
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
            git ls-remote --tags https://github.com/libuv/libuv.git | perl -nle 'if (m{refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$}) { print $1 }' | sort -V | tail -n 1
            ;;
        frameworks|frameworks6|extra-cmake-modules|breeze-icons|oxygen-icons)
            curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+(\.[0-9]+)?(?=/")}g) { my $v=$&; $v.=".0" if $v =~ /^\d+\.\d+$/; print $v }' | sort -V | tail -n 1
            ;;
        plasma|plasma-all)
            curl -sL https://download.kde.org/stable/plasma/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)
            curl -sL https://download.kde.org/stable/release-service/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        libpeas)
            # Use GitLab API to fetch the latest guaranteed 1.x stable tag by strictly filtering for 'libpeas-' prefix
            curl -sL "https://gitlab.gnome.org/api/v4/projects/GNOME%2Flibpeas/repository/tags" | perl -nle 'while (m{"name":"libpeas-([0-9.]+)"}g) { print $1 }' | sort -V | tail -n 1
            ;;
        harfbuzz)
            curl -s -H "User-Agent: bash" "https://api.github.com/repos/harfbuzz/harfbuzz/releases/latest" | perl -nle 'while (m{"tag_name":\s*"([0-9.]+)"}g) { print $1 }' | head -n 1
            ;;
        gnome-*|gsettings-desktop-schemas|yelp|mutter|nautilus|libpeas|gjs|glycin|tecla|gvfs|gexiv2|baobab|evince|epiphany|totem|tracker*|grilo*|folks|evolution*|gtksourceview*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|gjs|glib-networking|glibmm|gmime|gnome-video-effects|graphene|gsound|gtk-doc|gtkmm*|json-glib|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|libpeas|librsvg|libsecret|libsoup|mm-common|pangomm|phodav|pygobject|rest|vte|xdg-desktop-portal-gnome|tinysparql|localsearch|polkit-gnome|geocode-glib|libshumate|libsecret)
            local gnome_pkg="$pkg"
            [[ "$gnome_pkg" == "glib2" ]] && gnome_pkg="glib"
            local base_url="https://download.gnome.org/sources/$gnome_pkg"
            # Some packages might have different names on GNOME servers
            [[ "$gnome_pkg" == "libxml2" ]] && base_url="https://download.gnome.org/sources/libxml2"
            [[ "$gnome_pkg" == "libxslt" ]] && base_url="https://download.gnome.org/sources/libxslt"
            
            local gnome_ver=$(curl -sL "$base_url/cache.json" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    versions = data[1].get("'"$gnome_pkg"'", [])
    stable_versions = []
    for v in versions:
        parts = v.split(".")
        if not all(p.isdigit() for p in parts): continue
        ints = [int(p) for p in parts]
        if ints[0] < 40 and len(ints) >= 2 and ints[1] % 2 != 0: continue
        if any(p >= 90 for p in ints[1:]): continue
        stable_versions.append(v)
    if stable_versions:
        stable_versions.sort(key=lambda x: [int(p) for p in x.split(".")])
        print(stable_versions[-1])
except Exception:
    pass
' 2>/dev/null)
            if [[ -n "$gnome_ver" ]]; then
                echo "$gnome_ver"
            else
                local major=$(curl -sL "$base_url/" | perl -nle 'while (m{href="\K[0-9]+(\.[0-9]+)*(?=/?")}sg) { print $& }' | sort -V | tail -n 1)
                if [[ -n "$major" ]]; then
                    local rver=$(curl -sL "$base_url/$major/" | perl -nle 'while (m{href="\K'"$gnome_pkg"'-([0-9.]+)\.tar}sg) { print $1 }' | sort -V | tail -n 1)
                    if [[ -n "$rver" ]]; then
                        echo "$rver"
                        return
                    fi
                fi
                gn_ver "$gnome_pkg"
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
            git ls-remote --tags https://github.com/libjxl/libjxl.git | perl -nle 'if (m{refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$}) { print $1 }' | sort -V | tail -n 1
            ;;
    esac | grep -E '^[0-9]+(\.[0-9]+)+$' | head -n 1
}

lfs_get_remote_packages() {
    local upstream=true
    local global_offset=0
    local global_total=0
    local global_weight=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-upstream) upstream=false ;;
            --global-offset) global_offset="$2"; shift ;;
            --global-total)  global_total="$2";  shift ;;
            --global-weight) global_weight="$2"; shift ;;
        esac
        shift
    done

    # Fetch kernel version, JDK info, LFS book packages, BLFS longindex, and all BLFS
    # meta-pages in parallel to eliminate the largest sequential bottleneck.
    local tmp_fetch=$(mktemp -d)
    local tmp_meta=$(mktemp -d)

    # Kernel version
    (curl -s -H "User-Agent: bash" https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -Vr | head -n 1 > "$tmp_fetch/kernel") &

    # JDK: major lookup + tarball URL chained in one subshell (avoids extra wait round)
    (
        local jdk_major=$(curl -s https://jdk.java.net/ | perl -nle 'while (m{href="\./([0-9]+)}g) { print $1 }' | sort -rn | head -n 1)
        if [[ -n "$jdk_major" ]]; then
            local jdk_tarball=$(curl -s "https://jdk.java.net/${jdk_major}/" | perl -nle 'while (m{(https://download\.java\.net/java/[^ "]+/openjdk-[0-9]+[^ "]*_linux-x64_bin\.tar\.gz)}g) { print $1 }' | head -n 1)
            local jdk_ver=$(echo "$jdk_tarball" | perl -nle 'while (m{openjdk-([0-9a-zA-Z\+\.\-]+)_linux-x64_bin}g) { print $1 }')
            echo "openjdk-${jdk_ver}_linux-x64_bin" > "$tmp_fetch/jdk"
        fi
    ) &

    # LFS book packages (kernel version substitution applied after wait)
    (curl -s "$LFS_DEV_BOOK/chapter03/packages.html" | tr -d '\r' | \
        grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.(tar\.[a-z0-9]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | sort -u > "$tmp_fetch/lfs_raw") &

    # BLFS longindex
    (curl -s "$BLFS_DEV_BOOK/longindex.html" | tr -d '\r' | \
        perl -0777 -ne 'while (/SpiderMonkey:.*?firefox-([0-9.]+)/gs) { print "spidermonkey-$1\n" } while (/>([a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+)<\/a>/gs) { print "$1\n" }' | \
        sed "/[Vv]im-[0-9.]*$/d" | \
        sort -u > "$tmp_fetch/blfs") &

    # BLFS meta-pages (Xorg, KDE, etc.) — all fetched concurrently with the above
    local blfs_metapages=("x/x7lib.html" "x/x7app.html" "x/x7font.html" "x/x7driver.html" "kde/frameworks6.html" "kde/plasma-all.html" "kde/plasma.html")
    for page in "${blfs_metapages[@]}"; do
        local safe_name="${page//\//\_}"
        (curl -s "$BLFS_DEV_BOOK/$page" | tr -d '\r' | \
            grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.(tar\.[a-z0-9]+|zip)' | \
            sed 's/\.tar.*//; s/\.zip//' | sort -u > "$tmp_meta/$safe_name") &
    done

    wait

    KERNEL_VER=$(cat "$tmp_fetch/kernel")
    JDK_REMOTE=$(cat "$tmp_fetch/jdk" 2>/dev/null)
    # Apply kernel version substitution now that KERNEL_VER is known
    local lfs_remote=$(sed "s|^linux-[0-9.]*$|linux-${KERNEL_VER}|g" "$tmp_fetch/lfs_raw" | sort -u)
    local blfs_remote=$(cat "$tmp_fetch/blfs")
    rm -rf "$tmp_fetch"

    # Merge BLFS meta-page results (fetched in parallel above)
    local blfs_extra=""
    local plasma_pkg_names=""
    local frameworks_pkg_names=""
    for page in "${blfs_metapages[@]}"; do
        local safe_name="${page//\//\_}"
        local page_pkgs=$(cat "$tmp_meta/$safe_name" 2>/dev/null)
        blfs_extra+="${page_pkgs}"$'\n'
        if [[ "$page" == "kde/plasma"* ]]; then
            plasma_pkg_names+=$(echo "$page_pkgs" | sed -E 's/-[0-9].*//')
            plasma_pkg_names+=$'\n'
        elif [[ "$page" == "kde/frameworks6.html" ]]; then
            frameworks_pkg_names+=$(echo "$page_pkgs" | sed -E 's/-[0-9].*//')
            frameworks_pkg_names+=$'\n'
        fi
    done
    rm -rf "$tmp_meta"
    
    local all_pkgs=$(echo -e "${lfs_remote}\n${blfs_remote}\n${blfs_extra}\n${JDK_REMOTE}" | grep -v "^$" | sort -u | tr -d '\r')

    if [[ "$upstream" == "true" ]]; then
        local upstream_list=("rustc" "llvm" "libuv" "frameworks" "frameworks6" "extra-cmake-modules" "breeze-icons" "plasma" "konsole" "dolphin" "dolphin-plugins" "gwenview" "libkdcraw" "okular" "kdenlive" "gtk3" "gnome-shell" "glycin" "gjs" "nautilus" "libpeas" "tecla" "gnome-desktop" "gnome-shell-extensions" "gnome-session" "gnome-tweaks" "mutter" "yelp" "gvfs" "gnome-control-center" "gnome-settings-daemon" "gnome-keyring" "gnome-bluetooth" "gnome-backgrounds" "gnome-user-docs" "xdg-desktop-portal-gnome" "gexiv2" "adwaita-icon-theme" "baobab" "evince" "gnome-terminal" "glib2" "gsettings-desktop-schemas" "gnome-online-accounts" "gnome-menus" "gnome-autoar" "polkit-gnome" "geocode-glib" "evolution-data-server" "tracker" "tinysparql" "localsearch" "tracker-miners" "libshumate" "libjxl" "libdisplay-info")
        local total=${#upstream_list[@]}
        local count=0
        local tmp_upstream=$(mktemp -d)
        
        local gnome_pkgs=()
        local other_pkgs=()
        for p in "${upstream_list[@]}"; do
            case "$p" in
                gnome-*|gsettings-desktop-schemas|yelp|mutter|nautilus|gjs|glycin|tecla|gvfs|gexiv2|baobab|evince|epiphany|totem|tracker*|grilo*|folks|evolution*|gtksourceview*|adwaita-icon-theme|at-spi2-core|atkmm|cairomm|gdl|glib|glib2|glib-networking|glibmm|gmime|gnome-video-effects|graphene|gsound|gtk-doc|gtkmm*|json-glib|libchamplain|libgda|libgee|libgnome-keyring|libgsf|libgtop|libhandy|libnma|librsvg|libsecret|libsoup|mm-common|pangomm|phodav|pygobject|rest|vte|xdg-desktop-portal-gnome|tinysparql|localsearch|polkit-gnome|geocode-glib|libshumate)
                    gnome_pkgs+=("$p") ;;
                *)
                    other_pkgs+=("$p") ;;
            esac
        done

        if [[ ${#gnome_pkgs[@]} -gt 0 ]]; then
            (
                python3 -c '
import sys, json, urllib.request
from concurrent.futures import ThreadPoolExecutor
tmp_dir = sys.argv[1]
packages = sys.argv[2:]
def fetch_gnome(pkg):
    name = pkg
    if name == "glib2": name = "glib"
    if name == "libxml2": name = "libxml2"
    url = f"https://download.gnome.org/sources/{name}/cache.json"
    try:
        req = urllib.request.urlopen(url, timeout=10)
        data = json.loads(req.read())
        versions = data[1].get(name, [])
        stable_versions = []
        for v in versions:
            parts = v.split(".")
            if not all(p.isdigit() for p in parts): continue
            ints = [int(p) for p in parts]
            if ints[0] < 40 and len(ints) >= 2 and ints[1] % 2 != 0: continue
            if any(p >= 90 for p in ints[1:]): continue
            stable_versions.append(v)
        if stable_versions:
            stable_versions.sort(key=lambda x: [int(p) for p in x.split(".")])
            return pkg, stable_versions[-1]
    except Exception:
        pass
    return pkg, "FAILED"
with ThreadPoolExecutor(max_workers=20) as ex:
    for pkg, ver in ex.map(fetch_gnome, packages):
        with open(f"{tmp_dir}/{pkg}", "w") as f:
            if ver != "FAILED": f.write(f"{pkg}-{ver}\n")
            else: f.write(f"{pkg}-FAILED\n")
' "$tmp_upstream" "${gnome_pkgs[@]}"
                # Fallback via gn_ver for any GNOME packages the Python fetcher couldn't resolve
                for _gp in "${gnome_pkgs[@]}"; do
                    local _f="$tmp_upstream/$_gp"
                    if [[ -f "$_f" ]] && grep -q "FAILED" "$_f"; then
                        local _gname="$_gp"
                        [[ "$_gname" == "glib2" ]] && _gname="glib"
                        local _gv=$(gn_ver "$_gname")
                        if [[ -n "$_gv" ]]; then
                            echo "${_gp}-${_gv}" > "$_f"
                        fi
                    fi
                done
            ) &
        fi

        for p in "${upstream_list[@]}"; do
            # Only spawn subshells for non-GNOME packages; GNOME ones are batched in Python above
            if [[ ! " ${gnome_pkgs[@]} " =~ " ${p} " ]]; then
                (
                    uv=$(lfs_get_upstream_version "$p")
                    if [[ -n "$uv" ]]; then
                        echo "${p}-${uv}" > "$tmp_upstream/$p"
                    else
                        echo "${p}-FAILED" > "$tmp_upstream/$p"
                    fi
                ) &
            fi
            
            # Show progress based on jobs started
            count=$((count + 1))
            if (( global_total > 0 )); then
                local gpct=$(( 100 * (global_offset + count * global_weight) / global_total ))
                lfs_progress_bar "$count" "$total" "Starting upstream checks [Global ${gpct}%]" >&2
            else
                lfs_progress_bar "$count" "$total" "Starting upstream check: $p" >&2
            fi
        done
        wait
        
        # Update progress to 100% on the SAME line
        if (( global_total > 0 )); then
            local gpct=$(( 100 * (global_offset + total * global_weight) / global_total ))
            lfs_progress_bar "$total" "$total" "Upstream checks complete   [Global ${gpct}%]" >&2
        else
            lfs_progress_bar "$total" "$total" "Upstream checks complete" >&2
        fi
        echo "" >&2
        
        # 3. Parallel expansion of metapackage versions
        local tmp_expand=$(mktemp -d)

        if [[ -f "$tmp_upstream/plasma" ]]; then
            local plasma_up_ver=$(cat "$tmp_upstream/plasma" | cut -d- -f2)
            (
                local _names="$plasma_pkg_names"
                local tmp_listing="$tmp_expand/plasma_listing.html"
                local http_code=$(curl -sL -w "%{http_code}" "https://download.kde.org/stable/plasma/${plasma_up_ver}/" -o "$tmp_listing")
                if [[ "$http_code" == "200" ]]; then
                    local dir_pkgs=$(grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.tar\.xz' "$tmp_listing" | sed -E 's/-[0-9].*//' | sort -u)
                    [[ -n "$dir_pkgs" ]] && _names="$dir_pkgs"
                fi
                rm -f "$tmp_listing"
                for p in $(echo "$_names" | sort -u); do
                    [[ -n "$p" ]] && echo "${p}-${plasma_up_ver}" > "$tmp_upstream/$p"
                done
            ) &
        fi

        if [[ -f "$tmp_upstream/frameworks6" || -f "$tmp_upstream/frameworks" ]]; then
            local fw_up_ver=""
            [[ -f "$tmp_upstream/frameworks6" ]] && fw_up_ver=$(cat "$tmp_upstream/frameworks6" | cut -d- -f2)
            [[ -z "$fw_up_ver" && -f "$tmp_upstream/frameworks" ]] && fw_up_ver=$(cat "$tmp_upstream/frameworks" | cut -d- -f2)
            if [[ -n "$fw_up_ver" ]]; then
                local fw_mm=$(echo "$fw_up_ver" | cut -d. -f1,2)
                (
                    local _names="$frameworks_pkg_names"
                    local tmp_listing="$tmp_expand/fw_listing.html"
                    local http_code=$(curl -sL -w "%{http_code}" "https://download.kde.org/stable/frameworks/${fw_mm}/" -o "$tmp_listing")
                    if [[ "$http_code" == "200" ]]; then
                        local dir_pkgs=$(grep -oE '[a-zA-Z0-9_+.-]+-[0-9][a-zA-Z0-9_+.-]*\.tar\.xz' "$tmp_listing" | sed -E 's/-[0-9].*//' | sort -u)
                        [[ -n "$dir_pkgs" ]] && _names="$dir_pkgs"
                    fi
                    rm -f "$tmp_listing"
                    for p in $(echo "$_names" | sort -u); do
                        [[ -n "$p" ]] && echo "${p}-${fw_up_ver}" > "$tmp_upstream/$p"
                    done
                ) &
            fi
        fi

        wait
        rm -rf "$tmp_expand"

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

        lfs_autobuild -f "$actual_pkg"
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

    local global_offset=0
    local global_total=0
    local global_weight=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global-offset) global_offset="$2"; shift ;;
            --global-total)  global_total="$2";  shift ;;
            --global-weight) global_weight="$2"; shift ;;
        esac
        shift
    done

    local script=$(cat <<'EOF'
    sudo mkdir -p /var/lib/custom-packages 2>/dev/null || true

    if [ -f ~/lfs_packaging/shared-funcs.sh ]; then
        source ~/lfs_packaging/shared-funcs.sh
        while read -r func; do
            export -f "$func"
        done < <(declare -F | awk '{print $3}')
    fi

    # Intercept gn_ver for polkit-gnome so we don't hit the git ls-remote error in shared-funcs.sh
    # but leave other custom packages (like glib2, libadwaita, gedit) using their own gn_ver logic
    if declare -f gn_ver >/dev/null; then
        eval "original_gn_ver() $(declare -f gn_ver | tail -n +2)"
        gn_ver() {
            if [[ "$1" == "polkit-gnome" ]]; then
                curl -s --max-time 15 "https://gitlab.gnome.org/api/v4/projects/Archive%2Fpolicykit-gnome/repository/tags" | \
                    perl -nle 'while (m{"name":"v?([0-9][0-9.]+)"}g) { print $1 }' | \
                    grep -v "alpha\|beta\|rc" | sort -V | tail -n 1
            else
                original_gn_ver "$@"
            fi
        }
        export -f gn_ver
        export -f original_gn_ver
    fi

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
                # If the extracted name contains shell variable references it wasn't
                # a static assignment — fall back to the directory name instead.
                if echo "$pkg_name" | grep -q '\$'; then
                    pkg_name="$pkg_basename"
                fi
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
                # Extract the raw RHS of version= without executing anything
                raw_ver_line=$(sed -n "${version_line_num}p" "$build_script" | tr -d '\r')
                # Get just the value part after '='
                raw_ver=$(echo "$raw_ver_line" | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
                
                # If the value is a static string (no command substitution), use it directly
                if ! echo "$raw_ver" | grep -qE '[$`]'; then
                    [ -n "$raw_ver" ] && remote_ver="$raw_ver" || status="FAILED"
                else
                    # Dynamic version line - evaluate all lines UP TO AND INCLUDING version=
                    # so that prerequisite variables (REPO_URL, name, etc.) are available.
                    # This mirrors what lfs_autobuild does in its skip-logic eval.
                    eval_script="/tmp/eval_ver_${pkg_basename}_$$.sh"
                    echo 'set +e' > "$eval_script"
                    echo 'export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> "$eval_script"
                    echo 'exec 3>&1 1>/dev/null' >> "$eval_script"
                    head -n "$version_line_num" "$build_script" | tr -d '\r' >> "$eval_script"
                    echo "echo \"VER_RESULT:\$$var_name\" >&3" >> "$eval_script"
                    remote_ver=$(cd "$pkg_dir" && timeout 60 bash "$eval_script" 2>/dev/null | grep '^VER_RESULT:' | sed 's/^VER_RESULT://' | tr -d '\r\n[:space:]')
                    rm -f "$eval_script"
                    if [ -z "$remote_ver" ]; then status="FAILED"; fi
                fi
            fi
            
            # Fallback: if we still have no version AND the build script clones a git repo,
            # ask the remote for its current HEAD.
            # Use the LAST matching git clone URL in the file — the package's own repo is
            # typically cloned last, after any build-dependency repos.
            if [ -z "$remote_ver" ] && grep -q "git clone" "$build_script"; then
                repo_url=$(perl -nle 'while (m{git clone\s+(?:--\S+\s+)*(https?://\S+|git\@\S+)}g) { print $1 }' "$build_script" | tail -n 1)
                if [ -n "$repo_url" ]; then
                    status="OK"
                    for attempt in 1 2 3; do
                        remote_ver=$(timeout 15 git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}')
                        [ -n "$remote_ver" ] && break
                        [ "$attempt" -lt 3 ] && sleep 2
                    done
                    if [ -z "$remote_ver" ]; then status="FAILED"; fi
                fi
            fi

            if [ -z "$remote_ver" ] && [ "$status" == "OK" ]; then status="MISSING"; fi
            
            if [ "$status" != "OK" ]; then
                # Use the real local_ver we already read (or "none" if not installed),
                # only substitute FAILED for the remote side.
                _display_local="${local_ver:-none}"
                echo "RESULT:$pkg_name $_display_local FAILED"
            elif [ -n "$remote_ver" ]; then
                if [ "$local_ver" == "none" ]; then
                    if [ -f "/var/lib/custom-packages/$pkg_basename" ]; then
                        local_ver=$(head -n 1 "/var/lib/custom-packages/$pkg_basename" 2>/dev/null | tr -d '\r\n[:space:]' || echo "none")
                    fi
                fi
                echo "RESULT:$pkg_name $local_ver $remote_ver"
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
            if (( global_total > 0 )); then
                local gpct=$(( 100 * (global_offset + count * global_weight) / global_total ))
                lfs_progress_bar "$count" "$total" "Checking ~/lfs_packaging     [Global ${gpct}%]" >&2
            else
                lfs_progress_bar "$count" "$total" "Checking ~/lfs_packaging $n" >&2
            fi
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
        if (( global_total > 0 )); then
            lfs_progress_bar "$total" "$total" "~/lfs_packaging checks complete [Global 100%]" >&2
        else
            lfs_progress_bar "$total" "$total" "~/lfs_packaging checks complete" >&2
        fi
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
            echo "  -v, --verbose  List custom packages with their local and remote versions"
            echo "  -h, --help     Show this help message"
            return 0
        fi
    done

    local verbose=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --no-upstream) upstream=false ;;
            --upstream) upstream=true ;; # Hidden compatibility flag
            -v|--verbose) verbose=true ;;
        esac
        shift
    done

    # Synchronize clock to prevent build errors from time skew
    # if [[ "$dry_run" == "false" ]]; then
    #     if [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
    #         # Running from host: sync VM clock to host time
    #         echo "Synchronizing LFS guest clock to host..."
    #         [[ -f "$NIXCFG/shell/user/08-ssh.sh" ]] && source "$NIXCFG/shell/user/08-ssh.sh"
    #         ssh_lfs "sudo date -s '@$(date +%s)'" >/dev/null 2>&1
    #     else
    #         # Running on VM: try to sync from hardware clock
    #         echo "Synchronizing LFS clock from hardware clock..."
    #         sudo hwclock -s >/dev/null 2>&1
    #     fi
    # fi

    echo "Fetching remote package list $([[ "$upstream" == "true" ]] && echo "including upstream " )from Development books..."
    local remote_list=$(lfs_get_remote_packages $([[ "$upstream" == "false" ]] && echo "--no-upstream") | tr -d '\r')
    echo "Fetching local package list from VM..."
    local local_list=$(lfs_get_local_packages | sed 's/.tar.*//g' | tr -d '\r')
    
    # Packages with missing file inventories (≤1 line) need a forced rebuild regardless of version
    echo "Checking for packages with missing file inventories..."
    local broken_pkgs_raw=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do (head -n 1 "$f" | grep -q "^BUILD_FAILED$" || [ $(wc -l < "$f") -le 1 ]) && basename "$f"; done' 2>/dev/null | tr -d '\r')
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

        # Skip if versions already match (handles both plain versions and git hashes)
        if [[ "$local_ver" == "$remote_ver" ]]; then
            continue
        fi
        # For git hashes, also compare 7-char short forms
        if [[ ${#local_ver} -eq 40 && ${#remote_ver} -eq 40 && "$local_ver" == "$remote_ver" ]]; then
            continue
        fi
        if [[ ${#local_ver} -ge 7 && ${#remote_ver} -ge 40 && "${local_ver}" == "${remote_ver:0:7}" ]]; then
            continue
        fi
        
        if [[ "$verbose" == "true" ]]; then
            printf "Found custom update: %s: %s->%s\n" "$name" "$local_ver" "$remote_ver"
        fi
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

    local all_updates=("${updates[@]}" "${custom_updates_list[@]}")
    if [[ ${#all_updates[@]} -gt 0 ]]; then
        echo "Resolving dependencies and determining build order..."
        
        # 1. Gather custom dependencies from VM
        local custom_dep_edges=""
        if [[ ${#custom_updates_list[@]} -gt 0 ]]; then
            local pkg_list_escaped=$(printf '%s\n' "${all_updates[@]}" | paste -sd',')
            local dep_script=$(cat <<'DEPEOF'
pkg_list="__PKG_LIST__"
IFS=',' read -ra updates_array <<< "$pkg_list"

declare -A name_to_dir
for build_script in $(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null); do
    pkg_dir=$(dirname "$build_script")
    dir_name=$(basename "$pkg_dir")
    name_line=$(grep -E '^[A-Z_]*NAME=' "$build_script" | head -n 1)
    if [ -n "$name_line" ]; then
        pkg_name=$(echo "$name_line" | cut -d= -f2 | tr -d '"' | tr -d "'")
        # Fall back to dir name if value is dynamic (contains $)
        if echo "$pkg_name" | grep -q '\$'; then
            pkg_name="$dir_name"
        fi
    else
        pkg_name="$dir_name"
    fi
    name_to_dir["$pkg_name"]="$dir_name"
    name_to_dir["$dir_name"]="$dir_name"
done

for u in "${updates_array[@]}"; do
    dir_name="${name_to_dir[$u]:-$u}"
    build_script=$(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null | grep -E "/${dir_name}/build.sh$" | head -n 1)
    if [ -n "$build_script" ]; then
        deps_line=$(grep -E '^depends=' "$build_script" | head -n 1)
        if [ -n "$deps_line" ]; then
            deps_val=$(echo "$deps_line" | sed -E 's/^[a-zA-Z_]+=\(?//' | sed -E 's/\)$//')
            eval "deps=($deps_val)"
            echo "CUSTOM_DEP:$u ${deps[*]}"
        fi
    fi
done
DEPEOF
)
            dep_script="${dep_script/__PKG_LIST__/$pkg_list_escaped}"
            custom_dep_edges=$(ssh_lfs "bash -c '$(echo "$dep_script" | sed "s/'/'\''/g")'" 2>/dev/null | grep "^CUSTOM_DEP:")
        fi

        export CUSTOM_DEPS_ENV="$custom_dep_edges"
        export LFS_BOOK_PYTHON="$LFS_DEV_BOOK"
        export BLFS_BOOK_PYTHON="$BLFS_DEV_BOOK"

        local sorted_updates=$(python3 -c '
import urllib.request
import re
import sys
import os
import socket

# Set a global timeout for all network requests to prevent hangs
socket.setdefaulttimeout(10)

lfs_book = os.environ.get("LFS_BOOK_PYTHON", "https://www.linuxfromscratch.org/lfs/view/development")
blfs_book = os.environ.get("BLFS_BOOK_PYTHON", "https://linuxfromscratch.org/blfs/view/systemd")

updates = sys.argv[1:]
if not updates:
    sys.exit(0)

# 1. Fetch longindex to map package to page URL
def fetch_longindex():
    try:
        req = urllib.request.Request(f"{blfs_book}/longindex.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
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
        with urllib.request.urlopen(req, timeout=10) as response:
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

custom_deps_raw = os.environ.get("CUSTOM_DEPS_ENV", "")
custom_deps = {}
for line in custom_deps_raw.split("\n"):
    if line.startswith("CUSTOM_DEP:"):
        parts = line[11:].strip().split()
        if not parts: continue
        pkg = parts[0]
        deps = parts[1:]
        custom_deps[pkg] = deps

for pkg in updates:
    if pkg in custom_deps:
        for dep in custom_deps[pkg]:
            matched_dep = None
            for p in updates:
                if p == dep or p.startswith(dep + "-") or dep.startswith(p + "-"):
                    matched_dep = p
                    break
            
            if matched_dep and matched_dep != pkg:
                graph[pkg].add(matched_dep)
    elif pkg in pkg_urls:
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

KDE_PKGS = {"extra-cmake-modules", "breeze-icons", "frameworks6", "frameworks", "plasma-all", "plasma"}
have_kde = any(p in KDE_PKGS or "frameworks" in p or "plasma" in p for p in updates)

def fetch_frameworks_order():
    if not have_kde:
        return []
    try:
        req = urllib.request.Request(f"{blfs_book}/kde/frameworks6.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
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
    if not have_kde:
        return []
    try:
        req = urllib.request.Request(f"{blfs_book}/kde/plasma-all.html", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
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
' "${all_updates[@]}")

        if [[ -n "$sorted_updates" ]]; then
            all_updates=()
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && all_updates+=("$pkg")
            done <<< "$sorted_updates"
        fi

        echo "Applying updates in dependency order:"
        for pkg in "${all_updates[@]}"; do
            echo "  - $pkg"
        done
        echo ""

        for pkg in "${all_updates[@]}"; do
            local build_args=()
            if [[ "$dry_run" == "true" ]]; then build_args+=("--dry-run"); fi
            if [[ "$upstream" != "true" ]]; then
                build_args+=("--no-upstream")
            fi
            
            # Force rebuild if this package only has a missing inventory (not a version update)
            local is_force=false
            for fp in "${force_rebuild_pkgs[@]}"; do
                [[ "$fp" == "$pkg" ]] && is_force=true && break
            done
            [[ "$is_force" == "true" ]] && build_args+=("-f")

            # Check if it is a custom package
            local is_custom=false
            for cp in "${custom_updates_list[@]}"; do
                [[ "$cp" == "$pkg" ]] && is_custom=true && break
            done

            if [[ "$dry_run" == "true" ]]; then
                if [[ "$is_custom" == "true" ]]; then
                    echo "DRY RUN: lfs_autobuild (custom) ${build_args[*]} $pkg"
                else
                    echo "DRY RUN: lfs_autobuild (book) ${build_args[*]} $pkg"
                fi
                lfs_autobuild "${build_args[@]}" "$pkg"
            else
                if [[ "$is_custom" == "true" ]]; then
                    echo "Building custom package $pkg..."
                else
                    echo "Building book package $pkg..."
                fi
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
                            for p in "${all_updates[@]}"; do
                                if [[ "$p" == "$dep_pkg" ]]; then already_in=true; break; fi
                            done
                            if [[ "$already_in" == "false" && "$dep_pkg" != "$pkg" ]]; then
                                echo "    -> Found dependent: $dep_pkg (needs rebuild)"
                                all_updates+=("$dep_pkg")
                            fi
                        fi
                    done <<< "$dependents"
                    
                    # Register for final cleanup
                    echo "$lib" | sudo tee -a /tmp/lfs_preserved_rm_list.txt > /dev/null
                done <<< "$libs"
            fi
        done

        # Final cleanup of preserved libraries that are no longer needed
        if ssh_lfs "[ -f /tmp/lfs_preserved_rm_list.txt ]"; then
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
            done < /tmp/lfs_preserved_rm_list.txt && sudo rm -f /tmp/lfs_preserved_rm_list.txt'
        fi
    fi

    echo "Updating Python packages via pip..."
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: pip3 list --outdated 2>/dev/null | tail -n +3 | cut -d ' ' -f 1 | xargs -r sudo pip3 install -U"
    else
        ssh_lfs "pip3 list --outdated 2>/dev/null | tail -n +3 | cut -d ' ' -f 1 | xargs -r sudo pip3 install -U"
    fi

    echo "Updating Julia with juliaup..."
    if [[ "$dry_run" == "true" ]]; then
        echo "DRY RUN: juliaup update"
    else
        ssh_lfs 'export PATH=$PATH:$HOME/.juliaup/bin && juliaup update'
    fi

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
    ssh_lfs "~/.lfs_scripts/upos.sh"
}


lfs_updc() {
    lfs_update "$@"

    local broken_pkgs=$(ssh_lfs 'find /var/lib/book-packages /var/lib/custom-packages -maxdepth 1 -type f ! -name ".*" 2>/dev/null | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" | while read -r f; do (head -n 1 "$f" | grep -q "^BUILD_FAILED$" || [ $(wc -l < "$f") -le 1 ]) && basename "$f"; done' 2>/dev/null | tr -d '\r')

    if [ -z "$broken_pkgs" ]; then
        rm_old_libs
        rm_old_docs
        rm_old_kerns
        rm_old_share
        rm_book_src
        rm_lfp_src
        lfs_commit
    else
        echo "Build failures or missing inventories detected for the following packages:"
        echo "$broken_pkgs"
        echo "Skipping cleanup."
    fi
}
unalias lfs_updatec 2>/dev/null
alias lfs_updatec='lfs_updc'
unalias updatec 2>/dev/null
function updatec { lfs_updc "$@"; }
unalias update 2>/dev/null
function update { lfs_update "$@"; }
