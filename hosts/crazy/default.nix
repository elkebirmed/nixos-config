{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  my.disk.device = "/dev/sda"; # check with lsblk
  my.users.mohamed.admin = true;
  my.users.kids = { };

  system.stateVersion = "26.05"; # release you first install; never bump blindly
}
