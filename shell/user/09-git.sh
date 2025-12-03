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
  git add --all
  git commit -m "$@"
  git push origin $(git-branch)
}

function pushf {
  git add --all
  git commit -m "$@"
  git push origin $(git-branch) -f
}

function revision {
  if [[ -n $1 ]]; then
	  git -C "$1" log | head -n 1 | cut -d ' ' -f 2
  else
    git log | head -n 1 | cut -d ' ' -f 2
  fi
}