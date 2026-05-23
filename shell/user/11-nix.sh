function nixcg {
  # Clean up stale GC roots first to prevent disk bloat
  if [[ -d "$HOME/.cache/nix-gcroots" ]]; then
    rm -rf "$HOME/.cache/nix-gcroots"
  fi
  mkdir -p "$HOME/.cache/nix-gcroots"

  # Protect sources and build inputs of specific heavy/custom packages from GC to prevent re-downloads
  critical_pkgs=("OVMF" "unstable.winboat" "openra-git" "marvin")
  for pkg in "${critical_pkgs[@]}"; do
    # Use NIXCFG with --impure to ensure we can evaluate standard flake outputs and custom sources
    # We redirect stderr to suppress "evaluating..." messages
    
    # Protect Source
    echo "Protecting source for $pkg..."
    src_path=$(nix eval --impure --raw "$NIXCFG/nix#nixosConfigurations.nixos.pkgs.$pkg.src.outPath" 2>/dev/null)
    if [[ -n "$src_path" && -e "$src_path" ]]; then
      sudo nix-store --add-root "$HOME/.cache/nix-gcroots/src-$pkg" --indirect -r "$src_path" >/dev/null
    fi
    
    # Protect Build Output (Store Path)
    out_path=$(nix eval --impure --raw "$NIXCFG/nix#nixosConfigurations.nixos.pkgs.$pkg.outPath" 2>/dev/null)
    if [[ -n "$out_path" && -e "$out_path" ]]; then
      sudo nix-store --add-root "$HOME/.cache/nix-gcroots/out-$pkg" --indirect -r "$out_path" >/dev/null
    fi

    # Protect Build Inputs (Dependencies)
    # This prevents re-downloading build dependencies like dotnet-sdk when the package needs to be rebuilt
    nix eval --impure --json "$NIXCFG/nix#nixosConfigurations.nixos.pkgs.$pkg.nativeBuildInputs" 2>/dev/null | jq -r 'try .[] | if type=="string" then . else .outPath end // empty' | while read -r input_path; do
      if [[ -n "$input_path" && -e "$input_path" ]]; then
        name=$(basename "$input_path")
        sudo nix-store --add-root "$HOME/.cache/nix-gcroots/dep-$pkg-$name" --indirect -r "$input_path" >/dev/null
      fi
    done
    nix eval --impure --json "$NIXCFG/nix#nixosConfigurations.nixos.pkgs.$pkg.buildInputs" 2>/dev/null | jq -r 'try .[] | if type=="string" then . else .outPath end // empty' | while read -r input_path; do
      if [[ -n "$input_path" && -e "$input_path" ]]; then
        name=$(basename "$input_path")
        sudo nix-store --add-root "$HOME/.cache/nix-gcroots/dep-$pkg-$name" --indirect -r "$input_path" >/dev/null
      fi
    done
  done

  # Remove existing current-system root if it exists to avoid "already exists" error
  if [[ -L /nix/var/nix/gcroots/current-system ]]; then
    sudo rm /nix/var/nix/gcroots/current-system
  fi
  sudo nix-store --add-root /nix/var/nix/gcroots/current-system --indirect -r $(readlink -f /run/current-system)
  sudo nix-collect-garbage -d
}

# Accepted arguments are:
# * numbers of generations;
# * time periods, generations older than the period will be deleted; and 
# * "old" which will cause all older generations than current to be deleted. 
function nixdg {
  sudo nix-env --delete-generations $@ --profile /nix/var/nix/profiles/system
}


