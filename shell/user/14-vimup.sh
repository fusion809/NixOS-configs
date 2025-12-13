# if ! [[ -f /run/current-system/sw/bin/vim ]]; then
#     vim_verout=$(vim --version | head -n 2)
#     vim_basever=$(echo $vim_verout | head -n 1 | cut -d ' ' -f 5)
#     vim_patchver=$(echo $vim_verout | tail -n 1 | cut -d '-' -f 2)
#     export vim_instver="$vim_basever.$vim_patchver"
# fi

# export vim_upver=$(wget -q https://github.com/vim/vim/tags -O - | grep "tar\.gz" | head -n 1 | cut -d '/' -f 7 | cut -d '"' -f 1 | sed 's/v//g' | sed 's/\.tar\.gz//g')

# if ( [[ $vim_instver == $vim_upver ]] || [[ -z $vim_upver ]] ) && ! which vim | grep "vim not found" &> /dev/null; then
#     return 1
# fi

# if ( [[ -z $vim_instver ]] && echo $vim_instver | grep "[0-9]" &> /dev/null ); then
#     echo "You should run nixrsu to update your system, as Vim $vim_upver is out and $vim_instver is installed."
# fi