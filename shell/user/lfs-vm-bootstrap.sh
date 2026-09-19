#!/usr/bin/env bash
# LFS VM Bootstrap - Auto-synced from host via sync_to_vm
# Provides `updates` and `update` commands inside the LFS VM.
# DO NOT EDIT MANUALLY - changes will be overwritten on next sync.

# ---- Local passthrough for ssh_lfs (we ARE the VM) ----
ssh_lfs() {
    local cmd="$1"
    shift
    case "$cmd" in
        "bash -s")
            bash -s "$@"
            ;;
        *)
            eval "$cmd" "$@"
            ;;
    esac
}
if [ -n "$BASH_VERSION" ]; then
    export -f ssh_lfs
fi

# NIXCFG is not meaningful inside the VM, but 21-lfs.sh needs it set.
export NIXCFG="${HOME}/.lfs_scripts"

# Source the main helper library
if [[ -f "${HOME}/.lfs_scripts/21-lfs.sh" ]]; then
    source "${HOME}/.lfs_scripts/21-lfs.sh"
fi

# ---- VM-side command aliases ----
# `updates` = lfs_updates (with optional --upstream flag)
updates() {
    bash "${HOME}/.lfs_scripts/lfs-updates.sh" "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f updates
fi

# Helper to format package list with English grammar / Oxford comma
_lfs_format_pkg_list() {
    local -a items=("$@")
    local n=${#items[@]}
    if [ "$n" -eq 0 ]; then
        echo ""
    elif [ "$n" -eq 1 ]; then
        echo "${items[0]}"
    elif [ "$n" -eq 2 ]; then
        echo "${items[0]} and ${items[1]}"
    else
        local res=""
        for ((i=0; i<n-1; i++)); do
            res+="${items[i]}, "
        done
        res+="and ${items[n-1]}"
        echo "$res"
    fi
}

# ---- Commit and Push Registry Changes ----
lfs_package_commit() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: lfs_commit [message]"
        echo "Example: lfs_commit 'Updated kernel to 6.6.1'"
        echo "If no message is provided, one will be auto-generated based on changes."
        return 0
    fi

    # Safety check: refuse to commit if any inventory is broken (≤1 line = only version
    # header, or BUILD_FAILED marker written by the failure trap in lfs-autobuild.sh).
    local broken_pkgs
    broken_pkgs=$(find /var/lib/book-packages /var/lib/custom-packages \
        -maxdepth 1 -type f ! -name ".*" 2>/dev/null \
        | grep -vE "/(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$" \
        | while read -r f; do
            if [ "$(wc -l < "$f")" -le 1 ] || grep -q "^BUILD_FAILED$" "$f" 2>/dev/null; then
                basename "$f"
            fi
          done)
    if [[ -n "$broken_pkgs" ]]; then
        echo "ERROR: Refusing to commit — the following packages have missing/broken inventories:"
        echo "$broken_pkgs"
        echo "Fix them (re-run lfs_autobuild for each), then retry lfs_package_commit."
        return 1
    fi

    local msg="$1"
    local shared_msg=""
    local shared_has_updates=false
    local shared_has_rebuilds=false

    for dir in /var/lib/book-packages /var/lib/custom-packages; do
        if [ -d "$dir/.git" ]; then
            pushd "$dir" >/dev/null || continue
            local final_msg=""
            local has_updates=false
            local has_rebuilds=false

            if [ -n "$msg" ]; then
                final_msg="$msg"
            else
                local changes=""
                local -a rebuilt_pkgs=()

                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local filepath="${line:3}"
                    filepath="${filepath%\"}"
                    filepath="${filepath#\"}"
                    if [[ "$filepath" =~ ' -> ' ]]; then
                        filepath="${filepath##* -> }"
                    fi
                    local name=$(basename "$filepath")
                    [[ "$name" =~ ^(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$ ]] && continue
                    [[ "$name" =~ ^\.git ]] && continue
                    [ -f "$filepath" ] || continue

                    local new_v=$(head -n 1 "$filepath" 2>/dev/null | tr -d '[:space:]' | sed 's/\.tar.*//')
                    local old_v=""
                    if ! git rev-parse --verify "HEAD:$filepath" >/dev/null 2>&1; then
                        old_v="NEW"
                    else
                        old_v=$(git show "HEAD:$filepath" 2>/dev/null | head -n 1 | tr -d '[:space:]' | sed 's/\.tar.*//')
                    fi

                    if [ "$old_v" = "NEW" ]; then
                        changes+="${name}: ${new_v} (NEW); "
                        has_updates=true
                    elif [ -n "$new_v" ] && [ "$old_v" != "$new_v" ]; then
                        changes+="${name}: ${old_v}->${new_v}; "
                        has_updates=true
                    else
                        rebuilt_pkgs+=("$name")
                        has_rebuilds=true
                    fi
                done < <(git status --porcelain 2>/dev/null)

                local v_msg=""
                local r_msg=""
                if [ -n "$changes" ]; then
                    v_msg="${changes%; }."
                fi
                if [ ${#rebuilt_pkgs[@]} -gt 0 ]; then
                    local -a unique_rebuilds=()
                    while IFS= read -r pkg; do
                        [ -n "$pkg" ] && unique_rebuilds+=("$pkg")
                    done < <(printf "%s\n" "${rebuilt_pkgs[@]}" | sort -u)
                    r_msg="Rebuilding $(_lfs_format_pkg_list "${unique_rebuilds[@]}")"
                fi

                if [ "$has_updates" = true ] && [ "$has_rebuilds" = true ]; then
                    final_msg="${v_msg} ${r_msg}"
                elif [ "$has_updates" = true ]; then
                    final_msg="${v_msg}"
                elif [ "$has_rebuilds" = true ]; then
                    final_msg="${r_msg}"
                elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                    final_msg="Updating packages"
                fi
            fi

            # Check if there are changes in working tree to commit
            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                git add -A
                if [ -z "$msg" ] && [ ${#final_msg} -gt 72 ]; then
                    local short_msg=""
                    if [ "$has_updates" = true ] && [ "$has_rebuilds" = true ]; then
                        short_msg="Updating and rebuilding packages"
                    elif [ "$has_rebuilds" = true ]; then
                        short_msg="Rebuilding packages"
                    else
                        short_msg="Updating packages"
                    fi
                    echo "Committing updates in $dir: $short_msg"
                    git commit -m "$short_msg" -m "$final_msg" 2>/dev/null
                else
                    echo "Committing updates in $dir: $final_msg"
                    git commit -m "$final_msg" 2>/dev/null
                fi
            fi

            # Push if ahead of origin
            if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
                local branch=$(git rev-parse --abbrev-ref HEAD)
                if [ "$(git rev-list ${branch}...origin/${branch} --count 2>/dev/null || echo 1)" -gt 0 ]; then
                    echo "Pushing changes in $dir..."
                    git push origin "$branch" 2>/dev/null || true
                fi
            fi

            if [ -n "$final_msg" ]; then
                shared_msg="$final_msg"
                shared_has_updates="$has_updates"
                shared_has_rebuilds="$has_rebuilds"
            fi

            popd >/dev/null || true
        fi
    done

    # Commit and push in ~/build_duration
    if [ -d "$HOME/build_duration/.git" ]; then
        pushd "$HOME/build_duration" >/dev/null || return 0
        local bd_has_changes=false
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            bd_has_changes=true
        fi

        if [ "$bd_has_changes" = true ]; then
            local bd_msg=""
            local bd_has_updates=false
            local bd_has_rebuilds=false

            if [ -n "$msg" ]; then
                bd_msg="$msg"
            elif [ -n "$shared_msg" ]; then
                bd_msg="$shared_msg"
                bd_has_updates="$shared_has_updates"
                bd_has_rebuilds="$shared_has_rebuilds"
            else
                # Generate from build_duration's own changed files
                local -a bd_pkgs=()
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local filepath="${line:3}"
                    filepath="${filepath%\"}"
                    filepath="${filepath#\"}"
                    if [[ "$filepath" =~ ' -> ' ]]; then
                        filepath="${filepath##* -> }"
                    fi
                    local name=$(basename "$filepath")
                    [[ "$name" =~ ^(COMMIT_EDITMSG|HEAD|config|description|ORIG_HEAD)$ ]] && continue
                    [[ "$name" =~ ^\.git ]] && continue
                    bd_pkgs+=("$name")
                done < <(git status --porcelain 2>/dev/null)

                if [ ${#bd_pkgs[@]} -gt 0 ]; then
                    local -a unique_bd=()
                    while IFS= read -r pkg; do
                        [ -n "$pkg" ] && unique_bd+=("$pkg")
                    done < <(printf "%s\n" "${bd_pkgs[@]}" | sort -u)
                    bd_msg="Rebuilding $(_lfs_format_pkg_list "${unique_bd[@]}")"
                    bd_has_rebuilds=true
                else
                    bd_msg="Updating build duration logs"
                fi
            fi

            git add -A
            if [ -z "$msg" ] && [ ${#bd_msg} -gt 72 ]; then
                local bd_short=""
                if [ "$bd_has_updates" = true ] && [ "$bd_has_rebuilds" = true ]; then
                    bd_short="Updating and rebuilding packages"
                elif [ "$bd_has_rebuilds" = true ]; then
                    bd_short="Rebuilding packages"
                else
                    bd_short="Updating packages"
                fi
                echo "Committing changes in ~/build_duration: $bd_short"
                git commit -m "$bd_short" -m "$bd_msg" 2>/dev/null
            else
                echo "Committing changes in ~/build_duration: $bd_msg"
                git commit -m "$bd_msg" 2>/dev/null
            fi
        fi

        # Push if ahead of origin
        if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
            local branch=$(git rev-parse --abbrev-ref HEAD)
            if [ "$(git rev-list ${branch}...origin/${branch} --count 2>/dev/null || echo 1)" -gt 0 ]; then
                echo "Pushing changes in ~/build_duration..."
                git push origin "$branch" 2>/dev/null || true
            fi
        fi

        popd >/dev/null || true
    fi
}

if [ -n "$BASH_VERSION" ]; then
    export -f _lfs_format_pkg_list
    export -f lfs_package_commit
fi

# ---- Manual Commit Helper ----
lfs_commit() {
    lfs_package_commit "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f lfs_commit
fi

# `commit` = lfs_commit (no-prefix alias)
commit() {
    lfs_commit "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f commit
fi

# `update` = lfs_update
update() {
    lfs_update "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f update
fi

# `autobuild` = lfs_autobuild
autobuild() {
    lfs_autobuild "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f autobuild
fi

# `autoremove` = lfs_autoremove
autoremove() {
    lfs_autoremove "$@"
}
if [ -n "$BASH_VERSION" ]; then
    export -f autoremove
fi

