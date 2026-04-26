{
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Enable GPU acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  home-manager.users.root.homeSpec.programs.k9s.enable = true;

  hostSpec.services = {
    motd.sshMotd = builtins.readFile ./sshMotd.sh;
    minecraft = {
      enable = true;
      # --- Fabric Versions --- #
      fabric = {
        serverVersion = "1_21_11";
        loaderVersion = "0.18.4";
      };
      # --- Allowed Players --- #
      whitelist = {
        netsammateo = "06c0f83a-7ffe-466c-be19-b3c247b1438c";
        scorch3000 = "1380ccf2-aef4-4cb3-8d18-cf3642dac80c";
        Dingleborf = "0c86d5d5-44f4-4752-ae87-927beaeca0d5";
        GrimpTheImp = "df7a653a-e6d3-4287-84db-e06fb989bb58";
        sapphyy = "7ef1c05d-86b9-49fc-a3cf-ed1918818e2f";
        juwee = "d3dbf932-48dc-4102-b70d-5fbcf3eb1012";
        shinybronzor = "5417dbdb-dbd6-4d15-88e0-3bbd73bd7652";
        ColumboPlays = "1fb72d5e-ef87-419b-b76d-6ff278315931";
      };
      # --- Server Admins --- #
      operators = {
        netsammateo = {
          uuid = "06c0f83a-7ffe-466c-be19-b3c247b1438c";
          level = 4; # https://minecraft.wiki/w/Permission_level#Java_Edition
          bypassesPlayerLimit = true;
        };
      };
      # --- Mods --- #
      symlinks = {
        mods = pkgs.linkFarm "mods" (
          lib.mapAttrsToList
          (name: path: {
            name = "${name}.jar";
            inherit path;
          })
          {
            inherit
              (inputs)
              # --- ‼️ Required Client + Server ‼️ --- #
              Fabric-API # https://modrinth.com/mod/fabric-api
              Travelers-Backpack # https://modrinth.com/mod/travelersbackpack
              Storage-Drawers # https://modrinth.com/mod/storagedrawers
              Cardinal-Components-API # https://modrinth.com/mod/cardinal-components-api
              Cloth-Config-API # https://modrinth.com/mod/cloth-config
              Forge-Config-API-Port # https://modrinth.com/mod/forge-config-api-port

              # --- ☑️ Optional Client ( Some functionality is disabled if not present ) --- #
              Open-Parties-and-Claims # https://modrinth.com/mod/open-parties-and-claims
              JEI # https://modrinth.com/mod/jei
              Armored-Elytra # https://modrinth.com/datapack/elytra-armor
              Elytra-Trims # https://modrinth.com/mod/elytra-trims
              Lithium # https://modrinth.com/mod/lithium
              Inventory-Sorting # https://modrinth.com/mod/inventory-sorting

              # --- ✔️ Optional --- #
              Jade # https://modrinth.com/mod/jade
              FerriteCore # https://modrinth.com/mod/ferrite-core
              AppleSkin # https://modrinth.com/mod/appleskin
              Vein-Miner # https://modrinth.com/datapack/veinminer
              Vein-Miner-Enchantment # https://modrinth.com/datapack/veinminer-enchantment
              Silk # https://modrinth.com/mod/silk
              Kotlin # https://modrinth.com/mod/fabric-language-kotlin
              Clumps # https://modrinth.com/mod/clumps
              Distant-Horizons # https://modrinth.com/mod/distanthorizons
              Concurrent-Chunk-Management-Engine # https://modrinth.com/mod/c2me-fabric
              Universal-Shops # https://modrinth.com/mod/universal-shops
              Polymer # https://modrinth.com/mod/polymer
              Essential-Commands # https://modrinth.com/mod/essential-commands
              Dragon-Drops-Elytra # https://modrinth.com/mod/dragon-drops-elytra
              Collective # https://modrinth.com/mod/collective
              Bow-Infinity-Fix # https://modrinth.com/mod/bow-infinity-fix
              Universal-Enchants # https://modrinth.com/mod/universal-enchants
              Puzzles-Lib # https://modrinth.com/mod/puzzles-lib
              Grind-Enchantments # https://modrinth.com/mod/grind-enchantments
              Player-Roles # https://modrinth.com/mod/player-roles
              Just-Player-Heads # https://modrinth.com/mod/just-player-heads
              Infinite-Trading # https://modrinth.com/mod/infinite-trading
              TNT-Breaks-Bedrock # https://modrinth.com/mod/tnt-breaks-bedrock
              Recast # https://modrinth.com/mod/recast
              Respawning-Shulkers # https://modrinth.com/mod/respawning-shulkers
              Bigger-Sponge-Absorption-Radius # https://modrinth.com/mod/bigger-sponge-absorption-radius
              Fixed-Anvil-Repair-Cost # https://modrinth.com/mod/fixed-anvil-repair-cost
              Anvil-Restoration # https://modrinth.com/mod/anvil-restoration
              Inventory-Totem # https://modrinth.com/mod/inventory-totem
              Tree-Harvester # https://modrinth.com/mod/tree-harvester
              Extended-Bone-Meal # https://modrinth.com/mod/extended-bone-meal
              Random-Bone-Meal-Flowers # https://modrinth.com/mod/random-bone-meal-flowers
              Villager-Pickup # https://modrinth.com/mod/villager-pickup
              ;
          }
        );
      };
      # --- Server Config Files --- #
      files = {
        "config/roles.json".value = {
          owner = {
            level = 100;
            overrides = {
              name_decoration = {
                style = ["red" "bold"];
                contexts = ["chat" "tab_list"];
              };
              permission_keys.essentialcommands.spawn.set = true;
              permission_level = 4;
              commands.".*" = "allow";
              command_feedback = true;
            };
          };
          everyone.overrides.permission_keys.essentialcommands = {
            tpa = true;
            tpahere = true;
            tpaccept = true;
            tpdeny = true;
            home = {
              set = true;
              tp = true;
              delete = true;
            };
            warp = {
              tp = true;
              set = true;
              delete = true;
            };
            randomteleport = true;
            top = true;
            bed = true;
            back = true;
            spawn.tp = true;
            nickname = {
              self = true;
              style = {
                color = true;
                fancy = true;
                hover = true;
                click = true;
              };
            };
          };
        };
      };
    };
  };
}
