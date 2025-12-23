{ pkgs, ... }:

{
  services.udev.extraRules = ''
    # Disable autosuspend for Maxxter Wireless Receiver
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="248a", ATTR{idProduct}=="8514", ATTR{power/control}="on"
    # Disable autosuspend for Telink Wireless Receiver
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8510", ATTR{idProduct}=="12ab", ATTR{power/control}="on"
  '';
}
