{ pkgs, inputs, username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;
in

{
  appimage = {
    enable = true;
    binfmt = true;
  };
  bash.shellInit = ''
      export USER="${username}"
      export NIXCFG="${nixcfgDir}"
    '' + builtins.readFile ../shell/root/main.sh;
  firefox = { enable = false; };
  hyprland = {
    enable = true;
    package =
      inputs.hyprland.packages.${pkgs.system}.hyprland; # Thought using unstable lead to RS3 bugs, but happens even with stable
    #package = pkgs.hyprland;
  };
  nano = { enable = false; };
  steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall =
      true; # Open ports in the firewall for Steam Local Network Game Transfers

    # Enable GameScope session for better Wayland support
    gamescopeSession.enable = true;

    # Add extra compatibility packages for Nvidia + Wayland
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  vim = {
    enable = true;
    defaultEditor = true;
    package = pkgs.vim-latest;
  };
  virt-manager.enable = true;
  waybar.enable = true;
  zsh = {
    autosuggestions.enable = true;
    enable = true;
    enableCompletion = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "safe-paste" "vi-mode" ];
    };
    shellInit = ''
      export USER="${username}"
      export NIXCFG="${nixcfgDir}"
    '' + builtins.readFile ../shell/root/.zshrc;
    syntaxHighlighting.enable = true;
  };
}
