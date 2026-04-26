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
      profile-developer = {
        imports = [self.nixosModules.default];
        config = {
          # hostSpec options
          hostSpec = {
            clan.enable = true;
            networking = {
              enable = true;
              tailscale = {
                enable = true;
                systray = true;
              };
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
          # Home Profile
          home-manager.users = {
            netsa = self.homeModules.profile-developer;
            root = self.homeModules.profile-developer;
          };
          # nixos options
          security.sudo.wheelNeedsPassword = false;
          boot.binfmt.emulatedSystems = ["aarch64-linux"];
        };
      };
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
              storagebox.enable = true;
            };
          };
          # Home Profile
          home-manager.users = {
            netsa = self.homeModules.profile-server;
            root = self.homeModules.profile-server;
          };
        };
      };
      # --- Normal --- #
      # For Other's PCs
      profile-normal = {
        imports = [self.nixosModules.default];
        config = {
          # hostSpec options
          hostSpec = {
            clan.enable = true;
            networking = {
              enable = true;
              tailscale = {
                enable = true;
                systray = true;
              };
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
          # Home Profile
          home-manager.users = {
            netsa = self.homeModules.profile-normal;
            root = self.homeModules.profile-normal;
          };
        };
      };
    };

    # ------ Home-manager Profiles ------ #
    homeModules = {
      # --- Developer --- #
      # For Andrew's PCs
      profile-developer = {pkgs, ...}: {
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
          # Home Options
          home.packages = with pkgs;
          with pkgs.unstable; [
            zen-browser
            moscripts
            kubefetch
            obsidian
            usbutils
            wireguard-tools
            asciinema
            prismlauncher
            tor-browser
            kalker
            lazyssh
            lazyjournal
            jq
            yq
            httpie
            mediawriter
            fastfetch
            fh
          ];
        };
      };
      # --- Server --- #
      # For Headless Servers
      profile-server = {
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
      profile-normal = {
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
