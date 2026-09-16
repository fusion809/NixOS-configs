{ ... }:

{
  hostName = "nixos"; # Define your hostname.
  # Enable networking
  networkmanager.enable = true;

  # WayVNC ports (5910 for HDMI-A-1, 5911 for DVI-D-1)
  firewall = {
    enable = true;
    allowedTCPPorts = [
      80
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
    extraCommands = ''
      iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8000 || true
      iptables -t nat -A OUTPUT -p tcp -d 100.122.211.37 --dport 80 -j REDIRECT --to-ports 8000 || true
      iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 80 -j REDIRECT --to-ports 8000 || true
    '';
  };
}
