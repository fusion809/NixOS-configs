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
    };
    efi.canTouchEfiVariables = true;
  };
}
