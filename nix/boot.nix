{ pkgs, ... }:

{
  initrd.systemd.tpm2.enable = false;
  kernelPackages = pkgs.linuxPackages_latest;
  loader = {
    timeout = -1;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      default = 0;
      extraEntries = builtins.readFile ../grub-extra-entries.cfg;
    };
    efi.canTouchEfiVariables = true;
  };
  kernelParams = [ "usbcore.autosuspend=-1" ];
}
