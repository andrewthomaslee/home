{
  # lib,
  # inputs,
  # config,
  clanLib,
  directory,
  ...
}: {
  _class = "clan.service";
  manifest.name = "cluster-mesh";
  manifest.description = "cluster-mesh";
  manifest.readme = "cluster-mesh";
  manifest.categories = ["Networking"];

  # peer options and configuration
  roles.peer = {
    description = "cluster peer";
    interface = {lib, ...}: {
      options = {
        endpoint = lib.mkOption {
          type = lib.types.str;
          example = "node1.example.com";
          description = ''
            Endpoint where the peer can be reached, ip address or domain name pointing to the peer.
            The port will be appended to this value
          '';
        };
        ipv4 = lib.mkOption {
          type = lib.types.str;
          example = "100.64.0.1";
          description = ''
            The ipv4 address of the peer
          '';
        };
        ipv6 = lib.mkOption {
          type = lib.types.str;
          example = "fd00:100:64::1";
          description = ''
            The ipv6 address of the peer
          '';
        };
        port = lib.mkOption {
          type = lib.types.int;
          example = 51820;
          default = 51820;
          description = ''
            The port of the peer
          '';
        };
      };
    };
    perInstance = {
      settings,
      instanceName,
      machine,
      roles,
      mkExports,
      ...
    }: {
      nixosModule = {
        config,
        pkgs,
        lib,
        ...
      }: let
        getPublicValue = machine: file:
          clanLib.getPublicValue {
            inherit machine file;
            generator = instanceName;
            flake = directory;
          };
        # extra hosts to add to /etc/hosts
        extraHostsIPv4 =
          lib.mapAttrsToList (
            peer: _value: "${roles.peer.machines.${peer}.settings.ipv4} ${peer}.${instanceName}"
          )
          roles.peer.machines;
        extraHostsIPv6 =
          lib.mapAttrsToList (
            peer: _value: "${roles.peer.machines.${peer}.settings.ipv6} ${peer}.${instanceName}"
          )
          roles.peer.machines;

        hostsContent = builtins.concatStringsSep "\n" (extraHostsIPv4 ++ extraHostsIPv6);
      in {
        options.clanSpec.services.${instanceName} = {
          endpoint = lib.mkOption {
            type = lib.types.str;
            default = settings.endpoint;
            example = "node1.example.com";
            description = ''
              Endpoint where the peer can be reached, ip address or domain name pointing to the peer.
              The port will be appended to this value
            '';
          };
          ipv4 = lib.mkOption {
            type = lib.types.str;
            example = "100.64.0.1";
            default = settings.ipv4;
            description = ''
              The ipv4 address of the peer
            '';
          };
          ipv6 = lib.mkOption {
            type = lib.types.str;
            example = "fd00:100:64::1";
            default = settings.ipv6;
            description = ''
              The ipv6 address of the peer
            '';
          };
          port = lib.mkOption {
            type = lib.types.int;
            example = 51820;
            default = settings.port;
            description = ''
              The port of the peer
            '';
          };
        };

        config = {
          # --- clan vars --- #
          clan.core.vars.generators =
            lib.mkMerge [
              {
                ${instanceName} = {
                  files = {
                    publickey.secret = false;
                    privatekey = {};
                  };
                  runtimeInputs = with pkgs; [wireguard-tools];
                  script = ''
                    wg genkey > $out/privatekey
                    wg pubkey < $out/privatekey > $out/publickey
                  '';
                };
              }
            ]
            ++ lib.optional (config.services.k3s.role == "server")
            [
              {
                "${instanceName}-cilium-certs" = {
                  share = true;
                  files = {
                    "tls.crt".secret = false;
                    "tls.key".secret = true;
                  };
                  runtimeInputs = with pkgs; [openssl];
                  script = ''
                    mkdir -p $out
                    openssl genrsa -out $out/tls.key 4096
                    openssl req -new -x509 -days 3650 -key $out/tls.key -out $out/tls.crt -subj "/CN=Cilium CA"
                  '';
                };
              }
              {
                "${instanceName}-sealed-secrets-certs" = {
                  share = true;
                  files = {
                    "tls.crt".secret = false;
                    "tls.key".secret = true;
                  };
                  runtimeInputs = with pkgs; [openssl];
                  script = ''
                    mkdir -p $out
                    openssl genrsa -out $out/tls.key 4096
                    openssl req -new -x509 -days 3650 -key $out/tls.key -out $out/tls.crt -subj "/CN=sealed-secret/O=sealed-secret"
                  '';
                };
              }
            ];

          systemd = lib.mkIf (config.services.k3s.role == "server") {
            paths."${instanceName}-sync-certs" = {
              description = "Watch Cilium CA secrets for changes";
              wantedBy = ["multi-user.target"];
              pathConfig.PathChanged = [
                config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.crt".path
                config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.key".path
                config.clan.core.vars.generators."${instanceName}-sealed-secrets-certs".files."tls.crt".path
                config.clan.core.vars.generators."${instanceName}-sealed-secrets-certs".files."tls.key".path
              ];
            };
            services = {
              "${instanceName}-sync-certs" = {
                description = "Sync Certs Manifests";
                wantedBy = ["multi-user.target"];
                before = ["k3s.service"];
                serviceConfig = {
                  Type = "oneshot";
                  User = "root";
                  ExecStart = pkgs.writeShellScript "${instanceName}-certs" ''
                    mkdir -p /var/lib/rancher/k3s/server/manifests

                    cat <<EOF > /var/lib/rancher/k3s/server/manifests/cilium-ca.yaml
                    apiVersion: v1
                    kind: Secret
                    type: kubernetes.io/tls
                    metadata:
                      name: cilium-ca
                      namespace: kube-system
                      labels:
                        app.kubernetes.io/managed-by: Helm
                      annotations:
                        meta.helm.sh/release-name: cilium
                        meta.helm.sh/release-namespace: kube-system
                    data:
                      tls.crt: $(cat ${config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.crt".path} | base64 -w0)
                      tls.key: $(cat ${config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.key".path} | base64 -w0)
                      ca.crt: $(cat ${config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.crt".path} | base64 -w0)
                      ca.key: $(cat ${config.clan.core.vars.generators."${instanceName}-cilium-certs".files."tls.key".path} | base64 -w0)
                    EOF

                    cat <<EOF > /var/lib/rancher/k3s/server/manifests/sealed-secrets-key.yaml
                    apiVersion: v1
                    kind: Secret
                    type: kubernetes.io/tls
                    metadata:
                      name: sealed-secrets-key
                      namespace: kube-system
                      labels:
                        sealedsecrets.bitnami.com/sealed-secrets-key: "active"
                    data:
                      tls.crt: $(cat ${config.clan.core.vars.generators."${instanceName}-sealed-secrets-certs".files."tls.crt".path} | base64 -w0)
                      tls.key: $(cat ${config.clan.core.vars.generators."${instanceName}-sealed-secrets-certs".files."tls.key".path} | base64 -w0)
                    EOF
                  '';
                };
              };
              k3s = {
                wants = ["${instanceName}-sync-certs.service"];
                after = ["${instanceName}-sync-certs.service"];
              };
            };
          };

          # --- firewall --- #
          networking = {
            extraHosts = hostsContent;
            firewall = {
              allowedUDPPorts = [settings.port];
              trustedInterfaces = [instanceName];
            };
          };

          # --- kernel --- #
          boot.kernel.sysctl = {
            # Enable IP forwarding
            "net.ipv4.ip_forward" = lib.mkForce true;
            "net.ipv6.ip_forward" = lib.mkForce true;

            # Increase maximum socket buffer sizes to 32MB (for high BDP links)
            "net.core.rmem_max" = lib.mkDefault 33554432;
            "net.core.wmem_max" = lib.mkDefault 33554432;
            "net.core.rmem_default" = lib.mkDefault 1048576;
            "net.core.wmem_default" = lib.mkDefault 1048576;

            # Increase TCP buffer limits to 32MB as well
            "net.ipv4.tcp_rmem" = lib.mkDefault "4096 1048576 33554432";
            "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 33554432";

            # Enable TCP BBR for much better high-latency throughput
            "net.core.default_qdisc" = lib.mkDefault "fq";
            "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";

            # Optional: Increase network device backlog for high-speed local links
            "net.core.netdev_max_backlog" = lib.mkDefault 16384;
          };

          # --- wireguard --- #
          networking.wireguard.interfaces."${instanceName}" = {
            ips = [
              "${settings.ipv4}/32"
              "${settings.ipv6}/128"
            ];
            listenPort = settings.port;
            privateKeyFile = config.clan.core.vars.generators.${instanceName}.files.privatekey.path;

            peers = map (peer: {
              publicKey = getPublicValue peer "publickey";

              allowedIPs = [
                "${roles.peer.machines.${peer}.settings.ipv4}/32"
                "${roles.peer.machines.${peer}.settings.ipv6}/128"
              ];

              endpoint = "${roles.peer.machines.${peer}.settings.endpoint}:${builtins.toString roles.peer.machines.${peer}.settings.port}";

              persistentKeepalive = 20;
            }) (lib.attrNames roles.peer.machines);
          };

          # tools and scripts to test connectivity
          environment.systemPackages = with pkgs; [
            (writeShellApplication {
              name = "fping-${instanceName}";
              runtimeInputs = [fping gnugrep coreutils];
              text = ''
                # shellcheck disable=SC2046
                fping "$@" -a -q -e -c 20 $(grep -oP '\S+\.${instanceName}' /etc/hosts | sort -u)
              '';
            })
          ];
        };
      };
    };
  };
}
