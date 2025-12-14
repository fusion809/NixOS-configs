{ username, pkgs, ... }:

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

  # zed-editor = {
  #   enable = true;

  #   # This populates the userSettings "auto_install_extensions"
  #   extensions = [ "nix" "toml" ];

  #   # Everything inside of these brackets are Zed options
  #   userSettings = {
  #     assistant = {
  #       enabled = true;
  #       version = "2";
  #       default_open_ai_model = null;

  #       # Provider options:
  #       # - zed.dev models (claude-3-5-sonnet-latest) requires GitHub connected
  #       # - anthropic models (claude-3-5-sonnet-latest, claude-3-haiku-latest, claude-3-opus-latest) requires API_KEY
  #       # - copilot_chat models (gpt-4o, gpt-4, gpt-3.5-turbo, o1-preview) requires GitHub connected
  #       default_model = {
  #         provider = "zed.dev";
  #         model = "claude-3-5-sonnet-latest";
  #       };
  #     };

  #     node = {
  #       path = pkgs.lib.getExe pkgs.nodejs;
  #       npm_path = pkgs.lib.getExe' pkgs.nodejs "npm";
  #     };

  #     hour_format = "hour24";
  #     auto_update = false;

  #     terminal = {
  #       alternate_scroll = "off";
  #       blinking = "off";
  #       copy_on_select = false;
  #       dock = "bottom";
  #       detect_venv = {
  #         on = {
  #           directories = [ ".env" "env" ".venv" "venv" ];
  #           activate_script = "default";
  #         };
  #       };
  #       env = { TERM = "alacritty"; };
  #       font_family = "FiraCode Nerd Font";
  #       font_features = null;
  #       font_size = null;
  #       line_height = "comfortable";
  #       option_as_meta = false;
  #       button = false;
  #       shell = "system";
  #       toolbar = { title = true; };
  #       working_directory = "current_project_directory";
  #     };

  #     lsp = {
  #       rust-analyzer = {
  #         binary = {
  #           # path = lib.getExe pkgs.rust-analyzer;
  #           path_lookup = true;
  #         };
  #       };

  #       nix = { binary = { path_lookup = true; }; };

  #       elixir-ls = {
  #         binary = { path_lookup = true; };
  #         settings = { dialyzerEnabled = true; };
  #       };
  #     };

  #     vim_mode = true;

  #     # Tell Zed to use direnv and direnv can use a flake.nix environment
  #     load_direnv = "shell_hook";
  #     base_keymap = "VSCode";

  #     theme = {
  #       mode = "system";
  #       light = "One Light";
  #       dark = "One Dark";
  #     };

  #     show_whitespaces = "all";
  #     ui_font_size = 16;
  #     buffer_font_size = 16;
  #   };
  # };
}
