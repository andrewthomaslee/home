{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.shell = {
    config,
    osConfig,
    pkgs,
    ...
  }: let
    cfg = config.homeSpec.programs.shell;
  in {
    options.homeSpec.programs.shell.enable = lib.mkEnableOption "default shell configuration";
    config = lib.mkIf cfg.enable {
      programs = {
        # ------ Extras ------ #
        ripgrep = {
          enable = true;
          package = pkgs.unstable.ripgrep;
        };
        eza = {
          enable = true;
          package = pkgs.unstable.eza;
        };
        fzf = {
          enable = true;
          package = pkgs.unstable.fzf;
        };
        # ------ Bash ------ #
        bash = {
          enable = true;
          shellAliases = {
            sudo = "sudo ";
            root = "su root";
            sr = "su -l";
            ssh-key = "eval \"$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519";
            # nix commands
            nfc = "nix flake check --all-systems --show-trace";
            nfu = "nix flake update";
            nd = "nix develop";
            nr = "nix run";
            nfs = "nix flake show --all-systems";
            nixos-facter = "sudo nix run nixpkgs#nixos-facter -- -o facter.json";
            # local nixos rebuild commands
            nixos-rebuild-boot = "sudo nixos-rebuild boot --flake /home/netsa/home#${
              if osConfig != null
              then osConfig.networking.hostName
              else "default"
            }";
            nixos-rebuild-switch = "sudo nixos-rebuild switch --flake /home/netsa/home#${
              if osConfig != null
              then osConfig.networking.hostName
              else "default"
            }";
            nixos-rebuild-test = "sudo nixos-rebuild test --flake /home/netsa/home#${
              if osConfig != null
              then osConfig.networking.hostName
              else "default"
            }";
            # nixos-rebuild tests
            nixos-current-system = "readlink -f /nix/var/nix/profiles/system && readlink -f /run/current-system";
            # misc
            speedtest = "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#ookla-speedtest";
            off = "shutdown -h now";
            # k3s
            k3s-wipe = "systemctl stop k3s.service && rm -fr /var/lib/rancher/ && rm -fr /etc/rancher/ && k3s-killall.sh && ip link delete cilium_host && ip link delete cilium_vxlan && iptables-save | grep -iv cilium | iptables-restore && ip6tables-save | grep -iv cilium | ip6tables-restore";
            kubefetch = ''nix run "https://flakehub.com/f/andrewthomaslee/kubefetch/*"'';
          };
        };
      };
    };
  };
}
