{ pkgs, ... }:

{
  packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.noto
    nerd-fonts.hurmit
    nerd-fonts.hasklug
    nerd-fonts.symbols-only
    font-awesome
  ];
}
