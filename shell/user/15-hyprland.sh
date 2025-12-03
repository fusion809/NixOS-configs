# Update flake.nix
export FLAKE_FILE="$NIXCFG/nix/flake.nix"
# Fetch latest Hyprland release
export HYPR_TAG=$(curl -s https://api.github.com/repos/hyprwm/Hyprland/releases/latest | jq -r .tag_name)
export HYPR_INST=$(cat $FLAKE_FILE | grep "Hyprland?" | cut -d '"' -f 2 | cut -d '/' -f 7)
# Fetch latest hy3 release
export HY3_TAG=$(curl -s https://api.github.com/repos/outfoxxed/hy3/releases/latest | jq -r .tag_name)
export HY3_INST=$(cat $FLAKE_FILE | grep "hy3?" | cut -d '"' -f 2 | cut -d '/' -f 7)
if ( [[ -n $HY3_TAG ]] && [[ $HY3_TAG != $HY3_INST ]] && [[ -n $HY3_INST ]] ); then
    echo "New version of hy3, $HY3_TAG, is out. Run hyprupdate to apply this update."
fi
if ( [[ $HYPR_INST != $HYPR_TAG ]] && [[ -n $HYPR_TAG ]] ); then
    echo "New version of Hyprland, $HYPR_TAG, is out. Run hyprupdate to apply this update."
fi

function hyprupdate {
    if ( ( [[ -n $HY3_TAG ]] && [[ $HY3_TAG != $HY3_INST ]] && [[ -n $HY3_INST ]] ) || ( [[ $HYPR_INST != $HYPR_TAG ]] && [[ -n $HYPR_TAG ]] ) ) ; then
        # Update hy3 url
        sed -i \
        -e "s|https://github.com/outfoxxed/hy3?ref=refs/tags/$HY3_INST|https://github.com/outfoxxed/hy3?ref=refs/tags/$HY3_TAG|" \
        -e "s|https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/$HYPR_INST|https://github.com/hyprwm/Hyprland?submodules=1&ref=refs/tags/$HYPR_TAG|" "$FLAKE_FILE"
        echo "Updated flake.nix to use Hyprland $HYPR_TAG and hy3 $HY3_TAG"
        nixrsu
        sed -i -e "s|hyprupdate|nixfrb|g" $NIXCFG/shell/hyprland/update_func
    fi
}