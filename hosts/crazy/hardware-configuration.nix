# PLACEHOLDER - replace with:
#   nixos-generate-config --no-filesystems --show-hardware-config > hosts/laptop/hardware-configuration.nix
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
