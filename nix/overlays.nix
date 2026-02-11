{ inputs, username }:
[
  (self: super:

    let
      pkgs = self;
      inherit (pkgs) lib;
      forkNixpkgsPath = ../nixpkgs;
      callPackage = lib.callPackageWith (pkgs
        // builtins.removeAttrs pkgs.xorg [
          "callPackage"
          "newScope"
          "overrideScope"
          "packages"
        ]);

      myLib = import ./lib.nix { inherit username; };
      inherit (myLib) homeDir;

    in with pkgs; {
      openraPackages = import (forkNixpkgsPath + /openra/default.nix) {
        inherit pkgs homeDir;
      }; # Import as a set
      openra-git = openraPackages.engines.git; # Access the git engine directly
      marvin = callPackage (forkNixpkgsPath + /marvin/package.nix) { };

      vim-latest = pkgs.master.vim.overrideAttrs (oldAttrs: {
        version = "latest";
        src = inputs.vim-src;
      });
      antigravity = callPackage (forkNixpkgsPath + /antigravity/package.nix) {
        buildVscode = { customizeFHSEnv ? null, ... }@args:
          let
            generic = pkgs.path + /pkgs/applications/editors/vscode/generic.nix;
            buildFHSEnv = if customizeFHSEnv != null then
              (fhsArgs: pkgs.buildFHSEnv (customizeFHSEnv fhsArgs))
            else
              pkgs.buildFHSEnv;
          in pkgs.callPackage generic
          (builtins.removeAttrs args [ "customizeFHSEnv" ] // {
            inherit buildFHSEnv;
          });
      };
      # Applying AUR patch and upgrading for Linux 6.19 compatibility
      patchNvidia = oldAttrs: {
        version = "580.126.09";
        src = pkgs.fetchurl {
          url =
            "https://us.download.nvidia.com/XFree86/Linux-x86_64/580.126.09/NVIDIA-Linux-x86_64-580.126.09.run";
          sha256 = "09pchs4lk2h8zpm8q2fqky6296h54knqi1vwsihzdpwaizj57b2c";
        };
        postPatch = (if oldAttrs ? postPatch && oldAttrs.postPatch != null then
          oldAttrs.postPatch
        else
          "") + ''
            echo "Applying Linux 6.19 compatibility hacks..."
            # Fix uvm_hmm.c (AUR fix)
            sed -i 's/#if defined(NV_ZONE_DEVICE_PAGE_INIT_HAS_ORDER_ARG)/#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 19, 0)\n#define ZONE_DEVICE_PAGE_INIT(page)   zone_device_page_init(page, page_pgmap(page), 0)\n#elif defined(NV_ZONE_DEVICE_PAGE_INIT_HAS_ORDER_ARG)/' kernel/nvidia-uvm/uvm_hmm.c || true

            # Re-apply previously needed fixes if version 580.126.09 doesn't have them
            # Fix nv_vm_flags_set (avoiding GPL-only vm_flags_set)
            sed -i 's/ACCESS_PRIVATE(vma, __vm_flags) |= flags;/vma->vm_flags |= flags;/' kernel/common/inc/nv-mm.h || true
            # Fix nv_vm_flags_clear (avoiding GPL-only vm_flags_clear)
            sed -i 's/ACCESS_PRIVATE(vma, __vm_flags) &= ~flags;/vma->vm_flags \&= ~flags;/' kernel/common/inc/nv-mm.h || true
            # Fix nv_dma_use_map_resource
            sed -i 's/return (ops->map_resource != NULL);/return 1;/' kernel/nvidia/nv-dma.c || true
          '';
      };
      linuxPackages_latest = super.linuxPackages_latest.extend (lfinal: lprev: {
        nvidia_x11 = lprev.nvidia_x11.overrideAttrs patchNvidia;
        nvidiaPackages = lprev.nvidiaPackages // {
          stable = lprev.nvidiaPackages.stable.overrideAttrs patchNvidia;
          production =
            lprev.nvidiaPackages.production.overrideAttrs patchNvidia;
        };
      });
      # Also patch the default linuxPackages
      linuxPackages = super.linuxPackages.extend (lfinal: lprev: {
        nvidia_x11 = lprev.nvidia_x11.overrideAttrs patchNvidia;
        nvidiaPackages = lprev.nvidiaPackages // {
          stable = lprev.nvidiaPackages.stable.overrideAttrs patchNvidia;
          production =
            lprev.nvidiaPackages.production.overrideAttrs patchNvidia;
        };
      });
    })
]
