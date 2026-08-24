{ ... }:

{
  hostName = "nixos"; # Define your hostname.
  # Enable networking
  networkmanager.enable = true;

  # WayVNC ports (5900 for HDMI-A-1, 5901 for DVI-D-1)
  firewall = {
    enable = true;
    allowedTCPPorts = [ 5900 5901 ];
  };
}
