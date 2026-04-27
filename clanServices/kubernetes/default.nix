{
  lib,
  # config,
  # clanLib,
  # directory,
  ...
}: {
  _class = "clan.service";
  manifest = {
    name = "kubernetes";
    description = "k3s cluster";
    readme = builtins.readFile ./README.md;
    categories = ["System"];
  };

  # init role
  roles.init = {
    description = "The first node of the cluster";
    interface.options = {
      masterAddr = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.67.67.1";
        description = ''
          The address of the master node
        '';
      };
      masterPort = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        example = 6443;
        default = null;
        description = ''
          The port of the master node
        '';
      };
      clusterCidr = lib.mkOption {
        type = lib.types.str;
        default = "10.42.0.0/16,fd42::/56";
        example = "10.42.0.0/16,fd42::/56";
        description = ''
          Cluster CIDR
        '';
      };
      serviceCidr = lib.mkOption {
        type = lib.types.str;
        default = "10.43.0.0/16,fd43::/112";
        example = "10.43.0.0/16,fd43::/112";
        description = ''
          Service CIDR
        '';
      };
      interface = lib.mkOption {
        type = lib.types.str;
        default = "cm";
        example = "en+";
        description = ''
          Interface to use for the cluster
        '';
      };
    };

    perInstance.nixosModule.services.k3s = {
      clusterInit = true;
      serverAddr = lib.mkForce "";
    };
  };

  # server role
  roles.server = {
    description = "Manager nodes of the cluster";
    perInstance = {instanceName, ...}: {
      nixosModule = {
        config,
        pkgs,
        self,
        ...
      }: let
        cfg = config.clanSpec.services.kubernetes;
      in {
        # k3s
        services.k3s = {
          role = lib.mkForce "server";
          extraFlags = [
            "--cluster-cidr=${cfg.clusterCidr}"
            "--service-cidr=${cfg.serviceCidr}"
            "--tls-san=${cfg.masterAddr}"
            "--flannel-backend=none"
            "--disable-network-policy"
            "--disable-kube-proxy"
          ];
          autoDeployCharts.cilium = {
            name = "cilium";
            version = "1.19.3";
            repo = "https://helm.cilium.io/";
            hash = "sha256-yOBd+eq/kBnmL1ED4fNYFLTxtDkW+IUZ5a5ONsaapCs=";
            targetNamespace = "kube-system";
            extraFieldDefinitions.spec.bootstrap = true;
            values = {
              rollOutCiliumPods = true;
              devices = cfg.interface;
              MTU = 1370;
              operator.replicas = 1;
              kubeProxyReplacement = true;
              k8sServiceHost = cfg.masterAddr;
              k8sServicePort = cfg.masterPort;
              ipv4.enabled = true;
              ipv6.enabled = true;
              ipam.mode = "kubernetes";
            };
          };
        };

        environment = {
          variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
          etc."kubenix.yaml".source = self.packages.${pkgs.stdenv.hostPlatform.system}.kubenix;
        };
        system.activationScripts.kubenix.text = ''
          ln -sf /etc/kubenix.yaml /var/lib/rancher/k3s/server/manifests/kubenix.yaml
        '';
      };
    };
  };

  # default role
  roles.default = {
    description = "Node of the cluster";
    perInstance = {
      settings,
      instanceName,
      machine,
      roles,
      ...
    }: let
      init = builtins.head (lib.attrNames roles.init.machines);
      clusterSettings = roles.init.machines.${init}.settings;
    in {
      nixosModule = {
        config,
        lib,
        ...
      }: let
        cfg = config.clanSpec.services.kubernetes;
      in {
        options.clanSpec.services.kubernetes = {
          masterAddr = lib.mkOption {
            type = lib.types.str;
            default =
              if (clusterSettings.masterAddr == null)
              then "${init}.cm"
              else settings.masterAddr;
          };
          masterPort = lib.mkOption {
            type = lib.types.int;
            default =
              if (clusterSettings.masterPort == null)
              then 6443
              else settings.masterPort;
          };
          clusterCidr = lib.mkOption {
            type = lib.types.str;
            default = clusterSettings.clusterCidr;
          };
          serviceCidr = lib.mkOption {
            type = lib.types.str;
            default = clusterSettings.serviceCidr;
          };
          interface = lib.mkOption {
            type = lib.types.str;
            default = clusterSettings.interface;
          };
        };

        config = {
          # create join token
          clan.core.vars.generators."kubernetes-${instanceName}" = {
            share = true;
            files.token = {};
            script = ''
              mkdir -p $out
              # Generates 32-character alphanumeric password without newline
              echo -n "$(tr -dc a-z0-9 < /dev/urandom | head -c 32)" > $out/token
            '';
          };
          # k3s
          services.k3s = {
            enable = true;
            nodeIP = "${config.clanSpec.services.${cfg.interface}.ipv4},${config.clanSpec.services.${cfg.interface}.ipv6}";
            role = lib.mkDefault "agent";
            nodeLabel = [
              "instanceName=${instanceName}"
              "machine=${machine.name}"
            ];
            tokenFile = config.clan.core.vars.generators."kubernetes-${instanceName}".files.token.path;
            serverAddr = lib.mkDefault "https://${cfg.masterAddr}:${toString cfg.masterPort}";
          };

          # networking
          networking = let
            interfaces = ["cilium+" "lxc+"];
          in {
            networkmanager.unmanaged = interfaces;
            firewall = {
              checkReversePath = "loose";
              trustedInterfaces = interfaces;
              allowedTCPPortRanges = [
                {
                  from = 30000;
                  to = 32767;
                }
              ];
              allowedUDPPortRanges = [
                {
                  from = 30000;
                  to = 32767;
                }
              ];
            };
          };
        };
      };
    };
  };
}
