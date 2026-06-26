{
  lib,
  customLib,
  config,
  ...
}: let
  cfg = config.terranix;
  allNodes = lib.flatten (map (cluster: [cluster.master] ++ cluster.managers ++ cluster.workers) cfg.clusters);
  inherit (customLib.custom) relativeToRoot;

  metaSubmodule = lib.types.submodule ({...}: {
    options = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "andrewlee.cloud";
      };
      zone = lib.mkOption {
        type = lib.types.str;
        default = "eu-central";
        description = "Hetzner network zone for all machines (e.g. eu-central, us-east)";
      };
    };
  });

  cloudSubmodule = lib.types.submodule ({...}: {
    options = {
      region = lib.mkOption {
        type = lib.types.str;
        default = "hel1";
      };
      server_type = lib.mkOption {
        type = lib.types.str;
        default = "cpx22";
      };
    };
  });

  nodeSubmodule = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
      };
      system = lib.mkOption {
        type = lib.types.str;
        default = "x86_64";
      };
      web = lib.mkOption {
        type = lib.types.enum ["true" "false"];
        default = "true";
      };
      cloud = lib.mkOption {
        type = cloudSubmodule;
      };
    };
  });

  clusterSubmodule = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
      };
      master = lib.mkOption {
        type = nodeSubmodule;
      };
      managers = lib.mkOption {
        type = lib.types.listOf nodeSubmodule;
        default = [];
      };
      workers = lib.mkOption {
        type = lib.types.listOf nodeSubmodule;
        default = [];
      };
    };
  });
