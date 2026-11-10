# Secrets are enabled automatically once secrets/common.yaml exists
# (and is `git add`ed). Until then users get initialPassword = "changeme".
{ config, lib, ... }:
let
  secretsFile = ../../secrets/common.yaml;
in
{
  options.my.secrets.enable = lib.mkOption {
    type = lib.types.bool;
    default = builtins.pathExists secretsFile;
    description = "Use sops-nix secrets (user password hashes).";
  };

  config = lib.mkIf config.my.secrets.enable {
    sops = {
      defaultSopsFile = secretsFile;
      # Host identity = SSH host key on the persistent subvolume.
      # Must be a /persist path: it is read before impermanence bind mounts.
      age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
      gnupg.sshKeyPaths = [ ];
    };
  };
}
