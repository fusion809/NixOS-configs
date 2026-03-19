git -C $GHUBO/OpenRA pull origin bleed -q
git merge --no-ff
export latestVer=$(comno $GHUBO/OpenRA).git.$(revision $GHUBO/OpenRA | head -c 7)
export packagedVer=$(ls -ld $(which openra-ra) | cut -d '/' -f 9 | cut -d '-' -f 4)

function check_openra_update {
  if [[ $latestVer != $packagedVer ]]; then
    echo "OpenRA git package is out of date. nixfrb will update it."
  fi
}
if [[ $- == *i* ]]; then
   check_openra_update
fi
