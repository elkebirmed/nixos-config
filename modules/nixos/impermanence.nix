# Everything not listed here is gone at next boot.
{ ... }:
{
  users.mutableUsers = false; # passwords come from sops (or initialPassword)

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/lib/nixos" # uid/gid maps - must persist
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
    ];
    files = [ "/etc/machine-id" ];
    # per-user dirs are added in users.nix
  };
}
