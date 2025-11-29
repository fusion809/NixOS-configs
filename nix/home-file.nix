{ config, pkgs, ... }:

{
  ".local/share/hyprland/plugins/hy3.so".source =
    "${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so";

  # Hyprland
  ".config/hypr/hyprland.conf".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/hyprland.conf;

  # Waybar
  ".config/waybar/config.jsonc".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/waybar-config.jsonc;
  ".config/waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/style.css;
  ".config/waybar/arch_menu.xml".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/arch_menu.xml;

  # Kitty
  ".config/kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/kitty.conf;

  # Alacritty
  ".config/alacritty/alacritty.toml".source =
    config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/alacritty.toml;

  # Fastfetch
  ".config/fastfetch/config.jsonc".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/hyprland/fastfetch-config.jsonc;
}
