function nixver {
    nix-channel --list | grep "^nixos" | cut -d '-' -f 2
}
  
function rebuild {
    nixos-rebuild switch -I nixos-config=$NIXCFG/nix/configuration.nix --flake $NIXPKGS/nix/#nixos
}

alias nixrb=rebuild

function nixstrep {
    nix-store --repair --verify --check-contents
}

function nixcg {
    nix-collect-garbage -d
}

function nixrsu {
    nix flake update --flake $NIXCFG/nix
}

function update {
    nix-store --repair --verify --check-contents
    nixrsu
    nixcg
}
