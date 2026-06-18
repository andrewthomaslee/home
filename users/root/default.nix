{self, ...}: {
  nix.settings.allowed-users = ["root"];

  home-manager.users.root = self.homeModules.profile-root;
}
