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


# Source the modularized scripts if they exist
for script in lfs-sync-to-vm.sh lfs-libs.sh lfs-kerns.sh lfs-share.sh lfs-autoremove.sh lfs-update.sh lfs-autobuild-func.sh; do
    if [[ -n "$NIXCFG" && -f "$NIXCFG/shell/user/$script" ]]; then
        source "$NIXCFG/shell/user/$script"
    elif [[ -f "${HOME}/.lfs_scripts/$script" ]]; then
        source "${HOME}/.lfs_scripts/$script"
    fi
done

if [[ -n "$NIXCFG" && -f "$NIXCFG/shell/user/08-ssh.sh" ]]; then
    function lfs_com {
        ssh_lfs "source ~/.zshrc ; $@"
    }

    function rm_old_share {
        lfs_com "rm_old_share"
    }

    function rm_old_kerns {
        lfs_com "rm_old_kerns"
    }

    function rm_book_src {
        lfs_com "rm_book_src"
    }

    function rm_lfp_src {
        lfs_com "rm_lfp_src"
    }

    function rm_src {
        rm_book_src
        rm_lfp_src
    }

    # Short aliases without lfs_ prefix for host-side commands.
    autobuild()   { lfs_autobuild "$@"; }
    autoremove()  { lfs_autoremove "$@"; }
    updates()     { bash "$NIXCFG/shell/user/lfs-updates.sh" "$@"; }
    commit() {
        source "$NIXCFG/shell/user/08-ssh.sh"
        source "$NIXCFG/shell/user/18-vms.sh" >/dev/null 2>&1
        ssh_lfs "bash -c 'source ~/.lfs_scripts/lfs-vm-bootstrap.sh 2>/dev/null && lfs_package_commit $(printf '%q ' "$@")'"
    }
fi
