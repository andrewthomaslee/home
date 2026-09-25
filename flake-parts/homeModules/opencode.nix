{
  inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.opencode = {
    pkgs,
    config,
    customLib,
    # The NixOS config this home-manager user runs on (null only for
    # standalone home-manager evals, which never happens here). Used to
    # identify the machine for the per-machine context file below.
    osConfig,
    ...
  }: let
    cfg = config.homeSpec.programs.opencode;
    headroomCfg = config.homeSpec.programs.headroom;
    headroomEnabled = config.homeSpec.programs.headroom.enable or false;
    headroomProxyUrl = "http://${headroomCfg.proxy.host}:${toString headroomCfg.proxy.port}/v1";
    inherit (customLib.custom) relativeToRoot;
    # PAT file used by the wrapper: explicit githubPatFile override or the
    # canonical sops-nix deployment path of the shared "github-mcp" clan var
    # (declared by nixosModules/github-mcp for pat-mode users).
    githubMcpPatFile =
      if cfg.mcp.github.patFile == null
      then "/run/secrets/vars/shared/github-mcp/pat"
      else cfg.mcp.github.patFile;
    # Wrapper for the PAT auth method: exports GITHUB_PERSONAL_ACCESS_TOKEN
    # from the PAT file before exec'ing the server. The github-mcp-server
    # exits immediately when that env var is unset, so a readable file is a
    # hard requirement for the server to start.
    githubMcpWrapper = pkgs.writeShellScriptBin "github-mcp-server-opencode" ''
      if [ -r ${lib.escapeShellArg githubMcpPatFile} ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${lib.escapeShellArg githubMcpPatFile})"
      fi
      exec ${lib.getExe pkgs.unstable.github-mcp-server} stdio "$@"
    '';
    # devenv MCP wrapper: `devenv mcp` requires a devenv project
    # (devenv.nix in cwd or an ancestor) and hard-exits otherwise. Mirror
    # devenv's own project discovery (walk up for devenv.nix); when there
    # is none (e.g. the home repo, which uses plain `nix develop`), fall
    # back to the pinned agent project generated in xdg.configFile below
    # so the server always starts and can serve
    # search_packages / search_options.
    devenvMcpWrapper = pkgs.writeShellScriptBin "devenv-mcp-opencode" ''
      dir="$PWD"
      while [ "$dir" != "/" ]; do
        if [ -f "$dir/devenv.nix" ]; then
          exec ${lib.getExe pkgs.devenv} mcp "$@"
        fi
        dir="$(dirname "$dir")"
      done
      cd "$HOME/.config/devenv-agent"
      exec ${lib.getExe pkgs.devenv} mcp "$@"
    '';
    # Morph API key: only wrapped when a key file is configured. When the
    # plugin is enabled and no explicit file is set, default to the
    # sops-deployed clan var from nixosModules/morph-api-key (same
    # pattern as githubMcpPatFile).
    morphApiKeyFile =
      if cfg.plugins.morph-fast-apply.apiKeyFile != null
      then cfg.plugins.morph-fast-apply.apiKeyFile
      else if cfg.plugins.morph-fast-apply.enable
      then "/run/secrets/vars/shared/morph-api-key/api-key"
      else null;
    morphEnabledWithKey =
      cfg.plugins.morph-fast-apply.enable && morphApiKeyFile != null;
    opencodeMorphWrapper = pkgs.writeShellScriptBin "opencode" ''
      if [ -r ${lib.escapeShellArg morphApiKeyFile} ]; then
        export MORPH_API_KEY="$(cat ${lib.escapeShellArg morphApiKeyFile})"
      fi
      export MORPH_MODEL=${lib.escapeShellArg cfg.plugins.morph-fast-apply.model}
      exec ${lib.getExe pkgs.opencode} "$@"
    '';
    # Hermetic plugin packages (flake-parts/packages/opencode-plugins.nix).
    # V2 native-plugin entries: each is an absolute store-path file whose
    # module default-exports a V2 plugin `{ id, setup|effect }` (the V1
    # loader accepted default-export hook functions; those no longer run).
    pluginEntries =
      lib.optional cfg.plugins.cc-safety-net.enable "${pkgs.cc-safety-net}/share/opencode-plugins/cc-safety-net/dist/index.js"
      ++ lib.optional cfg.plugins.morph-fast-apply.enable "${pkgs.opencode-morph-fast-apply}/share/opencode-plugins/opencode-morph-fast-apply/index.ts"
      ++ lib.optional cfg.plugins.opencode-mem.enable "${pkgs.opencode-mem}/share/opencode-plugins/opencode-mem/dist/v2/plugin.js";
    # ---- References (V2 attachable doc bundles) ---- #
    # Repo-side source: top-level `references/<name>/index.md` (one dir
    # per reference, mirroring the skills/ convention). Enabled
    # references are installed into ~/.config/opencode/references/<name>
    # (linkFarm of per-name symlinks) and registered in
    # settings.references with `path` + `description` — entries with a
    # description are advertised in agent instructions, so the alias is
    # discoverable without a client-side attach. Default descriptions
    # per alias live here; profiles can override the text.
    availableReferences = {
      "nix-style" = "Nix code style + tool loop (user preferences): attribute nesting/quoting/inherit rules, module-system and repo-root-path conventions, the mandatory alejandra/statix/deadnix tool loop, devShell awareness, and the flake-repo agent contract. Use when writing or editing any .nix file.";
      "flake-parts" = "flake-parts module system: mkFlake/perSystem mechanics, what the infra provides (self', inputs', flake, withSystem), input handling (follows, FlakeHub URLs, flake = false pins), the checks.lint gate, and integrations (clan-core, home-manager, devenv, mkdocs-flake). Load when editing flake.nix or any flake-parts module.";
      "import-tree" = "flake-parts auto-import via import-tree: provenance, mechanics (_-prefix escape hatch, .nix-only, one module-system eval), tree layout conventions, and agent rules (no import list ever). Load when adding, moving, or drafting files under flake-parts/.";
      "determinate" = "Determinate Systems + FlakeHub: where the docs live (docs.determinate.systems), publishing, FlakeHub Cache/private flakes/resolved store paths, semver (tagged vs rolling 0.1.<commits-on-branch>), and the fh CLI incl. fh apply deployment. Load when touching flake input URLs, releases, or machine deploys.";
      "home-manager" = "home-manager with flakes and flake-parts: NixOS-module integration, the homeSpec.* namespace, the homeModules.default composition filter, and a worked user-profile example (flake-parts/homeModules/profiles/netsa.nix). Load when building or changing a home-manager user profile.";
      "clan-core" = "Fleet management with clan-core: inventory.nix (machines/instances/roles/tags), clanServices (perInstance/perMachine), build-time exports + the strict-eval check, the clan CLI, vars generators, machine update flows (FlakeHub pull vs clan machines update), and clanService NixOS VM tests. Load when working on anything clan.*.";
      "devenv" = "devenv 2.x dev environments: full CLI reference, devenv.yaml inputs/lock discipline, CLI-native vs flake embedding (and why CLI is the default for dev shells), the borg hybrid pattern (one shared module, two lockfiles, drift check), devcontainer.json, monorepo/polyrepo, containers/OCI/K8s, and the Claude Code integration. Load when writing devenv.nix/devenv.yaml/.devcontainer or running devenv commands.";
      "vm-tests" = "Hermetic NixOS VM tests: hermeticity rule, structure (nixosLib.runTest modules under legacyPackages, never checks), sm/md/lg size variants, running via .#vm-test (sandboxed vs driver mode), the agent loop, and patterns/anti-patterns. Load when creating, running, or debugging a VM test.";
    };
    # Aliases of the references the user enabled, name -> description.
    enabledReferences = lib.filterAttrs (_: r: r.enable) cfg.references;
    # settings fragment for enabled references (merged under mkIf below
    # — kept as one binding so no assignment is left to lint).
    referenceSettings = {
      references =
        lib.mapAttrs
        (name: r: {
          path = "~/.config/opencode/references/${name}";
          inherit (r) description;
        })
        enabledReferences;
    };
    # ---- Machine context (per-machine system-prompt instruction) ---- #
    # Home-manager runs as a NixOS module here, so osConfig carries the
    # machine this user is on. From it, the machine's nixos-facter report
    # (machines/<host>/facter.json) is read at eval time and summarized
    # into ~/.config/opencode/instructions/machine-<host>.md, wired into
    # settings.instructions below — opencode injects instruction files
    # into the system prompt of every session on that machine.
    hostName =
      if osConfig == null
      then ""
      else osConfig.networking.hostName;
    facterFile = relativeToRoot "machines/${hostName}/facter.json";
    # Not every opencode consumer has a facter report (the installer ISO
    # has none, KubeVirt agent VMs have a hostname without a machines/
    # entry), so the facter-derived content is optional and everything
    # below stays lazy: nothing is read unless this user enables opencode.
    hasFacter = hostName != "" && builtins.pathExists facterFile;
    facterReport =
      if hasFacter
      then builtins.fromJSON (builtins.readFile facterFile)
      else {};
    # Best-effort accessors: facter reports differ per machine and facter
    # version (absent keys, null values, generic PCI class strings) — any
    # missing fact is skipped rather than failing the build.
    facterList = value:
      if lib.isList value
      then value
      else [];
    facterFirst = list:
      if list != []
      then lib.head list
      else null;
    facterLine = prefix: parts:
      if parts == []
      then null
      else "- ${prefix}: ${lib.concatStringsSep ", " parts}";
    # facterGet walks an attrset path (["hardware" "cpu"]), returning null
    # for any missing step; facterAttr reads one attribute off a possibly
    # null/missing object. Both are null-safe instead of throwing.
    facterGet = path: lib.attrByPath path null facterReport;
    facterAttr = set: name:
      if lib.isAttrs set
      then set.${name} or null
      else null;
    cpuEntry = facterFirst (facterList (facterGet ["hardware" "cpu"]));
    cpuModel = facterAttr cpuEntry "model_name";
    cpuThreads = facterAttr cpuEntry "units";
    gpuEntry = facterFirst (facterList (facterGet ["hardware" "graphics_card"]));
    gpuVendor = facterAttr (facterAttr gpuEntry "vendor") "name";
    gpuDriver = facterAttr gpuEntry "driver";
    diskModels =
      lib.unique
      (lib.remove null
        (lib.map (d: facterAttr d "model")
          (facterList (facterGet ["hardware" "disk"]))));
    memDevices =
      lib.filter (d: lib.isAttrs d && ((d.size or 0) > 0))
      (facterList (facterGet ["smbios" "memory_device"]));
    # memory_device sizes are reported in KiB; empty DIMM slots are 0 and
    # filtered out above.
    memGiB = builtins.div (lib.foldl' (sum: d: sum + (d.size or 0)) 0 memDevices) (1024 * 1024);
    memVendor =
      if memDevices == []
      then null
      else (lib.head memDevices).manufacturer or null;
    # Token-lean rendering: the first word is enough for a DIMM
    # manufacturer ("Micron Technology" -> "Micron").
    memVendorShort =
      if memVendor == null
      then null
      else lib.head (lib.splitString " " memVendor);
    machineContextHardware = lib.remove null [
      (facterLine "CPU"
        (lib.remove null [
          cpuModel
          (
            if cpuThreads == null
            then null
            else "${toString cpuThreads} threads"
          )
        ]))
      (facterLine "GPU"
        (lib.remove null [
          gpuVendor
          (
            if gpuDriver == null
            then null
            else "driver ${gpuDriver}"
          )
        ]))
      (facterLine "Memory"
        (lib.remove null [
          (
            if memDevices == []
            then null
            else "${toString memGiB} GiB${lib.optionalString (memVendorShort != null) " (${toString (lib.length memDevices)}x ${memVendorShort} DIMMs)"}"
          )
        ]))
      (facterLine "Disk" diskModels)
    ];
    # Plain, matter-of-fact and token-lean machine descriptor (no markdown
    # decoration) — injected into the system prompt of every opencode
    # session on this machine: what the machine is, what hardware it has
    # and where the facts about it live. The read-only rule and the
    # AGENTS.md rule apply on every machine; the hardware and facts paths
    # only when a facter report exists (installer ISO, KubeVirt agent VMs
    # have none).
    machineContextLines =
      [
        "Machine: ${hostName} (NixOS ${pkgs.stdenv.hostPlatform.system})"
        ""
      ]
      ++ lib.optionals (machineContextHardware != [])
      (["Hardware:"] ++ machineContextHardware ++ [""])
      ++ [
        "Repo: github.com/${cfg.machineContext.repoOwner}/${cfg.machineContext.repoName} (local: ${config.home.homeDirectory}/${cfg.machineContext.repoPath})"
      ]
      ++ lib.optionals hasFacter [
        "Machine facts: machines/${hostName}/facter.json, disko.nix, configuration.nix"
      ]
      ++ [
        "Machine config is strictly read-only: changes only by repo owner ${cfg.machineContext.repoOwner}, or when instructed to while working in the home repo."
        ""
        "Read a repo's AGENTS.md before working in it."
      ]
      # nix-style is the user's Nix-writing preferences (style guide +
      # tool loop); keep an always-on pointer to it in every session's
      # system prompt when the reference is enabled, so agents writing
      # .nix files load it.
      ++ lib.optionals cfg.references.nix-style.enable [
        "When writing or editing any .nix file: read the opencode reference nix-style (style rules + mandatory alejandra/statix/deadnix tool loop) first."
      ]
      ++ lib.optionals (cfg.machineContext.extraText != null)
      ([""]
        ++ lib.filter (line: line != "")
        (lib.splitString "\n" cfg.machineContext.extraText));
  in {
    options.homeSpec.programs.opencode = {
      enable = lib.mkEnableOption "default opencode configuration";
      # Install the Electron desktop app (opencode-desktop). Disable for
      # headless machines (saves ~2.4 GB: electron + gtk stack).
      enableDesktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install opencode-desktop (Electron GUI app).";
      };
      # Install the full heavy development toolset (k3s, rke2, k3d, devpod,
      # devcontainer, podman, gleam, terraform-ls, helm-ls, go_latest).
      # Disable for slim headless agents (keeps docker, kubectl, helm).
      fullDevTools = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the full heavy dev toolset in opencode extraPackages.";
      };
      # Per-machine system-prompt context (machineContext.*): generates
      # ~/.config/opencode/instructions/machine-<hostname>.md with the
      # hostname, hardware facts from the machine's facter.json and
      # pointers to where machine facts live, then loads it into every
      # opencode session via settings.instructions.
      machineContext = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Generate the per-machine context instruction file (hostname + hardware facts from machines/<hostname>/facter.json).";
        };
        repoPath = lib.mkOption {
          type = lib.types.str;
          default = "home";
          description = "Directory name of the home flake repo relative to the user's home directory, written into the generated file.";
        };
        repoOwner = lib.mkOption {
          type = lib.types.str;
          default = "andrewthomaslee";
          description = "Owner of the remote flake repo, written into the generated file's Remote line.";
        };
        repoName = lib.mkOption {
          type = lib.types.str;
          default = "home";
          description = "Name of the remote flake repo, written into the generated file's Remote line.";
        };
        extraText = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "Optional per-machine notes appended to the generated file (set from machines/<hostname>/configuration.nix).";
        };
      };
      # ---- MCP servers: homeSpec.programs.opencode.mcp.<name>.enable ---- #
      mcp = {
        # mcp-nixos: NixOS / Home Manager / nix-darwin package & option
        # search (local stdio, flake package).
        nix.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the mcp-nixos MCP server in opencode settings.";
        };
        # OpenRouter remote MCP: live model catalog, pricing, credits,
        # benchmarks, docs search. Hosted; OAuth flow on first use.
        openrouter.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the OpenRouter remote MCP server in opencode settings.";
        };
        # Playwright: browser automation via accessibility snapshots
        # (hermetic nixpkgs package; browsers pinned in the store).
        playwright.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the Playwright MCP server (nixpkgs playwright-mcp) in opencode settings.";
        };
        # GitHub: auth method selected by `auth`; the two methods are
        # mutually exclusive (enum + assertion below). pat-mode derives the
        # clan vars generator via nixosModules/github-mcp.
        github = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the GitHub MCP server in opencode settings.";
          };
          auth = lib.mkOption {
            type = lib.types.enum ["oauth" "pat"];
            default = "oauth";
            description = ''
              GitHub MCP auth method (mutually exclusive):
              - "oauth": remote hosted server (https://api.githubcopilot.com/mcp/);
                opencode runs the browser OAuth flow on first use. No secret.
              - "pat": local stdio server reading the PAT from `patFile`
                (usually the clan var at /run/secrets/vars/shared/github-mcp/pat).
            '';
          };
          patFile = lib.mkOption {
            type = with lib.types;
              nullOr str;
            default = null;
            description = ''
              Path to a file containing the GitHub Personal Access Token.
              Only used with mcp.github.auth = "pat"; must be null for "oauth".
            '';
          };
        };
        # Cloudflare remote MCP servers (hosted by Cloudflare; OAuth on
        # first use, the docs server is public). Off by default, enabled
        # via the netsa tag profile for the netsa dev machines.
        cloudflare.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Code Mode MCP server (recommended, broad access across Cloudflare APIs through code execution).";
        };
        cloudflare-docs.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Documentation MCP server (up-to-date Cloudflare reference information).";
        };
        cloudflare-bindings.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Workers Bindings MCP server (build Workers apps with storage, AI, and compute primitives).";
        };
        cloudflare-builds.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Workers Builds MCP server (insights and management for Cloudflare Workers Builds).";
        };
        cloudflare-browser.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Browser Run MCP server (fetch web pages, convert to markdown, take screenshots).";
        };
        cloudflare-containers.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Cloudflare Container MCP server (spin up a sandbox development environment).";
        };
        # MDN Web Docs remote MCP server (hosted by Mozilla; off by
        # default, enabled via the netsa tag profile).
        mdn.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the MDN Web Docs MCP server (up-to-date web API/CSS/JS reference from Mozilla).";
        };
        # ArtifactHub MCP server (local stdio, hermetic nix build; off by
        # default, enabled via the netsa tag profile). Helm-chart tools
        # against artifacthub.io: chart info, default values, templates.
        artifacthub.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the ArtifactHub MCP server (Helm chart info/values/templates from artifacthub.io) in opencode settings.";
        };
        # Kubernetes MCP server (containers/kubernetes-mcp-server, hermetic
        # Go build; stdio is the default transport). Reads the user's
        # kubeconfig.
        kubernetes = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the Kubernetes MCP server in opencode settings. Off by default: it exits at startup without a kubeconfig (~/.kube/config); enable per profile/machine once cluster credentials exist.";
          };
          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Run the Kubernetes MCP server in read-only mode (--read-only: only readOnlyHint tools exposed).";
          };
        };
        # devenv MCP: local stdio `devenv mcp` (search nixpkgs packages +
        # devenv options) via the devenv-mcp-opencode wrapper. Off by
        # default, enabled via the netsa tag profile. The devenv CLI comes
        # from the devenv flake input via the overlay; outside devenv
        # projects the wrapper serves the pinned ~/.config/devenv-agent
        # project instead.
        devenv.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the devenv MCP server (search nixpkgs packages and devenv options) in opencode settings.";
        };
        # TypeUI: hosted design-skills MCP for AI-first UI work
        # (https://mcp.typeui.sh/mcp, OAuth on first use). Off by default,
        # enabled for the dev profile.
        typeui.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the TypeUI remote MCP server (design systems and UI prompts) in opencode settings.";
        };
        # Varlock docs MCP: hosted docs-search server
        # (https://docs.mcp.varlock.dev/mcp, public, no auth). Off by
        # default, enabled via the netsa tag profile.
        varlock-docs.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Varlock docs MCP server (search varlock.dev documentation) in opencode settings.";
        };
      };

      # ---- Plugins: homeSpec.programs.opencode.plugins.<name>.enable ---- #
      plugins = {
        # CC Safety Net: pre-tool-call guard blocking destructive commands
        # (git reset --hard, rm -rf on dangerous targets, ...) and secret
        # access (SSH keys, .env, ~/.aws). Pure-JS plugin, hermetic build;
        # policy tuning is runtime state via `cc-safety-net gui`.
        cc-safety-net.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the CC Safety Net plugin (blocks destructive commands and secret access).";
        };
        # Morph Fast Apply: `morph_edit` tool (lazy edit markers, ~10k
        # tok/s merges). Requires a Morph API key exported into the
        # opencode process env; `apiKeyFile` is provisioned by the
        # morph-api-key clan var generator (nixosModules/morph-api-key).
        # Off by default until the key is provisioned.
        morph-fast-apply = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the Morph Fast Apply plugin (morph_edit tool). Requires a Morph API key via apiKeyFile.";
          };
          apiKeyFile = lib.mkOption {
            type = with lib.types;
              nullOr str;
            default = null;
            description = ''
              Path to a file containing the Morph API key, exported as
              MORPH_API_KEY by the opencode wrapper at launch. Usually the
              clan var at /run/secrets/vars/shared/morph-api-key/api-key.
            '';
          };
          model = lib.mkOption {
            type = lib.types.str;
            default = "auto";
            description = "Morph model (morph-v3-fast, morph-v3-large, or auto).";
          };
        };
        # opencode-mem: persistent project memory with local vector search
        # (embedded libSQL + onnxruntime embeddings). The default embedding
        # model (Xenova/nomic-embed-text-v1) is downloaded from Hugging
        # Face on first use and cached under ~/.opencode-mem. Web UI on
        # 127.0.0.1:4747. Runtime config at
        # ~/.config/opencode/opencode-mem.jsonc (plugin writes a template).
        opencode-mem.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the opencode-mem persistent memory plugin (memory tool + web UI).";
        };
      };

      # ---- References: homeSpec.programs.opencode.references.<name> ---- #
      # V2 attachable doc bundles (opencode.json references field): one
      # option per alias of the repo's top-level references/ tree.
      # Enabling installs ~/.config/opencode/references/<name> (symlink to
      # the store copy) and advertises it via settings.references; the
      # description is what agents see in their instructions.
      references = lib.genAttrs (builtins.attrNames availableReferences) (name:
        lib.mkOption {
          default = {};
          description = "Options for the ${name} opencode reference bundle (references/${name}/).";
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable the ${name} reference: install it and advertise it in settings.references.";
              };
              description = lib.mkOption {
                type = lib.types.str;
                default = availableReferences.${name};
                description = "When-to-use text advertised with the reference in agent instructions.";
              };
            };
          };
        });
    };
    config = lib.mkIf cfg.enable {
      xdg.configFile = {
        # Morph Fast Apply: ship the packaged always-on routing instruction
        # so agents reliably pick morph_edit over native edit.
        "opencode/instructions/morph-tools.md" = lib.mkIf cfg.plugins.morph-fast-apply.enable {
          source = "${pkgs.opencode-morph-fast-apply}/share/opencode-plugins/opencode-morph-fast-apply/instructions/morph-tools.md";
        };

        # Per-machine context file (built above from osConfig + facter.json):
        # opencode expands the ~/ path in settings.instructions and injects
        # the file into the system prompt of every session on this machine.
        "opencode/instructions/machine-${hostName}.md" = lib.mkIf (cfg.machineContext.enable && hostName != "") {
          text = lib.concatStringsSep "\n" machineContextLines + "\n";
        };

        # Skills: repo-local custom skills + external skill sources, merged
        # into ~/.config/opencode/skills by inputs.agents.lib.mkSkills (a
        # linkFarm of per-skill symlinks). Custom skills override externals
        # on name collision; among externals, earlier entries in the list
        # win. customLib (and thus relativeToRoot) reaches home modules via
        # home-manager.extraSpecialArgs, set once in nixosModules/default.
        "opencode/skills".source = inputs.agents.lib.mkSkills {
          inherit pkgs;
          customSkills = relativeToRoot "skills";
          externalSkills = [
            # Claude skills from anthropics/skills (all skills under skills/)
            {src = inputs.skills-anthropic;}
            # Payload CMS skills (payload, cms-migration)
            {src = inputs.skills-payloadcms;}
          ];
        };

        # References: one symlink per enabled alias under
        # ~/.config/opencode/references/<name>, pointing at the repo's
        # references/<name>/ store copy (linkFarm over the enabled subset).
        # mkIf wraps the whole file entry, not just source — an unset
        # `source` under a disabled mkIf would throw at eval.
        "opencode/references" = lib.mkIf (enabledReferences != {}) {
          source =
            pkgs.linkFarm "opencode-references"
            (lib.mapAttrsToList
              (name: _: {
                inherit name;
                path = relativeToRoot "references/${name}";
              })
              enabledReferences);
        };

        # devenv MCP fallback project: pinned devenv project the
        # devenv-mcp-opencode wrapper serves when opencode is opened
        # outside a devenv project. nixpkgs is pinned to the repo flake's
        # nixpkgs input as a store path — no runtime fetch and search
        # results match the fleet's nixpkgs. devenv writes devenv.lock and
        # runtime state (.devenv/) next to these files on first use.
        "devenv-agent/devenv.yaml" = lib.mkIf cfg.mcp.devenv.enable {
          text = ''
            inputs:
              nixpkgs:
                url: path:${inputs.nixpkgs}
              # devenv 2.x implicitly adds a `devenv` input on first lock
              # update; pin it to the repo's devenv flake input so the
              # fallback project stays fully offline (VMs boot without
              # working DNS).
              devenv:
                url: path:${inputs.devenv.outPath}
          '';
        };
        "devenv-agent/devenv.nix" = lib.mkIf cfg.mcp.devenv.enable {
          text = ''
            {...}: {
              # Pinned minimal devenv project: fallback root for the
              # devenv MCP server (devenv-mcp-opencode wrapper) when
              # opencode runs outside a devenv project.
              packages = [];
            }
          '';
        };
      };

      home.packages =
        (lib.optionals cfg.enableDesktop [
          # Overlay package: inputs.opencode v2.0.16 with the upstream
          # postInstall completion fix (see overlays/default.nix).
          pkgs.opencode-desktop
        ])
        ++ (lib.optionals cfg.fullDevTools (with pkgs.unstable; [
          podman
          gleam
          helm-ls
          terraform-ls
          go_latest
          devcontainer
          k3d
          (lib.lowPrio k3s)
          rke2
          devpod
          kustomize
          kubeconform
          stern
          kubectx
          kubectl-neat
          helm-docs
          rancher
          etcd
          kubevirt
          kubernetes-helmPlugins.helm-diff
        ]))
        ++ (lib.optionals cfg.mcp.playwright.enable [
          pkgs.playwright-mcp
        ])
        ++ (lib.optionals cfg.mcp.github.enable [
          pkgs.unstable.github-mcp-server
        ])
        ++ (lib.optionals cfg.mcp.artifacthub.enable [
          pkgs.artifacthub-mcp
        ])
        ++ (lib.optionals cfg.mcp.devenv.enable [
          pkgs.devenv
          # The devenv-mcp-opencode wrapper referenced by the local
          # mcp.servers.devenv command, also installed on PATH so the
          # server can be driven manually (the VM test probes it that way).
          devenvMcpWrapper
        ])
        ++ (lib.optionals (cfg.mcp.github.enable && cfg.mcp.github.auth == "pat") [
          githubMcpWrapper
        ])
        # Plugin packages: referenced by store path in settings.plugins, so
        # keep them in the closure (GC safety).
        ++ (lib.optional cfg.plugins.cc-safety-net.enable pkgs.cc-safety-net)
        ++ (lib.optional cfg.plugins.morph-fast-apply.enable pkgs.opencode-morph-fast-apply)
        ++ (lib.optional cfg.plugins.opencode-mem.enable pkgs.opencode-mem);
      # NOTE: the morph key wrapper (opencodeMorphWrapper) is NOT added
      # here — programs.opencode.package above already installs it into
      # the user env, and a second entry would collide in buildEnv.
      assertions = [
        {
          assertion = cfg.mcp.github.auth == "oauth" -> cfg.mcp.github.patFile == null;
          message = "opencode: mcp.github.patFile is only valid with mcp.github.auth = \"pat\" — the oauth and pat methods are mutually exclusive.";
        }
      ];
      programs.opencode = {
        enable = true;
        # Morph key wrapper: exports MORPH_API_KEY (from the clan var file)
        # into the opencode process env when the morph plugin is enabled
        # with a configured key file; otherwise the stock package. The
        # package comes from the overlay (inputs.opencode v2.0.16 with the
        # upstream postInstall completion fix).
        package =
          if morphEnabledWithKey
          then opencodeMorphWrapper
          else pkgs.opencode;
        extraPackages =
          (with pkgs.unstable; [
            actionlint
            uv
            nix
            pyrefly
            nixd
            statix
            deadnix
            nix-output-monitor
            yaml-language-server
            alejandra
            ruff
            python3
            git
            httpie
            kubernetes-helm
            jq
            yq
            bun
            nodejs-slim_latest
            docker
            kubernetes
          ])
          # Overlay package (self.packages), not in nixpkgs-unstable.
          ++ [pkgs.opencode-nixd-scaffold]
          ++ (lib.optionals cfg.fullDevTools (with pkgs.unstable; [
            podman
            gleam
            helm-ls
            terraform-ls
            go_latest
            devcontainer
            k3d
            (lib.lowPrio k3s)
            rke2
            devpod
            kustomize
            kubeconform
            stern
            kubectx
            kubectl-neat
            helm-docs
            rancher
            etcd
            kubevirt
            kubernetes-helmPlugins.helm-diff
          ]))
          ++ (lib.optionals cfg.mcp.playwright.enable [
            pkgs.playwright-mcp
          ])
          ++ (lib.optionals cfg.mcp.github.enable [
            pkgs.unstable.github-mcp-server
          ])
          ++ (lib.optionals cfg.mcp.artifacthub.enable [
            pkgs.artifacthub-mcp
          ])
          ++ (lib.optionals cfg.mcp.devenv.enable [
            pkgs.devenv
          ]);
        tui.theme = "tokyonight";
        settings = lib.mkMerge [
          {
            model = "glm-5.3-flash";
            # small_model V1 field -> the model of the built-in title agent
            # (native V2 shape; V1 small_model is normalized silently).
            agents.title.model = "glm-5.3-flash";
            # V2 keeps compaction.auto; the V1 tail_turns budget is replaced
            # by checkpoint-based compaction (keep.tokens) — dropped here.
            compaction.auto = true;
            # V2 ordered permissions array (last matching rule wins; the V1
            # permission.* map is normalized silently). Path actions keep
            # their names ("read", "external_directory"); bash/task/write
            # were renamed shell/subagent/edit upstream.
            permissions = [
              {
                action = "read";
                resource = "/nix/store/**";
                effect = "allow";
              }
              {
                action = "read";
                resource = "/tmp/**";
                effect = "allow";
              }
              {
                action = "read";
                resource = "/home/netsa/.config/opencode/";
                effect = "allow";
              }
              {
                action = "read";
                resource = "/etc/hostname";
                effect = "allow";
              }
              {
                action = "external_directory";
                resource = "/nix/store/**";
                effect = "allow";
              }
              {
                action = "external_directory";
                resource = "/tmp/**";
                effect = "allow";
              }
            ];
            # NOTE: V1 settings.lsp was dropped — V2 accepts lsp config but
            # never runs language servers; diagnostics come from the agent
            # running the linters/typecheckers in extraPackages directly
            # (statix/deadnix/nix build, pyrefly check, gleam check, ...).
            formatter = {
              nix = {
                command = ["alejandra" "$FILE"];
                extensions = [".nix"];
              };
              ruff = {
                command = ["ruff" "format" "$FILE"];
                extensions = [".py" ".pyi"];
              };
              gleam = {
                command = ["gleam" "format" "$FILE"];
                extensions = [".gleam"];
              };
            };
          }
          (lib.mkIf cfg.mcp.nix.enable {
            mcp.servers.nixos = {
              type = "local";
              command = ["${lib.getExe inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos}"];
            };
          })
          (lib.mkIf cfg.mcp.openrouter.enable {
            mcp.servers.openrouter = {
              # Remote hosted server: no local install, no docker/uvx.
              # opencode handles the OAuth login automatically on first
              # tool use (minted key expires after 7 days).
              type = "remote";
              url = "https://mcp.openrouter.ai/mcp";
            };
          })
          (lib.mkIf cfg.mcp.playwright.enable {
            mcp.servers.playwright = {
              # Hermetic local server: the nixpkgs wrapper pins the
              # browser bundle (playwright-driver.browsers) and the
              # playwright node modules, so nothing is downloaded at
              # runtime. --headless so it works on displayless agents;
              # chromium is the nixpkgs default browser.
              type = "local";
              command = ["${lib.getExe pkgs.playwright-mcp}" "--headless"];
            };
          })
          (lib.mkIf cfg.mcp.github.enable {
            mcp.servers.github =
              if cfg.mcp.github.auth == "pat"
              then {
                # Local stdio server with PAT auth: the wrapper reads the
                # clan-var-deployed PAT file and exports
                # GITHUB_PERSONAL_ACCESS_TOKEN at server start.
                type = "local";
                command = ["${githubMcpWrapper}/bin/github-mcp-server-opencode"];
              }
              else {
                # Remote hosted server: no local install, no PAT file.
                # opencode handles the browser OAuth flow automatically on
                # first tool use.
                type = "remote";
                url = "https://api.githubcopilot.com/mcp/";
              };
          })
          # Cloudflare remote MCP servers: hosted by Cloudflare, no local
          # install. opencode handles the Cloudflare OAuth flow on first
          # tool use (the docs server is public).
          (lib.mkIf cfg.mcp.cloudflare.enable {
            mcp.servers.cloudflare = {
              type = "remote";
              url = "https://mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-docs.enable {
            mcp.servers.cloudflare-docs = {
              type = "remote";
              url = "https://docs.mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-bindings.enable {
            mcp.servers.cloudflare-bindings = {
              type = "remote";
              url = "https://bindings.mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-builds.enable {
            mcp.servers.cloudflare-builds = {
              type = "remote";
              url = "https://builds.mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-browser.enable {
            mcp.servers.cloudflare-browser = {
              type = "remote";
              url = "https://browser.mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-containers.enable {
            mcp.servers.cloudflare-containers = {
              type = "remote";
              url = "https://containers.mcp.cloudflare.com/mcp";
            };
          })
          (lib.mkIf cfg.mcp.mdn.enable {
            # MDN Web Docs, hosted by Mozilla — no local install.
            mcp.servers.mdn = {
              type = "remote";
              url = "https://mcp.mdn.mozilla.net/";
            };
          })
          (lib.mkIf cfg.mcp.artifacthub.enable {
            # ArtifactHub, local stdio server — hermetic nix build from the
            # pinned v1.1.1 source (packages/artifacthub-mcp.nix); no
            # docker/npx runtime downloads.
            mcp.servers.artifacthub = {
              type = "local";
              command = ["${lib.getExe pkgs.artifacthub-mcp}"];
            };
          })
          (lib.mkIf cfg.mcp.kubernetes.enable {
            # Kubernetes MCP server (containers/kubernetes-mcp-server):
            # hermetic Go build, stdio is the default transport (no
            # --stdio flag). Uses the user's kubeconfig; optional
            # --read-only restricts to readOnlyHint tools.
            mcp.servers.kubernetes = {
              type = "local";
              command =
                ["${lib.getExe pkgs.kubernetes-mcp-server}"]
                ++ lib.optional cfg.mcp.kubernetes.readOnly "--read-only";
            };
          })
          (lib.mkIf cfg.mcp.devenv.enable {
            # devenv MCP: local stdio `devenv mcp` via the wrapper —
            # serves the cwd's devenv project when there is one, the
            # pinned ~/.config/devenv-agent project otherwise (devenv
            # hard-exits outside devenv projects).
            mcp.servers.devenv = {
              type = "local";
              command = ["${devenvMcpWrapper}/bin/devenv-mcp-opencode"];
            };
          })
          (lib.mkIf headroomEnabled {
            mcp.servers.headroom = {
              type = "local";
              command = ["${lib.getExe headroomCfg.package}" "mcp" "serve"];
            };
            # Headroom proxy: reroute provider traffic through the proxy.
            # NOTE: the V1 transport plugin (headroom's entry.opencode.js)
            # is gone — its default export is a V1 plugin function and V2
            # only loads V2 plugins ({ id, setup }); headroom compresses
            # via these providers.*.settings.baseURL overrides (native V2
            # shape; V1 was provider.<p>.options.baseURL) plus its MCP
            # compress/retrieve tools.
            providers = {
              deepseek.settings.baseURL = headroomProxyUrl;
              anthropic.settings.baseURL = headroomProxyUrl;
              openai.settings.baseURL = headroomProxyUrl;
            };
          })
          # Morph Fast Apply: point the agent at the always-on instruction
          # (packaged file synced to the xdg path above).
          (lib.mkIf cfg.plugins.morph-fast-apply.enable {
            instructions = ["~/.config/opencode/instructions/morph-tools.md"];
          })
          # Per-machine context file (generated above). Only wired when a
          # facter report exists for this hostname — the installer ISO and
          # KubeVirt agent VMs have none, so they skip it.
          (lib.mkIf (cfg.machineContext.enable && hasFacter) {
            instructions = ["~/.config/opencode/instructions/machine-${hostName}.md"];
          })
          # TypeUI: hosted design-skills MCP (OAuth on first use).
          (lib.mkIf cfg.mcp.typeui.enable {
            mcp.servers.typeui = {
              type = "remote";
              url = "https://mcp.typeui.sh/mcp";
            };
          })
          # Varlock docs: hosted docs-search server
          # (https://docs.mcp.varlock.dev/mcp) — public, no auth.
          (lib.mkIf cfg.mcp.varlock-docs.enable {
            mcp.servers.varlock-docs = {
              type = "remote";
              url = "https://docs.mcp.varlock.dev/mcp";
            };
          })
          # References: V2 named doc bundles. path uses the home-relative
          # form opencode resolves itself (~/.config/opencode/references —
          # the linkFarm above); description is advertised in agent
          # instructions so the alias is discoverable without a manual
          # attach.
          (lib.mkIf (enabledReferences != {}) referenceSettings)
          # Reference reads happen outside the active project Location, so
          # they additionally need the external_directory permission
          # (read allow alone is not enough for attachments/reads from
          # another repo). Scoped to the references dir, not the whole
          # config dir.
          (lib.mkIf (enabledReferences != {}) {
            permissions = [
              {
                action = "read";
                resource = "${config.home.homeDirectory}/.config/opencode/references/**";
                effect = "allow";
              }
              {
                action = "external_directory";
                resource = "${config.home.homeDirectory}/.config/opencode/references/**";
                effect = "allow";
              }
            ];
          })
          # Plugin entries: single definition so mkMerge never sees two
          # conflicting `plugins` lists. Each entry is an absolute store
          # path (a V2 plugin module: default export `{ id, setup }`), so
          # nothing is fetched from npm at runtime; the packages are kept
          # alive via home.packages.
          (lib.mkIf (pluginEntries != []) {
            plugins = pluginEntries;
          })
        ];
      };
    };
  };
}
