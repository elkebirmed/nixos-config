{
  config,
  pkgs,
  inputs,
  ...
}: {
  users.users.mohamed = {
    initialHashedPassword = "$y$j9T$IoChbWGYRh.rKfmm0G86X0$bYgsWqDRkvX.EBzJTX.Z0RsTlwspADpvEF3QErNyCMC";
    isNormalUser = true;
    description = "mohamed";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "flatpak"
      "audio"
      "video"
      "plugdev"
      "input"
      "kvm"
      "qemu-libvirtd"
    ];
    packages = [inputs.home-manager.packages.${pkgs.system}.default];
  };
  home-manager.users.m3tam3re =
    import ../../../home/mohamed/${config.networking.hostName}.nix;
}
