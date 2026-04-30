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
      id = lib.mkOption {
        type = lib.types.int;
        default = 1;
        example = 2;
        description = ''
          The ID of the Cluster
        '';
      };
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
      clusters = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        example = {
          home = {
            address = "10.67.67.1";
            port = 32379;
          };
        };
        description = ''
          Cilium Clusters
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
            "--disable=traefik,servicelb"
          ];
          autoDeployCharts.cilium = {
            name = "cilium";
            version = "1.19.3";
            repo = "https://helm.cilium.io/";
            hash = "sha256-yOBd+eq/kBnmL1ED4fNYFLTxtDkW+IUZ5a5ONsaapCs=";
            targetNamespace = "kube-system";
            extraFieldDefinitions.spec.bootstrap = true;
            values =
              {
                cluster = {
                  name = instanceName;
                  id = cfg.id;
                };
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
              }
              // lib.optionalAttrs (cfg.clusters != {}) {
                clustermesh = {
                  useAPIServer = true;
                  cacheTTL = "5m";
                  apiserver = {
                    service = {
                      type = "NodePort";
                      nodePort = 32379;
                    };
                    tls.server = {
                      extraIpAddresses = lib.mapAttrsToList (name: details: details.address) cfg.clusters;
                      extraDnsNames = [cfg.masterAddr];
                    };
                  };
                  config = {
                    enabled = true;
                    inherit (cfg) clusters;
                  };
                };
              };
          };
        };

        environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        system.activationScripts.kubenix.text = ''
          mkdir -p /var/lib/rancher/k3s/server/manifests
          cp ${self.packages.${pkgs.stdenv.hostPlatform.system}.kubenix} /var/lib/rancher/k3s/server/manifests/kubenix.yaml
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
          id = lib.mkOption {
            type = lib.types.int;
            default = clusterSettings.id;
          };
          masterAddr = lib.mkOption {
            type = lib.types.str;
            default =
              if (clusterSettings.masterAddr == null)
              then "${init}.${cfg.interface}"
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
          clusters = lib.mkOption {
            type = lib.types.attrs;
            default = clusterSettings.clusters;
          };
        };

        config = {
          # create join token
          clan.core.vars.generators."kubernetes-${instanceName}" = {
            share = true;
            files.token = {};
            # Generates 32-character alphanumeric password without newline
            script = ''
              mkdir -p $out
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
              allowedTCPPorts = [
                80
                443
                53
              ];
              allowedUDPPorts = [
                80
                443
                53
              ];
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
