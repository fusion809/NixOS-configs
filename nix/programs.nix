{ pkgs, inputs, username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;

in {
  appimage = {
    enable = true;
    binfmt = true;
  };
  fuse.userAllowOther = true; # allows kdeconnect SFTP mounts to be readable by Nautilus
  bash.shellInit = ''
    export USER="${username}"
    export NIXCFG="${nixcfgDir}"
  '' + builtins.readFile ../shell/root/main.sh;
  firefox = { enable = false; };
  hyprland = {
    enable = true;
    # package =
    #   inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    package = pkgs.hyprland;
  };
  kdeconnect.enable = true; # enables KDE Connect daemon + opens firewall ports 1714-1764
  nano = { enable = false; };
  nixvim = {
    enable = true;
    defaultEditor = true;
    colorschemes.monokai-pro.enable = true;
    extraPlugins = with pkgs.vimPlugins; [ vim-nix nerdtree coc-nvim ];
    extraConfigVim = ''
      call coc#config('languageserver', {
        \ 'nix': {
        \   'command': 'nixd',
        \   'filetypes': ['nix']
        \ }
        \ })

      " NERDTree settings
      let NERDTreeQuitOnOpen = 1

      " Automatically open NERDTree when opening a directory
      autocmd StdinReadPre * let s:std_in=1
      autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | 
        \ execute 'NERDTree' argv()[0] | only | 
        \ endif

      " Toggle NERDTree with Ctrl+n
      nnoremap <C-n> :NERDTreeToggle<CR>

      " Navigate between splits with Alt+hjkl
      nnoremap <M-h> <C-w>j
      nnoremap <M-l> <C-w>k
      nnoremap <M-j> <C-w>l
      nnoremap <M-k> <C-w>h
    '';
  };
  ssh = {
    extraConfig = ''
      HostKeyAlgorithms +ssh-rsa
      PubkeyAcceptedKeyTypes +ssh-rsa
    '';
  };
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
  virt-manager.enable = true;
  waybar = {
    enable = true;
    package = let
      pkg = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in pkg // { override = args: pkg; };
  };

  zsh = {
    autosuggestions.enable = true;
    enable = true;
    enableCompletion = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "vi-mode" ];
    };
    shellInit = ''
      export DISABLE_MAGIC_FUNCTIONS=true
      export USER="${username}"
      export NIXCFG="${nixcfgDir}"
    '' + builtins.readFile ../shell/root/.zshrc;
    syntaxHighlighting.enable = true;
  };
}
