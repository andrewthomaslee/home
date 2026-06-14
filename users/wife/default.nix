{self, ...}: {
  nix.settings.allowed-users = ["wife"];
  users.users.wife = {
    isNormalUser = true;
    home = "/home/wife";
    description = "wife";
    extraGroups = [
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

  home-manager.users.wife = self.homeModules.profile-wife;
}
