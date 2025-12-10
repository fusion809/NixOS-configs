{ pkgs, inputs, username, ... }:

let
  lib = import ./lib.nix { inherit username; };
  nixcfgDir = lib.nixcfgDir;

in {
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
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland; # Thought using unstable lead to RS3 bugs, but happens even with stable
    #package = pkgs.hyprland;
  };
  nano = { enable = false; };
  nixvim = {
    enable = true;
    defaultEditor = true;
    colorschemes.monokai-pro.enable = true;
    extraPlugins = with pkgs.vimPlugins;
      [ vim-nix nerdtree coc-nvim ] ++ [
        (pkgs.vimUtils.buildVimPlugin {
          name = "vim-ai";
          src = pkgs.fetchFromGitHub {
            owner = "madox2";
            repo = "vim-ai";
            rev = "8887f9f78dc0957f57afbc60355a5f328cb84f20";
            hash = "sha256-gpVMxOqfQMMMb9dAfEaf0edHlEvy8lmetNL2oWolQ4c=";
          };
        })
      ];
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
      nnoremap <C-a> :AIChat<CR>

      " Navigate between splits with Alt+hjkl
      nnoremap <M-h> <C-w>j
      nnoremap <M-l> <C-w>k
      nnoremap <M-j> <C-w>l
      nnoremap <M-k> <C-w>h
      " Configure vim-ai to use Ollama (free local AI)
      let g:vim_ai_chat = {
      \  "options": {
      \    "model": "llama3.2",
      \    "endpoint_url": "http://localhost:11434/v1/chat/completions",
      \    "max_tokens": 0,
      \    "temperature": 1,
      \  },
      \}
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
