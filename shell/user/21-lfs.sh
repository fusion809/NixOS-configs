# LFS/BLFS update management logic
export NIXCFG="${NIXCFG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LFS_DEV_BOOK="https://www.linuxfromscratch.org/lfs/view/development"
BLFS_DEV_BOOK="https://linuxfromscratch.org/blfs/view/systemd"

lfs_autobuild() {
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    # Sync the latest host script to the VM, then execute it there.
    # This ensures the VM always uses the host's current version,
    # and also makes lfs_autobuild available natively in the VM's zsh session.
    ssh_lfs "cat > ~/.lfs_autobuild.sh && chmod +x ~/.lfs_autobuild.sh" \
        < "$NIXCFG/shell/user/lfs-autobuild.sh"
    ssh_lfs "bash ~/.lfs_autobuild.sh $(printf '%q ' "$@")"
}


lfs_get_upstream_version() {
    local pkg="$1"
    case "$pkg" in
        rustc)
            curl -s https://static.rust-lang.org/dist/channel-rust-stable.toml | perl -ne 'if (/^\[pkg\.rust\]/) { $in=1 } elsif ($in && /^version\s*=\s*"([0-9.]+)/) { print $1; exit }'
            ;;
        llvm)
            curl -s -H "User-Agent: bash" https://api.github.com/repos/llvm/llvm-project/releases/latest | perl -nle 'while (m{"tag_name":\s*"llvmorg-([0-9.]+)"}g) { print $1 }' | head -n 1
            ;;
        libuv)
            curl -s -H "User-Agent: bash" https://api.github.com/repos/libuv/libuv/releases/latest | perl -nle 'while (m{"tag_name":\s*"v([0-9.]+)"}g) { print $1 }' | head -n 1
            ;;
        vim)
            VIM_TAG=$(curl -sL -H "User-Agent: bash" https://github.com/vim/vim/tags | perl -nle 'while (m{href="/vim/vim/releases/tag/v\K[0-9.]+}g) { print $& }' | head -n 1)
            if [[ -z "$VIM_TAG" ]]; then
                VIM_TAG=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | perl -nle 'while (m{(?<="tag_name": "v)[0-9.]+}g) { print $& }' | head -n 1)
            fi
            echo "$VIM_TAG"
            ;;
        firefox)
            curl -s https://product-details.mozilla.org/1.0/firefox_versions.json | perl -nle 'while (m{(?<="LATEST_FIREFOX_VERSION": ")[0-9.]+}g) { print $& }'
            ;;
        frameworks|frameworks6)
            curl -sL https://download.kde.org/stable/frameworks/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        plasma|plasma-all)
            curl -sL https://download.kde.org/stable/plasma/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
        konsole|dolphin|dolphin-plugins|gwenview|libkdcraw|okular|kdenlive)
            curl -sL https://download.kde.org/stable/release-service/ | perl -nle 'while (m{href="\K[0-9]+\.[0-9]+\.[0-9]+}g) { print $& }' | sort -V | tail -n 1
            ;;
    esac
}

