{
  # inputs,
  self,
  # lib,
  ...
}: {
  flake = {
    # ------ Hosts' NixOS Profiles ------ #
    nixosModules = {
      # --- Server --- #
      # For Headless Servers
      profile-server = {
        imports = [self.nixosModules.default];
        config = {
          # hostSpec options
          hostSpec = {
            clan.enable = true;
            networking = {
              enable = true;
              tailscale.enable = true;
            };
            services = {
              motd.enable = true;
              openssh.enable = true;
            };
          };
          # Home Profile
          home-manager.users = {
            netsa = self.homeModules.profile-server; # TODO: change to your default user
            root = self.homeModules.profile-server;
          };
        };
      };
    };

    # ------ Users' Home-manager Profiles ------ #
    homeModules = {
      # --- Server --- #
      # For Headless Servers
      profile-server = {
        imports = [self.homeModules.default];
        config = {
          # homeSpec options
          homeSpec = {
            xdg.enable = true;
            programs = {
              shell.enable = true;
              ssh.enable = true;
              starship.enable = true;
            };
          };
        };
      };
    };
  };
}
