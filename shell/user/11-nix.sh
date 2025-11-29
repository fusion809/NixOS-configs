function nixcg {
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

function nixfrb {
  if [[ $PWD != $NIXCFG ]]; then
    pushd -q $NIXCFG
    git add --all
    popd -q
  else
    git add --all
  fi
  sudo nixos-rebuild switch -I nixos-config="$NIXCFG/nix/configuration.nix" --flake "$NIXCFG/nix/#nixos" --impure
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
  nixfrb
}

# First argument is the repository, e.g. nixpkgs, second is the package regex
function nixs {
  nix search $1 $2
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
  instVer=$(sudo nix-channel --list | grep "^nixos " | cut -d '/' -f 5)
  echo "The installed release of NixOS is ${instVer/nixos-/}..."
  if [[ $latVer != $instVer ]]; then
    echo "NixOS is out of date. Upgrading..."
    if `git -C $NIXCFG branch | grep $latVer &> /dev/null`; then
      git -C $NIXCFG checkout $latVer
      nix flake update $NIXCFG || echo "Failed to update flake." && return
    else
      git -C $NIXCFG checkout -b $latVer
      sed -i -e "s|$instVer|$latVer|g" $NIXCFG/flake.nix || echo "Failed to update flake.nix." && return
      nix flake update $NIXCFG || echo "Failed to update flake." && return
      push "Initial commit of new branch"
    fi
    echo "Updating channels, not strictly necessary with flake setup..."
    sudo nix-channel --add https://nixos.org/channels/nixos-$latVer nixos
    sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-$latVer.tar.gz home-manager
    echo "Upgrading to NixOS $latVer..."
    nixfrb || echo "Failed to upgrade to NixOS $latVer." && return
    echo "Upgrade complete."
  else
    echo "You're already running the latest version of NixOS."
  fi
}

# Auto-check for upgrades every 12 hours
if [[ $- == *i* ]] && [[ -f $HOME/.cache/last_upgrade_check ]]; then
  last_check=$(cat $HOME/.cache/last_upgrade_check)
  current_time=$(date +%s)
  time_diff=$((current_time - last_check))
  # 12 hours = 43200 seconds
  if [[ $time_diff -ge 43200 ]]; then
    upgrade
    date +%s > $HOME/.cache/last_upgrade_check
  fi
elif [[ $- == *i* ]]; then
  # First time, create the file and run upgrade
  mkdir -p $HOME/.cache
  date +%s > $HOME/.cache/last_upgrade_check
  upgrade
fi
