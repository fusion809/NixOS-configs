function vbash {
  vim $HOME/.bashrc
}

function vcf {
  sudo vim /etc/nixos/configuration.nix
}

function vhc {
  vim $HCFG/hyprland.conf
}


function vhom {
  vim $NIXCFG/home.nix
}

alias vhx=vhom
function vrm {
  if [[ -f README.md ]]; then
    vim README.md
  else
    vim $NIXCFG/README.md
  fi
}

function vst {
  vim $HCFG/style.css
}

function vwc {
  vim $HCFG/waybar-config.jsonc
}

function vzsh {
  vim $HOME/.zshrc
}
