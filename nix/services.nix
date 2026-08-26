{ pkgs, username, ... }:

{
  blueman = {
    enable = true;
  };
  displayManager = {
    sddm.enable = true;
    defaultSession = "hyprland";
    autoLogin = {
      enable = true;
      user = username;
    };
    # sessionPackages = [
    #   (pkgs.writeTextDir "share/wayland-sessions/hyprland-lua.desktop" ''
    #     [Desktop Entry]
    #     Name=Hyprland (Lua)
    #     Comment=An intelligent dynamic tiling Wayland compositor (Lua Config)
    #     Exec=Hyprland --config /home/${username}/.config/hypr/hyprland.lua
    #     Type=Application
    #   '')
    # ];
  };
  gvfs = {
    enable = true;
  };
  pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  pulseaudio = {
    enable = false;
  };
  printing = {
    enable = false;
  };
  tailscale = {
    enable = true;
  };
  accounts-daemon.enable = true;
  avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
      workstation = true;
    };
  };
  sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };
  icecast = {
    enable = true;
    hostname = "nixos";
    listen.port = 8001;
    admin = {
      password = "hackme";
      user = "admin";
    };
    extraConfig = ''
      <authentication>
        <source-password>hackme</source-password>
      </authentication>
      <limits>
        <burst-size>0</burst-size>
        <burst-on-connect>0</burst-on-connect>
      </limits>
    '';
  };
}
