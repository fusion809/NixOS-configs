{ ... }: {
  home-manager.enable = true;
  bash = {
    enable = true;
    bashrcExtra = builtins.readFile ../Shell/user/main.sh;
  };
  git = {
    enable = true;
    userName = "fusion809";
    userEmail = "brentonhorne77@gmail.com";
  };
  gnome-shell.theme.name = "WhiteSur-Dark-solid";
  zsh = {
    enable = true;
    initContent = builtins.readFile ../Shell/user/.zshrc;
  };
}
