{ pkgs, username, ... }:

{
  blueman = { enable = true; };
  displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      user = username;
    };
  };
  gvfs = { enable = true; };
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
  pulseaudio = { enable = false; };
  printing = { enable = false; };
  accounts-daemon.enable = true;
  xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
