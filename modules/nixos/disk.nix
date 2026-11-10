# Shared disk layout for every host: GPT -> ESP + LUKS -> btrfs subvolumes.
# Hosts only set `my.disk.device`.
{ config, lib, ... }:
{
  options.my.disk.device = lib.mkOption {
    type = lib.types.str;
    example = "/dev/nvme0n1";
    description = "Whole-disk device to partition with disko.";
  };

  options.my.disk.autoUnlock = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Unlock LUKS without a prompt using a key file embedded in the initrd on the
      (unencrypted) ESP. Convenience only: anyone with the disk can read the key.
      The key lives at /persist/etc/secrets/luks.key and is copied into the initrd
      on every bootloader install. Your passphrase stays as a fallback keyslot.
    '';
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
              settings = {
                allowDiscards = true;
              } // lib.optionalAttrs config.my.disk.autoUnlock {
                keyFile = "/luks.key"; # path inside the initrd (see below)
              };
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

    boot.initrd.secrets = lib.mkIf config.my.disk.autoUnlock {
      "/luks.key" = "/persist/etc/secrets/luks.key"; # read at bootloader install time
    };

    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".neededForBoot = true;
  };
}
