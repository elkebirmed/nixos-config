# Shared disk layout for every host: GPT -> ESP + LUKS -> btrfs subvolumes.
# Hosts only set `my.disk.device`.
{ config, lib, ... }:
{
  options.my.disk.device = lib.mkOption {
    type = lib.types.str;
    example = "/dev/nvme0n1";
    description = "Whole-disk device to partition with disko.";
  };

  config = {
    disko.devices.disk.main = {
      type = "disk";
      device = config.my.disk.device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot"; # referenced by btrfs-rollback.nix
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  # wiped on every boot
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  # survives reboots (see impermanence.nix)
                  "/persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };

    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;
  };
}
