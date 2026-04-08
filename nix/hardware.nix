{ ... }:

{
  steam-hardware.enable = true;
  graphics.enable32Bit = true;
  bluetooth.enable = true;
  graphics.enable = true;
  nvidia.open = false; # Should only be true for newer cards
  nvidia.gsp.enable = false; # GTX 1050Ti (Pascal) does not support GSP
  nvidia.modesetting.enable = true; # Multimonitor support
}
