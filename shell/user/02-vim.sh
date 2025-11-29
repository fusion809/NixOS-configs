function vbash {
  vim $HOME/.bashrc
}

function vcf {
  vim $NIXCFG/nix
}

function vhc {
  vim $NIXCFG/dotfiles/hyprland.conf
}

function vrm {
  if [[ -f README.md ]]; then
    vim README.md
  else
    vim $NIXCFG/README.md
  fi
}

function vst {
  vim $NIXCFG/dotfiles/style.css
}

function vwc {
  vim $NIXCFG/dotfiles/waybar-config.jsonc
}

function vzsh {
  vim $HOME/.zshrc
}
