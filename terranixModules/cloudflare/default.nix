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
      terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";
      provider.cloudflare = {};
      variable.cloudflare_account_id.sensitive = true;

      data.cloudflare_zone = lib.mkMerge (map (domain: {
          "${safeDomain domain}" = {
            name = domain;
          };
        })
        uniqueDomains);

      resource.cloudflare_dns_record = lib.mkMerge (map (machine: let
          zone_id = "\${data.cloudflare_zone.${safeDomain machine.domain}.id}";
          name = "${machine.name}.${machine.domain}";
          ttl = 1;
        in {
          "${machine.name}-v4" = {
            inherit zone_id ttl name;
            type = "A";
            content = machine.network.ipv4;
          };
          "${machine.name}-v6" = {
            inherit zone_id ttl name;
            type = "AAAA";
            content = machine.network.ipv6;
          };
        })
        cfg.machines);
    }
  ];
}
