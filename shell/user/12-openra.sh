git -C $GHUBO/OpenRA pull origin bleed -q
export latestRev=$(revision $GHUBO/OpenRA)
export packagedRev=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'rev' | cut -d '"' -f 2)

function check_openra_update {
  if [[ $latestRev != $packagedRev ]]; then
    echo "OpenRA git package is out of date. openraup will update it."
  fi
}
if [[ $- == *i* ]]; then
   check_openra_update
fi

function openraup {
  upno=$(comno $GHUBO/OpenRA)
  uphash=$(echo $latestRev | head -c 7)
  sed -i -e "s|$packagedRev|$latestRev|g" $NIXCFG/nixpkgs/openra/engines/git/default.nix
  latestHash=$(nix-prefetch-git --url https://github.com/OpenRA/OpenRA --rev $latestRev 2>&1 | grep '"hash"' | cut -d '"' -f 4)
  packagedHash=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'hash' | cut -d '"' -f 2)
  packagedVer=$(cat $NIXCFG/nixpkgs/openra/engines/git/default.nix | grep 'version' | cut -d '"' -f 2)
  latestVer="$upno.git.$uphash"
  sed -i -e "s|$packagedHash|$latestHash|g" -e "s|$packagedVer|$latestVer|g" $NIXCFG/nixpkgs/openra/engines/git/default.nix
  nixfrb
  sed -i -e "s|openraup|nixfrb|g" $NIXCFG/shell/hyprland/update_func
}
