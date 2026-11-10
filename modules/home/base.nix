{ osConfig, lib, ... }:
{
  home.stateVersion = lib.mkDefault osConfig.system.stateVersion;
}
