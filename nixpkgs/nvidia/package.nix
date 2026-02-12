{ pkgs, lib, fetchurl, ... }:

let
  version = "580.126.09";
  sha256_64bit = "09pchs4lk2h8zpm8q2fqky6296h54knqi1vwsihzdpwaizj57b2c";

  # Base package from generic linux-nvidia definition
  # We use pkgs.path to find the generic builder and helper files
  genericNvidia = pkgs.path + "/pkgs/os-specific/linux/nvidia-x11/generic.nix";

in pkgs.callPackage genericNvidia {
  inherit version sha256_64bit;

  # Compatibility fixes for Linux 6.19
  postPatch = ''
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
}