in {
  options.terranix = {
    infra_file = lib.mkOption {
      type = lib.types.path;
      default = relativeToRoot "infra.json";
      description = "The infra file to use for the cluster";
    };
    clusters = lib.mkOption {
      type = lib.types.listOf clusterSubmodule;
      default = (builtins.fromJSON (builtins.readFile cfg.infra_file)).clusters;
      description = "List of clusters to provision";
    };
    meta = lib.mkOption {
      type = metaSubmodule;
      default = (builtins.fromJSON (builtins.readFile cfg.infra_file)).meta or {};
      description = "Metadata for the cluster";
    };
  };

  config = lib.mkMerge [
    # --- TF State --- #
    {
      terraform.backend.s3 = {
        bucket = "9ufoxh1ue8wiphh7nkeo9djawdfvcidwlpokfemkewtrqcclotypenislsltvbp";
        endpoint = "https://hel1.your-objectstorage.com";
        key = "github/andrewthomaslee/home/tofu.tfstate";
        region = "hel1";
        use_path_style = true;
        use_lockfile = true;
        skip_credentials_validation = true;
        skip_metadata_api_check = true;
        skip_region_validation = true;
        skip_requesting_account_id = true;
        skip_s3_checksum = true;
      };
    }
    # --- Base Config --- #
    {
      terraform.required_providers.external.source = "hashicorp/external";
      provider.external = {};

      variable.flakehub_token.sensitive = true;

      data.external.machine_keys.program = ["get-keys"];
    }
    # --- TLS SSH Key Pair --- #
    {
      terraform.required_providers.tls.source = "hashicorp/tls";

      resource.tls_private_key.clan_ssh_key.algorithm = "ED25519";

      output.clan_ssh_key = {
        value = "\${tls_private_key.clan_ssh_key.private_key_openssh}";
        sensitive = true;
      };
    }
    # --- Cloudflare --- #
    {
      terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";
      provider.cloudflare = {};

      variable.cloudflare_account_id.sensitive = true;

      data.cloudflare_zones.cluster_domain.name = cfg.meta.domain;
    }
    # --- Hcloud --- #
    {
      terraform.required_providers.hcloud.source = "hetznercloud/hcloud";
      provider.hcloud = {};

      # Snapshots
      data = {
        hcloud_image.x86_64 = {
          with_selector = "system=x86_64";
          most_recent = true;
        };
        hcloud_ssh_keys.all = {};
      };

      resource = {
        # SSH Keys
        hcloud_ssh_key.clan_ssh_key = {
          name = "clan_ssh_key";
          public_key = "\${tls_private_key.clan_ssh_key.public_key_openssh}";
        };
        # Networks
        hcloud_network.clan_network = {
          name = "clan_network";
          ip_range = "10.0.0.0/16";
          labels = {
            network = "clan_network";
          };
        };
        hcloud_network_subnet.clan_subnet = {
          type = "cloud";
          network_id = "\${hcloud_network.clan_network.id}";
          network_zone = cfg.meta.zone;
          ip_range = "10.0.1.0/24";
        };
        # Placement Group
        hcloud_placement_group.clan_placement_group = {
          name = "clan_placement_group";
          type = "spread";
          labels = {
            network = "clan_network";
          };
        };
        # Firewall
        hcloud_firewall.clan_firewall = {
          name = "clan_firewall";
          apply_to = [
            {
              label_selector = "network=clan_network";
            }
          ];
          rule = [
            {
              direction = "in";
              protocol = "udp";
              port = "51820";
              source_ips =
                (map (node: "\${hcloud_server.${node.name}.ipv4_address}/32") allNodes)
                ++ (map (node: "\${hcloud_server.${node.name}.ipv6_address}/128") allNodes);
            }
          ];
        };
        hcloud_firewall.web = {
          name = "web";
          apply_to = [
            {
              label_selector = "web=true";
            }
          ];
          rule = [
            {
              direction = "in";
              protocol = "tcp";
              port = "80";
              source_ips = ["0.0.0.0/0" "::/0"];
            }
            {
              direction = "in";
              protocol = "tcp";
              port = "443";
              source_ips = ["0.0.0.0/0" "::/0"];
            }
          ];
        };
        hcloud_firewall.ssh = {
          name = "ssh";
          apply_to = [
            {
              label_selector = "network=clan_network";
            }
          ];
          rule = [
            {
              direction = "in";
              protocol = "tcp";
              port = "22";
              source_ips = ["0.0.0.0/0" "::/0"];
            }
            {
              direction = "in";
              protocol = "icmp";
              source_ips = ["0.0.0.0/0" "::/0"];
            }
          ];
        };
      };
    }
    # --- Nodes --- #
    {
      resource = {
        hcloud_server = lib.mkMerge (map (node: {
            ${node.name} = {
              image =
                if node.system == "x86_64"
                then "\${data.hcloud_image.x86_64.id}"
                else "\${data.hcloud_image.arm64.id}";
              name = node.name;
              location = node.cloud.region;
              server_type = node.cloud.server_type;
              placement_group_id = "\${hcloud_placement_group.clan_placement_group.id}";
              labels = {
                region = node.cloud.region;
                network = "clan_network";
                web = node.web;
              };
              public_net = {
                ipv4_enabled = true;
                ipv6_enabled = true;
              };
              network = [
                {
                  network_id = "\${hcloud_network.clan_network.id}";
                }
              ];
              depends_on = [
                "hcloud_network_subnet.clan_subnet"
              ];
              ssh_keys = "\${concat([hcloud_ssh_key.clan_ssh_key.id], data.hcloud_ssh_keys.all.ssh_keys.*.name)}";
              connection = {
                type = "ssh";
                user = "root";
                private_key = "\${tls_private_key.clan_ssh_key.private_key_openssh}";
                host = "\${self.ipv6_address}";
              };
              provisioner = [
                {
                  file = {
                    content = "\${var.flakehub_token}";
                    destination = "/etc/flakehub_token";
                  };
                }
                {
                  remote-exec.inline = [
                    "determinate-nixd login token --token-file /etc/flakehub_token"
                    "touch /var/lib/sops-nix/key.txt"
                    ''echo "''${data.external.machine_keys.result.${node.name}}" > /var/lib/sops-nix/key.txt''
                    "chmod 600 /var/lib/sops-nix/key.txt"
                    ''fh apply nixos "https://flakehub.com/f/andrewthomaslee/home/*" boot''
                    "systemd-run --on-active=10s systemctl reboot"
                  ];
                }
              ];
            };
          })
          allNodes);

        cloudflare_dns_record = lib.mkMerge (map (node: let
            name = "${node.name}.${cfg.meta.domain}";
            zone_id = "\${data.cloudflare_zones.cluster_domain.result[0].id}";
            ttl = 1;
          in {
            "${node.name}-v4" = {
              inherit zone_id ttl name;
              type = "A";
              content = "\${hcloud_server.${node.name}.ipv4_address}";
            };
            "${node.name}-v6" = {
              inherit zone_id ttl name;
              type = "AAAA";
              content = "\${hcloud_server.${node.name}.ipv6_address}";
            };
          })
          allNodes);
      };
    }
  ];
}
