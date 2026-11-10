# Pulls the per-user email in from sops (see modules/nixos/users.nix).
{ config, osConfig, lib, ... }:
{
  programs.git.includes = lib.mkIf osConfig.my.secrets.enable [
    { path = osConfig.sops.templates."git-${config.home.username}".path; }
  ];
}