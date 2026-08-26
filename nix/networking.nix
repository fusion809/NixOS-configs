{ ... }:

{
  hostName = "nixos"; # Define your hostname.
  # Enable networking
  networkmanager.enable = true;

  # WayVNC ports (5910 for HDMI-A-1, 5911 for DVI-D-1)
  firewall = {
    enable = true;
    allowedTCPPorts = [
      5910
      5911
      8000
      8001
    ];
    allowedUDPPorts = [
      1234
    ];
    trustedInterfaces = [
      "tailscale0"
    ];
  };
}