function nixdiff {
  generations=$(nixlg | awk '{print $1}' | tail -n 2)
  noGens=$(echo "$generations" | wc -l)
  if [[ $noGens -lt 2 ]]; then
    echo "Not enough generations to diff."
    return
  fi
  previousGen=$(echo "$generations" | head -n 1)
  currentGen=$(echo "$generations" | tail -n 1)
  diff=$(nix run nixpkgs#nvd -- diff /nix/var/nix/profiles/system-${previousGen}-link /nix/var/nix/profiles/system-${currentGen}-link)
  echo "$(date +"%r %D")" >> $HOME/.cache/systemChangeLog
  echo $diff >> $HOME/.cache/systemChangeLog
  echo $diff
}

function nixfrb {
  if [[ $PWD != $NIXCFG ]]; then
    git -C $NIXCFG add --all
  else
    git add --all
  fi
  sudo nixos-rebuild switch -I nixos-config="$NIXCFG/nix/configuration.nix" --flake "$NIXCFG/nix/#nixos" --impure || return
  # Snapshot the flake.lock used by this build so updates can compare against
  # what was actually installed, rather than what is currently at HEAD.
  cp "$NIXCFG/nix/flake.lock" "$HOME/.cache/last-built-flake.lock"
  nixdiff
  sed -i -e "2s|.*||g" $HOME/.cache/update
}

function nixfu {
  nix flake update --flake "$NIXCFG/nix"
}

# List generations of NixOS system
function nixlg {
  sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
}

function nixrsu {
  nixfu
  if [[ $(git -C $NIXCFG diff nix/flake.lock | wc -l) > 0 ]]; then
    nixfrb
  else
    echo "flake.lock has not been updated, so no updates available."
  fi
}

# First argument is the repository, e.g. nixpkgs, second is the package regex
function nixs {
  nix search --quiet "git+https://github.com/NixOS/nixpkgs.git?ref=$1" $2
}

function nixspc {
  nixs "$1" ".*" | grep "^\*" | wc -l
}

function nixstrep {
  sudo nix-store --repair --verify --check-contents
}

function nixver {
  sudo nix-channel --list | grep nixos | cut -d '-' -f 2
}

function rebuild {
  sudo nixos-rebuild switch -I nixos-config="$NIXCFG/nix/configuration.nix"
}

alias nixrb=rebuild

function rollback {
  sudo nixos-rebuild --rollback switch
}

function update {
  nixstrep
  nixrsu
  nixcg
}

function upgrade {
  echo "Checking for NixOS updates..."
  latVer=$(wget -cqO- https://nixos.org/download/ | grep -i "nixos-[0-9]*\.[0-9]*" | head -n 1 | sed 's|.*https://channels.nixos.org/||g' | cut -d '/' -f 1) 
  echo "The latest release of NixOS is ${latVer/nixos-/}..."
  instVer=$(cat /etc/os-release | grep "^VERSION_ID" | cut -d '"' -f 2)
  echo "The installed release of NixOS is $instVer..."
  echo "NIXCFG=$NIXCFG"
  if [[ ${latVer/nixos-/} != $instVer ]]; then
    echo "NixOS is out of date. Upgrading..."
    git -C $NIXCFG checkout -b ${latVer/nixos-/}
    sed -i -e "s|$instVer|${latVer/nixos-/}|g" $NIXCFG/nix/flake.nix || echo "Failed to update flake.nix." && return
    nix flake update --flake $NIXCFG/nix || echo "Failed to update flake." && return
    push "Initial commit of new branch"
    echo "Upgrading to NixOS ${latVer/nixos-/}..."
    nixfrb || echo "Failed to upgrade to NixOS ${latVer/nixos-/}." && return
    echo "Upgrade complete."
  else
    echo "You're already running the latest version of NixOS."
  fi
  date +%s > $HOME/.cache/last_upgrade_check
}

function nearEOL {
  eol_date=$(cat /etc/os-release | grep "^SUPPORT_END" | cut -d '"' -f 2)
  eol_secs=$(date -d "$eol_date" +%s);
  release_date=$(($eol_secs - 40*24*60*60)); # Let us estimated that within 40 days of the EOL date, we may wish to start checking for the new release.
  if [[ $(date +%s) -ge $release_date ]]; then
    true
  else
    false
  fi
}

# Auto-check for upgrades every 12 hours once we're 35 days from the EOL of current release.
if [[ $- == *i* ]] && [[ -f $HOME/.cache/last_upgrade_check ]] && nearEOL; then
  last_check=$(cat $HOME/.cache/last_upgrade_check)
  current_time=$(date +%s)
  time_diff=$((current_time - last_check))
  if [[ $time_diff -ge $((12*60*60)) ]]; then
    upgrade
  fi
elif [[ $- == *i* ]] && nearEOL; then
  # First time, create the file and run upgrade
  mkdir -p $HOME/.cache
  upgrade
fi
