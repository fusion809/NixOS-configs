function vbash {
  nvim $HOME/.bashrc
}

function vcf {
  nvim $NIXCFG/nix
}

function vhc {
  nvim $NIXCFG/dotfiles/hyprland.conf
}

function vrm {
  if [[ -f README.md ]]; then
    nvim README.md
  else
    nvim $NIXCFG/README.md
  fi
}

function vst {
  nvim $NIXCFG/dotfiles/style.css
}

function vwc {
  nvim $NIXCFG/dotfiles/waybar-config.jsonc
}

function vzsh {
  nvim $HOME/.zshrc
}

alias vim='nvim'