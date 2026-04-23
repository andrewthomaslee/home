{
  # inputs,
  self,
  # lib,
  ...
}: {
  flake = {
    # ------ Host Profiles ------ #
    nixosModules = {
      # --- Developer --- #
      # For Andrew's PCs
      developer = {
        imports = [self.nixosModules.default];
        config = {
          # hostSpec options
          hostSpec = {
            clan.enable = true;
            networking = {
              enable = true;
              tailscale.enable = true;
            };
            hardware = {
              bluetooth.enable = true;
              sound.enable = true;
            };
            services = {
              motd.enable = true;
              docker.enable = true;
              openssh.enable = true;
              storagebox.enable = true;
              nix.enable = true;
              kde.enable = true;
              wayland.enable = true;
            };
          };
          # nixos options
          security.sudo.wheelNeedsPassword = false;
          home-manager.users = {
            netsa = self.homeModules.developer;
            root = self.homeModules.developer;
          };
        };
      };
      # --- Server --- #
      # For Headless Servers
      server = {
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
              storagebox.enable = true;
            };
          };
          # nixos options
          home-manager.users = {
            netsa = self.homeModules.server;
            root = self.homeModules.server;
          };
        };
      };
      # --- Normal --- #
      # For Other's PCs
      normal = {
        imports = [self.nixosModules.default];
        config = {
          # hostSpec options
          hostSpec = {
            clan.enable = true;
            networking = {
              enable = true;
              tailscale.enable = true;
            };
            hardware = {
              bluetooth.enable = true;
              sound.enable = true;
            };
            services = {
              motd.enable = true;
              kde.enable = true;
              wayland.enable = true;
            };
          };
          # nixos options
          home-manager.users = {
            netsa = self.homeModules.normal;
            root = self.homeModules.normal;
          };
        };
      };
    };

    # ------ Home-manager Profiles ------ #
    homeModules = {
      # --- Developer --- #
      # For Andrew's PCs
      developer = {
        imports = [self.homeModules.default];
        config = {
          # homeSpec options
          homeSpec = {
            xdg.enable = true;
            programs = {
              tmux.enable = true;
              direnv.enable = true;
              docker.enable = true;
              firefox.enable = true;
              ghostty.enable = true;
              git.enable = true;
              go.enable = true;
              k9s.enable = true;
              ksshaskpass.enable = true;
              media.enable = true;
              shell.enable = true;
              ssh.enable = true;
              starship.enable = true;
              uv.enable = true;
              vscode.enable = true;
            };
          };
        };
      };
      # --- Server --- #
      # For Headless Servers
      server = {
        imports = [self.homeModules.default];
        config = {
          # homeSpec options
          homeSpec = {
            xdg.enable = true;
            programs = {
              tmux.enable = true;
              shell.enable = true;
              ssh.enable = true;
              starship.enable = true;
            };
          };
        };
      };
      # --- Normal --- #
      # For Other's PCs
      normal = {
        imports = [self.homeModules.default];
        config = {
          # homeSpec options
          homeSpec = {
            xdg.enable = true;
            programs = {
              firefox.enable = true;
              media.enable = true;
            };
          };
        };
      };
    };
  };
}
