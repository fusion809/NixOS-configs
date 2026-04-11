function comno {
  if [[ -n $1 ]]; then
  	git -C $1 rev-list --count HEAD
  else
    git rev-list --count HEAD
  fi
}

function git-branch {
  if ! [[ -n "$1" ]]; then
    git rev-parse --abbrev-ref HEAD
  else
    git -C "$1" rev-parse --abbrev-ref HEAD
  fi
}

function gitsw {
  repo=$(git remote -v | grep fetch | grep origin | sed 's|.*github.com[/:]||g' | cut -d ' ' -f 1)
  git remote rm origin
  git remote add origin git@github.com:$repo
}

function push {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    $NIXCFG/python/analysis.py
    doctoc "$NIXCFG/README.md" --notitle
    sed -i '/generated with \[DocToc\]/d' "$NIXCFG/README.md"
    git -C "$NIXCFG" add --all
    git -C "$NIXCFG" commit -m "$1"
    git -C "$NIXCFG" push origin $(git-branch "$NIXCFG") $2
  else
    if echo $PWD | grep $NIXCFG &> /dev/null ; then
      $NIXCFG/python/analysis.py
      doctoc README.md --notitle
      sed -i '/generated with \[DocToc\]/d' README.md
    fi
    git add --all
    git commit -m "$1"
    git push origin $(git-branch) $2
  fi
}

function pushf {
  push "$1" -f
}

function revision {
  if [[ -n $1 ]]; then
	  git -C "$1" log | head -n 1 | cut -d ' ' -f 2
  else
    git log | head -n 1 | cut -d ' ' -f 2
  fi
}