# Recreate an empty "root" subvolume on every boot, after LUKS is opened and
# before it is mounted as /sysroot.
{ pkgs, ... }:
{
  boot.initrd.systemd.initrdBin = [ pkgs.btrfs-progs ];

  boot.initrd.systemd.services.rollback-root = {
    description = "Reset btrfs root subvolume to a blank state";
    wantedBy = [ "initrd.target" ];
    requires = [ "systemd-cryptsetup@cryptroot.service" ];
    after = [ "systemd-cryptsetup@cryptroot.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      mkdir -p /mnt
      mount -t btrfs -o subvolid=5 /dev/mapper/cryptroot /mnt

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
