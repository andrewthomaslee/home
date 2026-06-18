{
  lib,
  customLib,
  config,
  ...
}: let
  cfg = config.terranix.cloudflare;
  inherit (customLib.custom) relativeToRoot;
  uniqueDomains = lib.unique (map (m: m.domain) cfg.machines);
  safeDomain = domain: builtins.replaceStrings ["."] ["_"] domain;

  # Helper to safely retrieve IPv4 address with preference for lan
  getIPv4 = machine:
    if machine ? network
    then
      if machine.network ? lan && machine.network.lan ? ipv4
      then machine.network.lan.ipv4
      else if machine.network ? wan && machine.network.wan ? ipv4
      then machine.network.wan.ipv4
      else null
    else null;

  # Helper to retrieve IPv6 address with preference for lan
  getIPv6 = machine:
    if machine ? network
    then
      if machine.network ? lan && machine.network.lan ? ipv6
      then machine.network.lan.ipv6
      else if machine.network ? wan && machine.network.wan ? ipv6
      then machine.network.wan.ipv6
      else null
    else null;
in {
  options.terranix.cloudflare = {
    file = lib.mkOption {
      type = lib.types.path;
      default = relativeToRoot "machines.json";
      description = "The network file";
    };
    machines = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = (builtins.fromJSON (builtins.readFile cfg.file)).machines;
      description = "Network configuration";
    };
  };

  config = lib.mkMerge [
    # --- Cloudflare --- #
    {
      data.cloudflare_zones = lib.mkMerge (map (domain: {
          "${safeDomain domain}" = {
            name = domain;
          };
        })
        uniqueDomains);

      resource.cloudflare_dns_record = lib.mkMerge (map (
          machine: let
            zone_id = "\${data.cloudflare_zones.${safeDomain machine.domain}.result[0].id}";
            name = "${machine.name}.${machine.domain}";
            ttl = 1;
            ipv4 = getIPv4 machine;
            ipv6 = getIPv6 machine;
          in
            (
              if ipv4 != null
              then {
                "${machine.name}-v4" = {
                  inherit zone_id ttl name;
                  type = "A";
                  content = ipv4;
                };
              }
              else {}
            )
            // (
              if ipv6 != null
              then {
                "${machine.name}-v6" = {
                  inherit zone_id ttl name;
                  type = "AAAA";
                  content = ipv6;
                };
              }
              else {}
            )
        )
        cfg.machines);
    }
    # --- Hcloud --- #
    {
      resource.hcloud_firewall.clan_firewall = {
        rule = [
          {
            direction = "in";
            protocol = "udp";
            port = "51820";
            source_ips = let
              validIPv6s = lib.filter (ip: ip != null) (map getIPv6 cfg.machines);
            in
              map (ip: "${ip}/128") validIPv6s;
          }
        ];
      };
    }
  ];
}
