{ username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;
in {
  home-manager.enable = true;
  bash = {
    enable = true;
    bashrcExtra = ''
      export USER="${username}"
      export NIXCFG="${nixcfgDir}"
    '' + builtins.readFile ../shell/user/main.sh;
  };
  git = {
    enable = true;
    settings = {
      user = {
        name = username;
        email = "brentonhorne77@gmail.com";
      };
    };
  };
  gnome-shell.theme.name = "WhiteSur-Dark-solid";
  zsh = {
    enable = true;
    initContent = ''
      export USER="${username}"
      export NIXCFG="${nixcfgDir}"
    '' + builtins.readFile ../shell/user/.zshrc;
  };
}
