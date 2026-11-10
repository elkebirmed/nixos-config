# Recreate an empty "root" subvolume on every boot, once the partition is
# available and before it is mounted as /sysroot.
{ pkgs, utils, ... }:
let
  device = "/dev/disk/by-partlabel/disk-main-root";
  deviceUnit = "${utils.escapeSystemdPath device}.device";
in
{
  boot.initrd.systemd.initrdBin = [ pkgs.btrfs-progs ];

  boot.initrd.systemd.services.rollback-root = {
    description = "Reset btrfs root subvolume to a blank state";
    wantedBy = [ "initrd.target" ];
    requires = [ deviceUnit ];
    after = [ deviceUnit ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      mkdir -p /mnt
      mount -t btrfs -o subvolid=5 ${device} /mnt

      delete_subvolume_recursively() {
        # fields: ID <id> gen <g> top level <t> path <path>
        btrfs subvolume list -o "$1" | while read -r _ _ _ _ _ _ _ _ sub; do
          delete_subvolume_recursively "/mnt/$sub"
        done
        btrfs subvolume delete "$1"
      }

      if [ -e /mnt/root ]; then
        delete_subvolume_recursively /mnt/root
      fi
      btrfs subvolume create /mnt/root

      umount /mnt
    '';
  };
}