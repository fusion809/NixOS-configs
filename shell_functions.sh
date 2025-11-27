export NIXCFG=$HOME/GitHub/mine/config/NixOS-configs

function cdc {
  cd $HOME/Chem/$1
}

function cddc {
  cd $HOME/Documents/$1
}

function cddo {
  cd $HOME/Downloads/$1
}

function cdg {
  cd $HOME/GitHub/$1
}

function cdgo {
  cdg others/$1
}

function cdm {
  cd $HOME/Music/$1
}

function cdp {
  cd $HOME/Pictures/$1
}

function cdv {
  cd $HOME/Videos/$1
}

function cdvm {
  cd $HOME/VirtMachines/$1
}

function vbash {
  vim $HOME/.bashrc
}

function sbash {
  source $HOME/.bashrc
}

function vcf {
  sudo vim /etc/nixos/configuration.nix
}

function vhc {
  vim $HOME/.config/hypr/hyprland.conf
}

function vwc {
  vim $HOME/.config/waybar/config.jsonc
}

if [[ -v $HYPRLAND_INSTANCE_SIGNATURE ]]; then
  if `bt-device -l | grep -i "00:A4:1C:F5:00:63"` &> /dev/null; then
    bluetoothctl scan on
    bluetoothctl pair 00:A4:1C:F5:00:63
    bluetoothctl connect 00:A4:1C:F5:00:63
  fi
fi

function nixcg {
  sudo nix-store --add-root /nix/var/nix/gcroots/current-system --indirect -r $(readlink -f /run/current-system)
  sudo nix-collect-garbage -d
}

function git-branch {
  if ! [[ -n "$1" ]]; then
    git rev-parse --abbrev-ref HEAD
  else
    git -C "$1" rev-parse --abbrev-ref HEAD
  fi
}

function nixver {
  sudo nix-channel --list | grep nixos | cut -d '-' -f 2
}

function umount_arch {
  if `mountpoint -q /arch/boot`; then
    sudo umount /arch/boot -l
    sudo umount /arch -l
    touch ~/.cache/umount_arch
  fi
}

function mount_arch {
  if ! `mountpoint -q /arch` && ! [[ -f $HOME/.cache/umount_arch ]]; then
    sudo mount /dev/disk/by-label/arch /arch
    sudo mount /dev/disk/by-label/ARCHEFI /arch/boot
  elif [[ -f $HOME/.cache/umount_arch ]]; then
    echo '$HOME/.cache/umount_arch exists, so a Nix rebuild is likely happening...'
  fi
}

function mount_data {
  if ! `mountpoint -q /data`; then
    sudo mount '/dev/disk/by-label/Data\x20partition' /data
  fi
}

mount_data

function rebuild {
  umount_arch
  sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix
  rm -f $HOME/.cache/umount_arch
  mount_arch
}

alias nixrb=rebuild
function nixfrb {
  umount_arch
  sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix --flake $NIXCFG/#nixos --impure
  rm -f $HOME/.cache/umount_arch
  mount_arch
}

function nixrsu {
  nix flake update $NIXCFG
  nixfrb
}

function update {
  sudo nix-store --repair --verify --check-contents
  nixrsu
  nixcg
}

function clipf {
  if `ps ax | grep wayland &> /dev/null`; then
    wl-copy < $1
  else
    xclip -sel clip < $1
  fi
}

if ! [[ -d $HOME/.ssh ]] || ! [[ -f $HOME/.ssh/id_rsa.pub ]]; then
  mkdir -p $HOME/.ssh
  ssh-keygen -t rsa -b 4096 -C 'brentonhorne77@gmail.com'
  clipf $HOME/.ssh/id_rsa.pub
  echo 'GitHub SSH key generated and is now in your clipboard. Go to https://github.com/settings/ssh to register it to your account!'
fi

function rainbowfastfetch {
  hyfetch -p rainbow -b fastfetch --args='--localip-show-ipv4 false'
}

export NIXPKGS_ALLOW_INSECURE=1

function sclipf {
  sudo xclip -sel clip < $1
}

function nixstrep {
  sudo nix-store --repair --verify --check-contents
}

function push {
  git add --all
  git commit -m "$@"
  git push origin $(git-branch)
}

function pushf {
  git add --all
  git commit -m "$@"
  git push origin $(git-branch) -f
}

function gitsw {
  repo=$(git remote -v | grep fetch | grep origin | sed 's|.*github.com[/:]||g' | cut -d ' ' -f 1)
  git remote rm origin
  git remote add origin git@github.com:$repo
}

function cdnc {
  cd $NIXCFG/$1
}

function vhom {
  vim $NIXCFG/home.nix
}

alias vhx=vhom
function vrm {
  if [[ -f README.md ]]; then
    vim README.md
  else
    vim $NIXCFG/README.md
  fi
}
mount_arch

function vsnc {
  code $NIXCFG
}

function vshc {
  code $HOME/GitHub/mine/config/hyprland-configs
}

function comno {
	git rev-list --count HEAD
}

function revision {
	git log | head -n 1 | cut -d ' ' -f 2
}

function check_openra_update {
  pushd -q $HOME/GitHub/others/OpenRA
  git pull origin bleed -q
  latestRev=$(revision)
  popd -q
  packagedRev=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '"' -f 2)
  if [[ $latestRev != $packagedRev ]]; then
    echo "OpenRA git package is out of date. openraup will update it."
  fi
}
if [[ $- == *i* ]]; then
   check_openra_update
fi

function openraup {
  pushd -q $HOME/GitHub/others/OpenRA
  git pull origin bleed -q
  latestRev=$(revision)
  upno=$(comno)
  uphash=$(revision | head -c 7)
  popd -q
  packagedRev=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '"' -f 2)
  sed -i -e "s|$packagedRev|$latestRev|g" $NIXCFG/nixpkgs/openra/engines/git/default.nix
  latestHash=$(nix-prefetch-git --url https://github.com/OpenRA/OpenRA --rev $latestRev 2>&1 | grep '"hash"' | cut -d '"' -f 4)
  packagedHash=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'hash' | cut -d '"' -f 2)
  packagedVer=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'version' | cut -d '"' -f 2)
  latestVer="$upno.git.$uphash"
  sed -i -e "s|$packagedHash|$latestHash|g" -e "s|$packagedVer|$latestVer|g" $NIXCFG/nixpkgs/openra/engines/git/default.nix        
  nixrb
}

function upgrade {
  echo "Checking for NixOS updates..."
  latVer=$(wget -cqO- https://nixos.org/download/ | grep -i "nixos-[0-9]*\.[0-9]*" | head -n 1 | sed 's|.*https://channels.nixos.org/||g' | cut -d '/' -f 1)
  echo "The latest release of NixOS is ''${latVer/nixos-/}..."
  instVer=$(sudo nix-channel --list | grep "^nixos " | cut -d '/' -f 5)
  echo "The installed release of NixOS is ''${instVer/nixos-/}..."
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
