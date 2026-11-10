{ ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Needed for the btrfs rollback unit (see btrfs-rollback.nix)
  boot.supportedFilesystems = [ "btrfs" ];

  # Swap
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  boot.kernel.sysctl."vm.swappiness" = 150;

  services.fstrim.enable = true; # LUKS allowDiscards is on
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/persist" ];
  };
}
