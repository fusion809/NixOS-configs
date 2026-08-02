{ pkgs, ... }:

{
  initrd.systemd.tpm2.enable = false;
  # NixOS 26.05 changed the default kernel from 6.12 → 6.18.
  # The NVIDIA 580.x driver + kernel 6.18 combination causes the X server to
  # crash at startup (SDDM: "Could not start Display server on vt 2").
  # Pin to 6.12 LTS until the upstream driver/patch situation is resolved.
  # Switch back to linuxPackages_latest once confirmed working on 6.18.
  #kernelPackages = pkgs.linuxPackages_6_12;
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
  extraModprobeConfig = "options usbhid mousepoll=8";

  kernel.sysctl = {
    "kernel.yama.ptrace_scope" = 0;
    "kernel.core_pattern" = "/dev/null";
  };
}
