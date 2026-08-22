{
  config,
  pkgs,
  username,
  ...
}:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;
  dotfilesDir = "${nixcfgDir}/dotfiles";
in
{
  ".local/share/hyprland/plugins/hy3_patched.so".source = "${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so";

  # Hyprland
  ".config/hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/hyprland.conf";

  # Waybar
  ".config/waybar/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/waybar-config.jsonc";
  ".config/waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/style.css";
  ".config/waybar/nixos_menu.xml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nixos_menu.xml";

  # Kitty
  ".config/kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/kitty.conf";

  # Alacritty
  ".config/alacritty/alacritty.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/alacritty.toml";

  # Fastfetch
  ".config/fastfetch/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/fastfetch-config.jsonc";

  # Julia
  ".julia/config/startup.jl".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/startup.jl";

  # Python
  ".pythonrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/pythonrc";

  # R
  ".Rprofile".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/Rprofile";

  # SSH
  ".ssh/config".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/config";

  # Desktop config files
  ".local/share/applications/dsv.desktop".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/dsv.desktop";
  ".local/share/applications/encifer.desktop".source = pkgs.substitute {
    src = builtins.toFile "encifer.desktop" (builtins.readFile "${dotfilesDir}/encifer.desktop");
    substitutions = [
      "--replace-quiet"
      "username"
      "${username}"
    ];
  };
  ".local/share/applications/mercury.desktop".source = pkgs.substitute {
    src = builtins.toFile "mercury.desktop" (builtins.readFile "${dotfilesDir}/mercury.desktop");
    substitutions = [
      "--replace-quiet"
      "username"
      "${username}"
    ];
  };
  ".local/share/applications/outlive.desktop".source = pkgs.substitute {
    src = builtins.toFile "outlive.desktop" (builtins.readFile "${dotfilesDir}/outlive.desktop");
    substitutions = [
      "--replace-quiet"
      "nixcfg"
      "${nixcfgDir}"
      "--replace-quiet"
      "username"
      "${username}"
    ];
  };

  # SwayNC
  ".config/swaync/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/swaync-config.json";
  ".config/swaync/style.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/style.css";

  # XDG MIME associations: registers kdeconnect:// URL handler
  ".config/mimeapps.list".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/mimeapps.list";
}
