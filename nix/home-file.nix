{ config, pkgs, ... }:

{
  ".local/share/hyprland/plugins/hy3.so".source =
    "${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so";

  # Hyprland
  ".config/hypr/hyprland.conf".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/hyprland.conf;

  # Waybar
  ".config/waybar/config.jsonc".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/waybar-config.jsonc;
  ".config/waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/style.css;
  ".config/waybar/nixos_menu.xml".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/nixos_menu.xml;

  # Kitty
  ".config/kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/kitty.conf;

  # Alacritty
  ".config/alacritty/alacritty.toml".source =
    config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/alacritty.toml;

  # Fastfetch
  ".config/fastfetch/config.jsonc".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/fastfetch-config.jsonc;

  # SSH
  ".ssh/config".source = config.lib.file.mkOutOfStoreSymlink
    /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/config;
}
