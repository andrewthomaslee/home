{self, ...}: {
  nix.settings.allowed-users = ["root"];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/"
  ];

  home-manager.users.root = self.homeModules.profile-root;
}
