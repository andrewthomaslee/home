{
  inputs,
  lib,
  ...
}: {
  # ------ Home-manager Module ------ #
  # AI coding agents and the shared repo skill set, consolidated under
  # one namespace:
  #
  #   homeSpec.agents.skills.enabled   — build the merged skills tree
  #     (repo skills/ + external flake-input sources, composed by
  #     inputs.agents.lib.mkSkills) and wire it into every enabled
  #     agent's skills dir. Defaults to true when any agent is enabled.
  #   homeSpec.agents.skills.extraSources — per-machine external skill
  #     sources appended to mkSkills' externalSkills.
  #   homeSpec.agents.<agent>.enabled  — install pi / kimi / claude /
  #     opencode and point the agent's skills dir at the shared tree.
  flake.homeModules.agents = {
    pkgs,
    config,
    customLib,
    # The NixOS config this home-manager user runs on (null only for
    # standalone home-manager evals, which never happens here). Used to
    # identify the machine for the global AGENTS.md machine context below.
    osConfig,
    ...
  }: let
    cfg = config.homeSpec.agents;
    oc = cfg.opencode;
    headroomCfg = config.homeSpec.programs.headroom;
    headroomEnabled = config.homeSpec.programs.headroom.enable or false;
    headroomProxyUrl = "http://${headroomCfg.proxy.host}:${toString headroomCfg.proxy.port}/v1";
    inherit (customLib) relativeToRoot;

    # ---- Shared skills tree (homeSpec.agents.skills) ---- #
    # inputs.agents.lib.mkSkills merges the repo's skills/ tree with
    # external flake-input skill sources into one derivation (a
    # linkFarm of per-skill symlinks), reused as the skills dir of
    # every enabled agent below. Custom skills override external ones
    # on name collision; among externals, earlier entries win. External
    # sources (fleet-wide: append to externalSkills here, per machine:
    # homeSpec.agents.skills.extraSources) look like:
    #   {src = inputs.skills-anthropic;}   # all skills under skills/
    #   {src = inputs.skills-davidondrej; skillsDir = "skills/agent-orchestration"; selectSkills = ["git-worktree" "handoff"];}
    # (davidondrej/skills nests skills/<category>/<name>, so each wanted
    # category gets its own entry with a deeper skillsDir; unknown
    # selectSkills names are silently dropped — verify the installed set
    # with ls ~/.config/opencode/skills). The sandbox OCI image bakes
    # the same tree at /opt/skills (flake-parts/ociImages/code-agent.nix)
    # — keep its externalSkills list in sync when adding sources here.
    skillsDir = inputs.agents.lib.mkSkills {
      inherit pkgs;
      customSkills = relativeToRoot "skills";
      externalSkills = cfg.skills.extraSources;
    };

    # ---- opencode bindings (only meaningful when opencode is on) ---- #
    # PAT file used by the wrapper: explicit githubPatFile override or the
    # canonical sops-nix deployment path of the shared "github-mcp" clan var
    # (declared by nixosModules/github-mcp for pat-mode users).
    githubMcpPatFile =
      if oc.mcp.github.patFile == null
      then "/run/secrets/vars/shared/github-mcp/pat"
      else oc.mcp.github.patFile;
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

    # ---- Machine context (global AGENTS.md system-prompt header) ---- #
    # Home-manager runs as a NixOS module here, so osConfig carries the
    # machine this user is on. From it, the machine's nixos-facter report
    # (machines/<host>/facter.json) is read at eval time and summarized
    # into ~/.config/opencode/AGENTS.md — opencode v2's global AGENTS.md
    # discovery spot, loaded into the system prompt of every session (a
    # project's own AGENTS.md still auto-loads on top of it). The
    # settings.instructions array is NOT a viable wiring: opencode v2
    # decodes it but never resolves its entries (see
    # services/www/src/docs/content/instructions.mdx at the pinned
    # opencode rev).
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
    # A synthetic report (machineContext.facterReport, set by VM tests)
    # overrides the on-disk read; the accessors below work identically on
    # either shape.
    facterReport =
      if oc.machineContext.facterReport != null
      then oc.machineContext.facterReport
      else if hasFacter
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
    # Environment annotation (plain line right after the Machine line):
    # the explicit option wins — NixOS has no eval-time "this is a VM"
    # marker (nixpkgs' kubevirt.nix / qemu-vm.nix set none), so VM images
    # set it (e.g. the KubeVirt agent). Otherwise NixOS containers are
    # detected via boot.isContainer (a real eval-time signal). Bare metal
    # emits no line (token-lean).
    machineContextEnvironment =
      if oc.machineContext.environment != null
      then "Environment: ${oc.machineContext.environment}"
      else if (osConfig != null && (osConfig.boot.isContainer or false))
      then "Environment: nixos-container"
      else null;
    # Plain, matter-of-fact and token-lean machine descriptor (no markdown
    # decoration) — written to the global AGENTS.md loaded into the system
    # prompt of every opencode session on this machine: what the machine
    # is, where it runs, what hardware it has and where the facts about it
    # live. The read-only rule and the AGENTS.md rule apply on every
    # machine; the hardware and facts paths only when a facter report
    # exists (installer ISO, KubeVirt agent VMs have none). The repo's
    # skills (incl. nix-style, the user's Nix-writing preferences) are
    # advertised by opencode itself from ~/.config/opencode/skills.
    machineContextLines =
      (
        ["Machine: ${hostName} (NixOS ${pkgs.stdenv.hostPlatform.system})"]
        ++ lib.optionals (machineContextEnvironment != null) [machineContextEnvironment]
        ++ [""]
      )
      ++ lib.optionals (machineContextHardware != [])
      (["Hardware:"] ++ machineContextHardware ++ [""])
      ++ [
        "Repo: github.com/${oc.machineContext.repoOwner}/${oc.machineContext.repoName} (local: ${config.home.homeDirectory}/${oc.machineContext.repoPath})"
      ]
      ++ lib.optionals hasFacter [
        "Machine facts: machines/${hostName}/facter.json, disko.nix, configuration.nix"
      ]
      ++ [
        "Machine config is strictly read-only: changes only by repo owner ${oc.machineContext.repoOwner}, or when instructed to while working in the home repo."
        ""
        "Read a repo's AGENTS.md before working in it."
      ]
      ++ lib.optionals (oc.machineContext.extraText != null)
      ([""]
        ++ lib.filter (line: line != "")
        (lib.splitString "\n" oc.machineContext.extraText));
  in {
    options.homeSpec.agents = {
      # ---- Shared skills: homeSpec.agents.skills.* ---- #
      skills = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default =
            oc.enabled
            || cfg.kimi.enabled
            || cfg.pi.enabled
            || cfg.claude.enabled;
          description = ''
            Build the shared skills tree (the repo's skills/ directory
            merged with external skill sources via inputs.agents.lib.mkSkills)
            and wire it into every enabled agent's skills dir. Defaults to
            true when at least one agent is enabled.
          '';
        };
        extraSources = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          example = lib.literalExpression "[{src = inputs.skills-anthropic;}]";
          description = ''
            External skill sources appended to the mkSkills externalSkills
            list — e.g. {src = inputs.skills-anthropic;}, optionally with
            skillsDir and selectSkills for cherry-picking. Add the source
            repo as a flake input first. Custom skills (skills/) override
            external ones on name collision; among externals, earlier
            entries win.
          '';
        };
      };

      # ---- pi: homeSpec.agents.pi.* ---- #
      pi = {
        enabled = lib.mkEnableOption "the pi coding agent (badlogic/pi-mono)";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.pi-coding-agent;
          defaultText = lib.literalExpression "pkgs.pi-coding-agent";
          description = "The pi package to install.";
        };
      };

      # ---- kimi-code: homeSpec.agents.kimi.* ---- #
      kimi = {
        enabled = lib.mkEnableOption "the Kimi Code CLI (MoonshotAI)";
        # Package comes from numtide/llm-agents.nix via overlays/default.nix
        # (from-source pnpm build, binary `kimi`, auto-update disabled by the
        # wrapper). Overridable so a caller can pin another build.
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.kimi-code;
          defaultText = lib.literalExpression "pkgs.kimi-code";
          description = "The kimi-code package to install.";
        };
      };

      # ---- claude-code: homeSpec.agents.claude.* ---- #
      claude = {
        enabled = lib.mkEnableOption "the Claude Code CLI (Anthropic)";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.claude-code;
          defaultText = lib.literalExpression "pkgs.claude-code";
          description = "The claude-code package to install.";
        };
      };

      # ---- opencode: homeSpec.agents.opencode.* ---- #
      opencode = {
        enabled = lib.mkEnableOption "default opencode configuration";
        # Per-machine system-prompt context (machineContext.*): generates
        # the global ~/.config/opencode/AGENTS.md with the hostname, an
        # optional environment annotation, hardware facts from the machine's
        # facter.json and pointers to where machine facts live. opencode v2
        # loads this file into every session's system prompt (the
        # settings.instructions array is not resolved in v2 — see the
        # machine-context comment above).
        machineContext = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate the global ~/.config/opencode/AGENTS.md machine context (hostname + environment + hardware facts from machines/<hostname>/facter.json).";
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
          environment = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              Host-environment annotation written after the Machine line (e.g. "vm (KubeVirt guest)").
              NixOS has no eval-time "this is a VM" marker, so VM images set this explicitly; NixOS
              containers are auto-detected (boot.isContainer); bare metal stays null (no line).
            '';
          };
          facterReport = lib.mkOption {
            type = with lib.types; nullOr attrs;
            default = null;
            description = ''
              Synthetic nixos-facter report overriding the machines/<hostname>/facter.json read
              (VM tests: the test hostname has no real report). Null reads the real file.
            '';
          };
        };
        # ---- MCP servers: homeSpec.agents.opencode.mcp.<name>.enable ---- #
        mcp = {
          # mcp-nixos: NixOS / Home Manager / nix-darwin package & option
          # search (local stdio, flake package).
          nix.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the mcp-nixos MCP server in opencode settings.";
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

          # (https://docs.mcp.varlock.dev/mcp, public, no auth). Off by
          # default, enabled via the netsa tag profile.
          varlock-docs.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the Varlock docs MCP server (search varlock.dev documentation) in opencode settings.";
          };
        };
      };
    };

    config = lib.mkMerge [
      # ---- pi ---- #
      (lib.mkIf cfg.pi.enabled {
        home.packages = [cfg.pi.package];
        # Agent Skills standard location (~/.agents/skills), scanned by pi.
        home.file = lib.mkIf cfg.skills.enabled {
          ".agents/skills".source = skillsDir;
        };
      })

      # ---- kimi-code ---- #
      (lib.mkIf cfg.kimi.enabled {
        home.packages = [cfg.kimi.package];
        # $KIMI_CODE_HOME/skills — the directory kimi-code scans.
        home.file = lib.mkIf cfg.skills.enabled {
          ".kimi-code/skills".source = skillsDir;
        };
      })

      # ---- claude-code ---- #
      (lib.mkIf cfg.claude.enabled {
        home.packages = [cfg.claude.package];
        # ~/.claude/skills — claude-code's personal skills dir.
        home.file = lib.mkIf cfg.skills.enabled {
          ".claude/skills".source = skillsDir;
        };
      })

      # ---- opencode ---- #
      (lib.mkIf oc.enabled {
        xdg.configFile = {
          # Global machine context (built above from osConfig + the machine's
          # facter report): written to opencode's global AGENTS.md discovery
          # spot. opencode v2 loads ~/.config/opencode/AGENTS.md into every
          # session's system prompt (a project's own AGENTS.md still
          # auto-loads on top). The settings.instructions array is decoded
          # but never resolved in v2 (see
          # services/www/src/docs/content/instructions.mdx at the pinned
          # opencode rev), so file instructions ride AGENTS.md.
          "opencode/AGENTS.md" = lib.mkIf (oc.machineContext.enable && hostName != "") {
            text = lib.concatStringsSep "\n" machineContextLines + "\n";
          };

          # Skills: repo-local custom skills + external skill sources, merged
          # into ~/.config/opencode/skills by inputs.agents.lib.mkSkills (see
          # the shared skillsDir above; customLib reaches home modules via
          # home-manager.extraSpecialArgs, set once in nixosModules/default).
          "opencode/skills" = lib.mkIf cfg.skills.enabled {
            source = skillsDir;
          };
        };

        assertions = [
          {
            assertion = oc.mcp.github.auth == "oauth" -> oc.mcp.github.patFile == null;
            message = "opencode: mcp.github.patFile is only valid with mcp.github.auth = \"pat\" — the oauth and pat methods are mutually exclusive.";
          }
        ];
        programs.opencode = {
          enable = true;
          # nixpkgs' opencode v2 package.
          package = pkgs.opencode;
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
            }
            (lib.mkIf oc.mcp.nix.enable {
              mcp.servers.nixos = {
                type = "local";
                command = ["${lib.getExe inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos}"];
              };
            })

            (lib.mkIf oc.mcp.github.enable {
              mcp.servers.github =
                if oc.mcp.github.auth == "pat"
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
            (lib.mkIf oc.mcp.artifacthub.enable {
              # ArtifactHub, local stdio server — hermetic nix build from the
              # pinned v1.1.1 source (packages/artifacthub-mcp.nix); no
              # docker/npx runtime downloads.
              mcp.servers.artifacthub = {
                type = "local";
                command = ["${lib.getExe pkgs.artifacthub-mcp}"];
              };
            })
            (lib.mkIf oc.mcp.kubernetes.enable {
              # Kubernetes MCP server (containers/kubernetes-mcp-server):
              # hermetic Go build, stdio is the default transport (no
              # --stdio flag). Uses the user's kubeconfig; optional
              # --read-only restricts to readOnlyHint tools.
              mcp.servers.kubernetes = {
                type = "local";
                command =
                  ["${lib.getExe pkgs.kubernetes-mcp-server}"]
                  ++ lib.optional oc.mcp.kubernetes.readOnly "--read-only";
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
            # Varlock docs: hosted docs-search server
            # (https://docs.mcp.varlock.dev/mcp) — public, no auth.
            (lib.mkIf oc.mcp.varlock-docs.enable {
              mcp.servers.varlock-docs = {
                type = "remote";
                url = "https://docs.mcp.varlock.dev/mcp";
              };
            })
          ];
        };
      })
    ];
  };
}
