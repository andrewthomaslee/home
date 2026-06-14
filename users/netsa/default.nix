{self, ...}: {
  nix.settings.allowed-users = ["netsa"];
  users.users.netsa = {
    isNormalUser = true;
    home = "/home/netsa";
    description = "husband";
    extraGroups = [
      "docker"
      "wheel"
      "networkmanager"
      "audio"
      "libvirtd"
      "tty"
      "dialout"
      "video"
      "storage-users"
    ];
  };

  home-manager.users.netsa = self.homeModules.profile-netsa;
}
