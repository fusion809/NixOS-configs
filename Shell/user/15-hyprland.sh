# Update flake.nix
export FLAKE_FILE="$NIXCFG/nix/flake.nix"
# Fetch latest Hyprland release
HYPR_TAG=$(curl -s https://api.github.com/repos/hyprwm/Hyprland/releases/latest | jq -r .tag_name)
HYPR_INST=$(cat $FLAKE_FILE | grep "Hyprland/" | cut -d '"' -f 2 | cut -d '/' -f 3 | sed 's/?submodules=1//g')
# Fetch latest hy3 release
HY3_TAG=$(curl -s https://api.github.com/repos/outfoxxed/hy3/releases/latest | jq -r .tag_name)
HY3_INST=$(cat $FLAKE_FILE | grep "hy3/" | cut -d '"' -f 2 | cut -d '/' -f 3)
if [[ $HY3_TAG != $HY3_INST ]] ; then
    echo "New version of hy3, $HY3_TAG, is out..."
fi
if [[ $HYPR_INST != $HYPR_TAG ]]; then
    echo "New version of Hyprland, $HYPR_TAG, is out..."
fi
# Update hy3 url
sed -i "s|github:outfoxxed/hy3/.*\"|github:outfoxxed/hy3/$HY3_TAG\"|" "$FLAKE_FILE"
# Update hyprland url
sed -i "s|github:hyprwm/Hyprland/.*?|github:hyprwm/Hyprland/$HYPR_TAG?|" "$FLAKE_FILE"
echo "Updated flake.nix to use Hyprland $HYPR_TAG and hy3 $HY3_TAG"
echo "Run nixrsu to update your system to use this Hyprland release."