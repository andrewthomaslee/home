{
  description = "Dendritic Determinate Flake";
  inputs = {
    # Determinate Nix
    # https://docs.determinate.systems/guides/advanced-installation/
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Nixpkgs
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Clan.lol
    clan-core = {
      url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Clan.lol Community
    clan-community = {
      url = "https://git.clan.lol/clan/clan-community/archive/main.tar.gz";
      inputs.clan-core.follows = "clan-core";
    };

    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Mkdocs
    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Utility Flakes
    flake-parts.follows = "clan-core/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # ------ Packages ------ #
    # Zen Browser
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Scripts
    moscripts = {
      url = "https://flakehub.com/f/andrewthomaslee/moscripts/*";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # neofetch for kube
    kubefetch = {
      url = "https://flakehub.com/f/andrewthomaslee/kubefetch/*";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # --- Minecraft --- #
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ----------------------------------- Fabric Mods ----------------------------------- #

    # ------ ⚠️‼️ Required mods ‼️⚠️ ------#
    Fabric-API = {
      # https://modrinth.com/mod/fabric-api
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
      flake = false;
    };
    Storage-Drawers = {
      # https://modrinth.com/mod/storagedrawers
      url = "https://cdn.modrinth.com/data/guitPqEi/versions/Q9r8LMQL/StorageDrawers-fabric-1.21.11-20.0.0.jar";
      flake = false;
    };
    Forge-Config-API-Port = {
      # Storage-Drawers Dependency
      # https://modrinth.com/mod/forge-config-api-port
      url = "https://cdn.modrinth.com/data/ohNO6lps/versions/uXrWPsCu/ForgeConfigAPIPort-v21.11.1-mc1.21.11-Fabric.jar";
      flake = false;
    };
    Travelers-Backpack = {
      # https://modrinth.com/mod/travelersbackpack
      url = "https://cdn.modrinth.com/data/rlloIFEV/versions/XbEGJQSG/travelersbackpack-fabric-1.21.11-10.11.9.jar";
      flake = false;
    };
    Cardinal-Components-API = {
      # Travelers-Backpack Dependency
      # https://modrinth.com/mod/cardinal-components-api
      url = "https://cdn.modrinth.com/data/K01OU20C/versions/O2RJYZwD/cardinal-components-api-7.3.1.jar";
      flake = false;
    };
    Cloth-Config-API = {
      # Travelers-Backpack Dependency
      # https://modrinth.com/mod/cloth-config
      url = "https://cdn.modrinth.com/data/9s6osm5g/versions/xuX40TN5/cloth-config-21.11.153-fabric.jar";
      flake = false;
    };

    # ------ ✅❓ Optional Client-side mods (recommended) ❓✅  -------- #
    JEI = {
      # https://modrinth.com/mod/jei
      url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/N7YozqFm/jei-1.21.11-fabric-27.4.0.15.jar";
      flake = false;
    };
    Open-Parties-and-Claims = {
      # https://modrinth.com/mod/open-parties-and-claims
      url = "https://cdn.modrinth.com/data/gF3BGWvG/versions/JkiXvTq4/open-parties-and-claims-fabric-1.21.11-0.26.2.jar";
      flake = false;
    };
    Elytra-Trims = {
      # https://modrinth.com/mod/elytra-trims
      url = "https://cdn.modrinth.com/data/XpzGz7KD/versions/Nzd1iQCn/elytratrims-fabric-4.6.2%2B1.21.11.jar";
      flake = false;
    };
    Armored-Elytra = {
      # https://modrinth.com/datapack/elytra-armor
      url = "https://cdn.modrinth.com/data/AuFCCYMx/versions/mKCSekSL/armored-elytra-1.12.0.jar";
      flake = false;
    };
    Lithium = {
      # https://modrinth.com/mod/lithium
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/gl30uZvp/lithium-fabric-0.21.2%2Bmc1.21.11.jar";
      flake = false;
    };
    Inventory-Sorting = {
      # https://modrinth.com/mod/inventory-sorting
      url = "https://cdn.modrinth.com/data/5ibSyLAz/versions/Dq4h9aTH/inventorysorter-fabric-2.1.4%2Bmc1.21.11.jar";
      flake = false;
    };

    # ------ ☑️ Server-side mods ☑️ ------#
    FerriteCore = {
      # https://modrinth.com/mod/ferrite-core
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/Ii0gP3D8/ferritecore-8.2.0-fabric.jar";
      flake = false;
    };
    Jade = {
      # https://modrinth.com/mod/jade
      url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/HKUAgY3D/Jade-1.21.11-Fabric-21.1.1.jar";
      flake = false;
    };
    AppleSkin = {
      # https://modrinth.com/mod/appleskin
      url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/59ti1rvg/appleskin-fabric-mc1.21.11-3.0.8.jar";
      flake = false;
    };
    Vein-Miner = {
      # https://modrinth.com/datapack/veinminer
      url = "https://cdn.modrinth.com/data/OhduvhIc/versions/g7E2sCkF/veinminer-fabric-2.6.0.jar";
      flake = false;
    };
    Vein-Miner-Enchantment = {
      # https://modrinth.com/datapack/veinminer-enchantment
      url = "https://cdn.modrinth.com/data/4sP0LXxp/versions/h5oKcjvq/veinminer-enchant-2.3.0.jar";
      flake = false;
    };
    Silk = {
      # https://modrinth.com/mod/silk
      url = "https://cdn.modrinth.com/data/aTaCgKLW/versions/tgYliGAU/silk-all-1.11.5.jar";
      flake = false;
    };
    Kotlin = {
      # https://modrinth.com/mod/fabric-language-kotlin
      url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/N6D3uiZF/fabric-language-kotlin-1.13.8%2Bkotlin.2.3.0.jar";
      flake = false;
    };
    Clumps = {
      # https://modrinth.com/mod/clumps
      url = "https://cdn.modrinth.com/data/Wnxd13zP/versions/OgBE8Rz4/Clumps-fabric-1.21.11-29.0.0.1.jar";
      flake = false;
    };
    Distant-Horizons = {
      # https://modrinth.com/mod/distanthorizons
      url = "https://cdn.modrinth.com/data/uCdwusMi/versions/GT3Bm3GN/DistantHorizons-2.4.5-b-1.21.11-fabric-neoforge.jar";
      flake = false;
    };
    Concurrent-Chunk-Management-Engine = {
      # https://modrinth.com/mod/c2me-fabric
      url = "https://cdn.modrinth.com/data/VSNURh3q/versions/olrVZpJd/c2me-fabric-mc1.21.11-0.3.6.0.0.jar";
      flake = false;
    };
    Universal-Shops = {
      # https://modrinth.com/mod/universal-shops
      url = "https://cdn.modrinth.com/data/cnIatHrN/versions/M6PTvMlM/universal_shops-1.13.0%2B1.21.11.jar";
      flake = false;
    };
    Polymer = {
      # https://modrinth.com/mod/polymer
      url = "https://cdn.modrinth.com/data/xGdtZczs/versions/wugBT1fU/polymer-bundled-0.15.2%2B1.21.11.jar";
      flake = false;
    };
    Essential-Commands = {
      # https://modrinth.com/mod/essential-commands
      url = "https://cdn.modrinth.com/data/6VdDUivB/versions/3s9XXmZa/essential_commands-0.38.6-mc1.21.11.jar";
      flake = false;
    };
    Dragon-Drops-Elytra = {
      # https://modrinth.com/mod/dragon-drops-elytra
      url = "https://cdn.modrinth.com/data/DPkbo3dg/versions/NwRksTCY/dragondropselytra-1.21.11-3.5.jar";
      flake = false;
    };
    Collective = {
      # https://modrinth.com/mod/collective
      url = "https://cdn.modrinth.com/data/e0M1UDsY/versions/T8rv7kwo/collective-1.21.11-8.13.jar";
      flake = false;
    };
    Just-Player-Heads = {
      # https://modrinth.com/mod/just-player-heads
      url = "https://cdn.modrinth.com/data/YdVBZMNR/versions/AlFsC8XK/justplayerheads-1.21.11-4.3.jar";
      flake = false;
    };
    Infinite-Trading = {
      # https://modrinth.com/mod/infinite-trading
      url = "https://cdn.modrinth.com/data/U3eoZT3o/versions/QmTnAQac/infinitetrading-1.21.11-4.6.jar";
      flake = false;
    };
    TNT-Breaks-Bedrock = {
      # https://modrinth.com/mod/tnt-breaks-bedrock
      url = "https://cdn.modrinth.com/data/eU2O6Xp1/versions/hwq9f9Cd/tntbreaksbedrock-1.21.11-3.6.jar";
      flake = false;
    };
    Recast = {
      # https://modrinth.com/mod/recast
      url = "https://cdn.modrinth.com/data/8TWzoOby/versions/sad63YT1/recast-1.21.11-3.7.jar";
      flake = false;
    };
    Respawning-Shulkers = {
      # https://modrinth.com/mod/respawning-shulkers
      url = "https://cdn.modrinth.com/data/gHCmhGUV/versions/UxqGoIcn/respawningshulkers-1.21.11-4.2.jar";
      flake = false;
    };
    Bigger-Sponge-Absorption-Radius = {
      # https://modrinth.com/mod/bigger-sponge-absorption-radius
      url = "https://cdn.modrinth.com/data/3PLAyBxz/versions/KzkF169B/biggerspongeabsorptionradius-1.21.11-3.7.jar";
      flake = false;
    };
    Fixed-Anvil-Repair-Cost = {
      # https://modrinth.com/mod/fixed-anvil-repair-cost
      url = "https://cdn.modrinth.com/data/jmLyNFBG/versions/uCZEtWWi/fixedanvilrepaircost-1.21.11-3.5.jar";
      flake = false;
    };
    Anvil-Restoration = {
      # https://modrinth.com/mod/anvil-restoration
      url = "https://cdn.modrinth.com/data/bd8nwTGy/versions/xGzeyADa/anvilrestoration-1.21.11-2.5.jar";
      flake = false;
    };
    Inventory-Totem = {
      # https://modrinth.com/mod/inventory-totem
      url = "https://cdn.modrinth.com/data/yQj7xqEM/versions/IzZmDI2F/inventorytotem-1.21.11-3.4.jar";
      flake = false;
    };
    Tree-Harvester = {
      # https://modrinth.com/mod/tree-harvester
      url = "https://cdn.modrinth.com/data/abooMhox/versions/8mfyGsIg/treeharvester-1.21.11-9.3.jar";
      flake = false;
    };
    Extended-Bone-Meal = {
      # https://modrinth.com/mod/extended-bone-meal
      url = "https://cdn.modrinth.com/data/bHkCoxMs/versions/Z4hgjtLH/extendedbonemeal-1.21.11-3.6.jar";
      flake = false;
    };
    Random-Bone-Meal-Flowers = {
      # https://modrinth.com/mod/random-bone-meal-flowers
      url = "https://cdn.modrinth.com/data/17enPZMC/versions/xncSYvvy/randombonemealflowers-1.21.11-4.7.jar";
      flake = false;
    };
    Bow-Infinity-Fix = {
      # https://modrinth.com/mod/bow-infinity-fix
      url = "https://cdn.modrinth.com/data/BFENfScW/versions/besCdt3U/BowInfinityFix-1.21.9-fabric-3.1.2.jar";
      flake = false;
    };
    Universal-Enchants = {
      # https://modrinth.com/mod/universal-enchants
      url = "https://cdn.modrinth.com/data/DT56YDir/versions/MuPwsQLB/UniversalEnchants-v21.11.2-mc1.21.11-Fabric.jar";
      flake = false;
    };
    Puzzles-Lib = {
      # https://modrinth.com/mod/puzzles-lib
      url = "https://cdn.modrinth.com/data/QAGBst4M/versions/7L1WGsjw/PuzzlesLib-v21.11.6-mc1.21.11-Fabric.jar";
      flake = false;
    };
    Grind-Enchantments = {
      # https://modrinth.com/mod/grind-enchantments
      url = "https://cdn.modrinth.com/data/WC4UgDcZ/versions/XX0LqtxX/grind-enchantments-4.1.0%2B1.21.11-pre2.jar";
      flake = false;
    };
    Player-Roles = {
      # https://modrinth.com/mod/player-roles
      url = "https://cdn.modrinth.com/data/Rt1mrUHm/versions/2PHCrWcd/player-roles-1.8.1.jar";
      flake = false;
    };
    Villager-Pickup = {
      # https://modrinth.com/mod/villager-pickup
      url = "https://cdn.modrinth.com/data/EL95Q1AM/versions/bf8Q2X39/villagerpickup-fabric-1.21.11-1.3.jar";
      flake = false;
    };
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-cache:4FILs79Adxn/798F8qk2PC1U8HaTlaPqptwNJrXNA1g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-substituters = [
      "https://install.determinate.systems"
      "https://cache.clan.lol"
      "https://nix-community.cachix.org"
      "https://cache.lounge.rocks/nix-cache"
      "https://cache.nixos.org"
    ];
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
      ];

      imports = [
        (inputs.import-tree ./flake-parts)
        inputs.mkdocs-flake.flakeModules.default
        inputs.clan-core.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
      ];
    };
}
