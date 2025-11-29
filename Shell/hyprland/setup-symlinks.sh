pushd $HOME/GitHub/mine/config/hyprland-configs
if ! [[ -d $HOME/.local/bin ]]; then
	mkdir -p $HOME/.local/bin
fi
if ! [[ -d $HOME/.config/waybar ]]; then
	mkdir -p $HOME/.config/waybar
fi
ln -sf $PWD/arch_menu.xml ~/.config/waybar/
ln -sf $PWD/power_menu.xml ~/.config/waybar/
ln -sf $PWD/waybar-config.jsonc ~/.config/waybar/config.jsonc
ln -sf $PWD/fastfetch-config.jsonc ~/.config/fastfetch/config.jsonc
ln -sf $PWD/style.css ~/.config/waybar/
if ! [[ -d $HOME/.config/hypr ]]; then
	mkdir -p $HOME/.config/hypr
fi
ln -sf $PWD/hyprland.conf ~/.config/hypr/
if ! [[ -d $HOME/.config/kitty ]]; then
	mkdir -p $HOME/.config/kitty
fi
ln -sf $PWD/kitty.conf ~/.config/kitty/
if ! [[ -d $HOME/.config/alacritty ]]; then
	mkdir -p $HOME/.config/alacritty
fi
ln -sf $PWD/alacritty.conf ~/.config/alacritty/
popd

