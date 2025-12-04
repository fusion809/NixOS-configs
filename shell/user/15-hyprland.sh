# Update flake.nix
export FLAKE_FILE="$NIXCFG/nix/flake.nix"
# Fetch latest Hyprland release
export HYPR_TAG=$(wget -cqO- https://github.com/hyprwm/Hyprland/tags | grep 'tag/v' | head -n 1 | cut -d '"' -f 6 
| cut -d '/' -f 6)
if [[ $HYPR_TAG != "null" ]]; then
    echo $HYPR_TAG > $HOME/.cache/hyprland_latest
elif [[ -f $HOME/.cache/hyprland_latest ]]; then
    export HYPR_TAG=$(cat $HOME/.cache/hyprland_latest)
fi
export HYPR_INST=$(cat $FLAKE_FILE | grep "Hyprland?" | cut -d '"' -f 2 | cut -d '/' -f 7)
# Fetch latest hy3 release
export HY3_TAG=$(wget -cqO- https://github.com/outfoxxed/hy3/tags | grep 'tag/hl' | head -n 1 | cut -d '"' -f 6 
| cut -d '/' -f 6)
if [[ $HY3_TAG != "null" ]]; then
    echo $HY3_TAG > $HOME/.cache/hy3_latest
elif [[ -f $HOME/.cache/hy3_latest ]]; then
    export HY3_TAG=$(cat $HOME/.cache/hy3_latest)
fi
export HY3_INST=$(cat $FLAKE_FILE | grep "hy3?" | cut -d '"' -f 2 | cut -d '/' -f 7)
if ( [[ -n $HY3_TAG ]] && [[ $HY3_TAG != $HY3_INST ]] && [[ -n $HY3_INST ]] && [[ $HY3_TAG != "null" ]] ); then
    echo "New version of hy3, $HY3_TAG, is out. Run hyprupdate to apply this update."
fi
if ( [[ $HYPR_INST != $HYPR_TAG ]] && [[ -n $HYPR_TAG ]] && [[ $HYPR_TAG != "null" ]] ); then
    echo "New version of Hyprland, $HYPR_TAG, is out. Run hyprupdate to apply this update."
fi

function hyprupdate {
    if ( ( [[ -n $HY3_TAG ]] && [[ $HY3_TAG != $HY3_INST ]] && [[ -n $HY3_INST ]] && [[ $HY3_TAG != "null" ]] ) || ( [[ $HYPR_INST != $HYPR_TAG ]] && [[ -n $HYPR_TAG ]] && [[ $HYPR_TAG != "null" ]] ) ) ; then
        # Update hy3 url
        sed -i \
        -e "s|https://github.com/outfoxxed/hy3?ref=refs/tags/$HY3_INST|https://github.com/outfoxxed/hy3?ref=refs/tags/$HY3_TAG|" \
        -e "s|https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/$HYPR_INST|https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/$HYPR_TAG|" "$FLAKE_FILE"
        echo "Updated flake.nix to use Hyprland $HYPR_TAG and hy3 $HY3_TAG"
        nixrsu
        sed -i -e "s|hyprupdate|nixfrb|g" $NIXCFG/shell/hyprland/update_func
    fi
}