lfs_get_remote_packages() {
    local upstream=false
    if [[ "$1" == "--upstream" ]]; then
        upstream=true
    fi

    KERNEL_VER=$(curl -s -H "User-Agent: bash" https://www.kernel.org/ | grep -A 1 -E "mainline:|stable:" | grep -v "rc" | grep -oP '[0-9.]+' | sort -Vr | head -n 1)
    VIM_VER=$(curl -sL -H "User-Agent: bash" https://github.com/vim/vim/tags | grep -oP 'href="/vim/vim/releases/tag/v\K[0-9.]+' | head -n 1)
    if [[ -z "$VIM_VER" ]]; then
        VIM_VER=$(curl -s -H "User-Agent: bash" https://api.github.com/repos/vim/vim/releases/latest | grep -oP '(?<="tag_name": "v)[0-9.]+' | head -n 1)
    fi
    JDK_MAJOR=$(curl -s https://jdk.java.net/ | grep -oP 'href="\./\K[0-9]+' | sort -rn | head -n 1)
    if [[ -n "$JDK_MAJOR" ]]; then
        JDK_TARBALL=$(curl -s "https://jdk.java.net/${JDK_MAJOR}/" | grep -oP 'https://download.java.net/java/.*?/openjdk-[0-9]+.*?_linux-x64_bin.tar.gz' | head -n 1)
        JDK_VER=$(echo "$JDK_TARBALL" | grep -oP 'openjdk-\K[0-9a-zA-Z\+\.\-]+(?=_linux-x64_bin)')
        JDK_REMOTE="openjdk-${JDK_VER}_linux-x64_bin"
    fi
    # LFS packages are in links ending in .tar.* or .zip
    local lfs_remote=$(curl -s "$LFS_DEV_BOOK/chapter03/packages.html" | tr -d '\r' | \
        grep -oP '[a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-]*\.(tar\.[a-z2]+|zip)' | \
        sed 's/\.tar.*//; s/\.zip//' | \
        sed "s|^linux-[0-9.]*$|linux-${KERNEL_VER}|g" | \
        sed "s|^[Vv]im-[0-9.]*$|vim-${VIM_VER}|g" | \
        sort -u)

    # BLFS longindex has package-version in <a> tags or before " -- "
    local blfs_remote=$(curl -s "$BLFS_DEV_BOOK/longindex.html" | tr -d '\r' | \
        perl -0777 -ne 'while (/SpiderMonkey:.*?firefox-([0-9.]+)/gs) { print "spidermonkey-$1\n" } while (/>([a-zA-Z0-9_\+\-]+\-[0-9][a-zA-Z0-9_\+\-\.]+)<\/a>/gs) { print "$1\n" }' | \
        sed "/[Vv]im-[0-9.]*$/d" | \
        sort -u)
    
    local all_pkgs=$(echo -e "${lfs_remote}\n${blfs_remote}\n${JDK_REMOTE}" | grep -v "^$" | sort -u | tr -d '\r')

    if [[ "$upstream" == "true" ]]; then
        local upstream_list="rustc llvm libuv vim firefox frameworks frameworks6 plasma konsole dolphin dolphin-plugins gwenview libkdcraw okular kdenlive"
        for p in $upstream_list; do
            local uv=$(lfs_get_upstream_version "$p")
            if [[ -n "$uv" ]]; then
                # Remove existing (case-insensitive) and add upstream
                all_pkgs=$(echo "$all_pkgs" | grep -vEi "^${p}-([0-9])")
                all_pkgs=$(echo -e "${all_pkgs}\n${p}-${uv}")
            fi
        done
        all_pkgs=$(echo "$all_pkgs" | sort -u)
    fi

    echo "$all_pkgs" | grep -v "^$"
}

lfs_get_local_packages() {
    # Ensure dependencies are available
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
    
    ssh_lfs "find /sources/archives -type f ! -name '*.patch*' 2>/dev/null | tr -d '\r'" | \
        sed 's|.*/||; s/\.tar\.[a-z2]\+//; s/\.zip$//; s/\.patch\.[a-z2]\+//; s/\.[a-z2]\+$//; s/-apng$//' | \
        sed 's/^firefox-\([0-9].*esr\.source\)/spidermonkey-\1/' | \
        grep -vE "^$|-docs-html|-systemd" | \
        sort -u
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
    # Ensure dependencies are available
    source "$NIXCFG/shell/user/08-ssh.sh"
    source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1

    local script=$(cat <<'EOF'
    sudo mkdir -p /var/lib/lfs-custom-packages 2>/dev/null || true
    for build_script in $(find ~/lfs_packaging -mindepth 2 -maxdepth 4 -name "build.sh" 2>/dev/null); do
        pkg_dir=$(dirname "$build_script")
        name_line=$(grep -E '^[A-Z_]*NAME=' "$build_script" | head -n 1)
        if [ -n "$name_line" ]; then
            pkg_name=$(echo "$name_line" | cut -d= -f2 | tr -d '"' | tr -d "'")
        else
            pkg_name=$(basename "$pkg_dir")
        fi
        
        # 1. Get local version
        local_ver="none"
        if [ -f "/var/lib/lfs-custom-packages/$pkg_name" ]; then
            local_ver=$(cat "/var/lib/lfs-custom-packages/$pkg_name" 2>/dev/null || echo "none")
        fi
        
        # 2. Get remote version
        remote_ver=""
        status="OK"
        version_line_num=$(grep -nE '^[a-z_]*version=' "$build_script" | head -n 1 | cut -d: -f1)
        if [ -n "$version_line_num" ]; then
            head -n "$version_line_num" "$build_script" > /tmp/eval_ver.sh
            var_name=$(grep -E '^[a-z_]*version=' "$build_script" | head -n 1 | cut -d= -f1)
            echo "echo \$$var_name" >> /tmp/eval_ver.sh
            remote_ver=$(cd "$pkg_dir" && bash /tmp/eval_ver.sh 2>/dev/null | tail -n 1)
            rm -f /tmp/eval_ver.sh
            if [ -z "$remote_ver" ]; then
                status="FAILED"
            fi
        fi
        
        # If no version line, try to determine git remote head
        if [ -z "$remote_ver" ] && [ "$status" == "OK" ] && grep -q "git clone" "$build_script"; then
            repo_url=$(grep -oP 'git clone \K[^ ]+' "$build_script" | head -n 1)
            if [ -n "$repo_url" ]; then
                remote_ver=$(git ls-remote "$repo_url" HEAD 2>/dev/null | awk '{print $1}')
                if [ -z "$remote_ver" ]; then
                    status="FAILED"
                fi
            fi
        fi

        if [ -z "$remote_ver" ] && [ "$status" == "OK" ]; then
            status="MISSING"
        fi
        
        if [ "$status" != "OK" ]; then
            echo "$pkg_name $status $status"
        elif [ -n "$remote_ver" ]; then
            if [ "$local_ver" == "none" ]; then
                # Also check by directory basename (fallback for packages that registered under dir name)
                dir_name=$(basename "$pkg_dir")
                if [ -f "/var/lib/lfs-custom-packages/$dir_name" ]; then
                    local_ver=$(cat "/var/lib/lfs-custom-packages/$dir_name" 2>/dev/null || echo "none")
                fi
            fi
            if [ "$local_ver" != "$remote_ver" ]; then
                # Handle short hash: if local is a prefix of remote, treat as same version
                if [[ "${#local_ver}" -ge 7 && "${#local_ver}" -le 12 && "${remote_ver#$local_ver}" != "$remote_ver" ]]; then
                    : # same
                else
                    echo "$pkg_name $local_ver $remote_ver"
                fi
            fi
        fi
    done
EOF
)
    ssh_lfs "bash -c '$(echo "$script" | sed "s/'/'\\\\''/g")'" 2>/dev/null | grep -vE "^(Warning:|Connection|IP|SSH|grep:)"
}

lfs_update_all() {
    local dry_run=false
    local upstream=false
    while [[ "$1" == "-"* ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --upstream) upstream=true ;;
        esac
        shift
    done



    echo "Fetching remote package list $([[ "$upstream" == "true" ]] && echo "including upstream " )from Development books..."
    local remote_list=$(lfs_get_remote_packages $([[ "$upstream" == "true" ]] && echo "--upstream"))
    echo "Fetching local package list from VM..."
    local local_list=$(lfs_get_local_packages)

    echo "Checking for updates..."
    local updates=()

    while read -r local_pkg; do
        [[ -z "$local_pkg" ]] && continue
        
        # Exclude auxiliary texlive archives to prevent false positive updates against texlive-*-source
        if [[ "$local_pkg" == texlive-*-texmf* ]] || [[ "$local_pkg" == texlive-*-extra* ]]; then
            continue
        fi

        local name=$(echo "$local_pkg" | sed -E 's/^([a-zA-Z0-9_\+\-]+)-[0-9].*/\1/')
        local local_ver=$(echo "$local_pkg" | sed -E 's/^[a-zA-Z0-9_\+\-]+-([0-9].*)/\1/')

        [[ -z "$name" || "$name" == "$local_pkg" ]] && continue

        # Find matching package in remote list (case-insensitive)
        local remote_pkg=$(echo "$remote_list" | grep -Ei "^${name}-([0-9])" | head -n 1)
        
        if [[ -n "$remote_pkg" ]]; then
            local remote_ver=$(echo "$remote_pkg" | sed -E "s/^.{${#name}}-//I")
            
            if [[ "$local_ver" != "$remote_ver" ]]; then
                local higher=$(echo -e "$local_ver\n$remote_ver" | sort -V | tail -n 1)
                if [[ "$higher" == "$remote_ver" ]]; then
                    echo "Found update: $name ($local_ver -> $remote_ver)"
                    updates+=("$name")
                fi
            fi
        fi
    done <<< "$local_list"

    # Also check custom updates
    local custom_updates_list=()
    local custom_updates=$(lfs_check_custom_updates)
    while read -r update_line; do
        [[ -z "$update_line" ]] && continue
        local name=$(echo "$update_line" | awk '{print $1}')
        local local_ver=$(echo "$update_line" | awk '{print $2}')
        local remote_ver=$(echo "$update_line" | awk '{print $3}')
        echo "Found custom update: $name ($local_ver -> $remote_ver)"
        custom_updates_list+=("$name")
    done <<< "$custom_updates"

    if [[ ${#updates[@]} -eq 0 && ${#custom_updates_list[@]} -eq 0 ]]; then
        echo "No updates found."
        return 0
    fi

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

# Build graph: node -> set of depends-on nodes (edges from dependency to dependent)
# We want to build graph where A depends on B -> B must come before A
# The graph for topological sort typically expects: node -> iterable of nodes it depends on
# We will use graphlib if available (Python 3.9+) or do a simple Kahn array sort.

pkg_urls = {}
for pkg in updates:
    search_pkg = pkg
    if re.match(r"^gst-plugins-(base|good|bad|ugly)$", pkg):
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
        else:
            # Not fully resolving LFS pages here as they rarely depend on BLFS.
            # Assuming LFS packages just have no deps mapped for now
            pass

graph = {pkg: set() for pkg in updates}

for pkg in updates:
    if pkg in pkg_urls:
        deps = extract_deps(pkg_urls[pkg])
        # Only care about dependencies that are also in the update list
        for dep in deps:
            # We need to map the parsed page name back to our update list name
            # which could be an exact match, or a prefix match (e.g. gstreamer matches gstreamer)
            matched_dep = None
            for p in updates:
                # If the dependency page name is the package, or package starts with page name
                if p == dep or p.startswith(dep + "-") or dep.startswith(p + "-"):
                    matched_dep = p
                    break
            
            if matched_dep and matched_dep != pkg:
                graph[pkg].add(matched_dep)

# Perform topological sort
def toposort(graph):
    # Calculate in-degrees (how many things does a node depend on)
    in_degree = {u: len(graph[u]) for u in graph}
    
    queue = [u for u in in_degree if in_degree[u] == 0]
    result = []
    
    while queue:
        u = queue.pop(0)
        result.append(u)
        
        # When u is resolved, anything depending on u gets -1 to their in_degree
        for v in graph:
            if u in graph[v]:
                in_degree[v] -= 1
                if in_degree[v] == 0:
                    queue.append(v)
                    
    # Handle cycles or missing nodes by just appending whatever is left
    for node in graph:
        if node not in result:
            result.append(node)
            
    return result

sorted_pkgs = toposort(graph)
for pkg in sorted_pkgs:
    print(pkg)
' "${updates[@]}")

    if [[ -n "$sorted_updates" ]]; then
        mapfile -t updates <<< "$sorted_updates"
    fi

    echo "Applying updates in dependency order:"
    for pkg in "${updates[@]}"; do
        echo "  - $pkg"
    done
    echo ""

    for pkg in "${updates[@]}"; do
        local build_args=()
        [[ "$dry_run" == "true" ]] && build_args+=("--dry-run")
        [[ "$upstream" == "true" ]] && build_args+=("--upstream")
        
        if [[ "$dry_run" == "true" ]]; then
            echo "DRY RUN: $NIXCFG/shell/user/lfs-autobuild.sh ${build_args[*]} $pkg"
            "$NIXCFG/shell/user/lfs-autobuild.sh" "${build_args[@]}" "$pkg"
        else
            echo "Building $pkg..."
            "$NIXCFG/shell/user/lfs-autobuild.sh" "${build_args[@]}" "$pkg"
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
        echo "DRY RUN: sudo pip3 install --upgrade pyparsing attrs numpy sphinx pyqt-builder pyopengl sip pyqt6-sip"
    else
        ssh_lfs "sudo pip3 install --upgrade pyparsing attrs numpy sphinx pyqt-builder pyopengl sip pyqt6-sip"
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
            [[ "$dry_run" == "true" ]] && build_args+=("--dry-run")
            [[ "$upstream" == "true" ]] && build_args+=("--upstream")

            if [[ "$dry_run" == "true" ]]; then
                echo "DRY RUN: $NIXCFG/shell/user/lfs-autobuild.sh ${build_args[*]} $pkg"
                "$NIXCFG/shell/user/lfs-autobuild.sh" "${build_args[@]}" "$pkg"
            else
                echo "Building custom package $pkg..."
                "$NIXCFG/shell/user/lfs-autobuild.sh" "${build_args[@]}" "$pkg"
            fi
        done
    fi
}
