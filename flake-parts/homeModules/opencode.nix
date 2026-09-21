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
      exec ${inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode}/bin/opencode "$@"
    '';
    # Hermetic plugin packages (flake-parts/packages/opencode-plugins.nix).
    pluginEntries =
      lib.optional headroomEnabled "${headroomCfg.package}/${pkgs.unstable.python313.sitePackages}/headroom/providers/opencode/_dist/entry.opencode.js"
      ++ lib.optional cfg.plugins.cc-safety-net.enable "${pkgs.cc-safety-net}/share/opencode-plugins/cc-safety-net/dist/index.js"
      ++ lib.optional cfg.plugins.morph-fast-apply.enable "${pkgs.opencode-morph-fast-apply}/share/opencode-plugins/opencode-morph-fast-apply/index.ts"
      ++ lib.optional cfg.plugins.opencode-mem.enable "${pkgs.opencode-mem}/share/opencode-plugins/opencode-mem/dist/plugin.js"
      ++ lib.optional cfg.plugins.devcontainers.enable "${pkgs.opencode-devcontainers}/share/opencode-plugins/opencode-devcontainers/plugin/index.js";
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
        # TypeUI: hosted design-skills MCP for AI-first UI work
        # (https://mcp.typeui.sh/mcp, OAuth on first use). Off by default,
        # enabled for the dev profile.
        typeui.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the TypeUI remote MCP server (design systems and UI prompts) in opencode settings.";
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
        # opencode-devcontainers: isolated branch workspaces via
        # devcontainers or git worktrees (/devcontainer, /worktree,
        # /workspaces commands). Needs the devcontainer CLI (fullDevTools)
        # and docker/podman at runtime.
        devcontainers.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the opencode-devcontainers plugin (branch workspace isolation).";
        };
      };
    };
    config = lib.mkIf cfg.enable {
      # Morph Fast Apply: ship the packaged always-on routing instruction
      # so agents reliably pick morph_edit over native edit.
      xdg.configFile."opencode/instructions/morph-tools.md" = lib.mkIf cfg.plugins.morph-fast-apply.enable {
        source = "${pkgs.opencode-morph-fast-apply}/share/opencode-plugins/opencode-morph-fast-apply/instructions/morph-tools.md";
      };

      # Skills: repo-local custom skills + external skill sources, merged
      # into ~/.config/opencode/skills by inputs.agents.lib.mkSkills (a
      # linkFarm of per-skill symlinks). Custom skills override externals
      # on name collision; among externals, earlier entries in the list
      # win. customLib (and thus relativeToRoot) reaches home modules via
      # home-manager.extraSpecialArgs, set once in nixosModules/default.
      xdg.configFile."opencode/skills".source = inputs.agents.lib.mkSkills {
        inherit pkgs;
        customSkills = relativeToRoot "skills";
        externalSkills = [
          # Claude skills from anthropics/skills (all skills under skills/)
          {src = inputs.skills-anthropic;}
          # Payload CMS skills (payload, cms-migration)
          {src = inputs.skills-payloadcms;}
        ];
      };

      home.packages =
        (lib.optionals cfg.enableDesktop
          (with inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}; [
            opencode-desktop
          ]))
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
        ++ (lib.optionals (cfg.mcp.github.enable && cfg.mcp.github.auth == "pat") [
          githubMcpWrapper
        ])
        # Plugin packages: referenced by store path in settings.plugin, so
        # keep them in the closure (GC safety).
        ++ (lib.optional cfg.plugins.cc-safety-net.enable pkgs.cc-safety-net)
        ++ (lib.optional cfg.plugins.morph-fast-apply.enable pkgs.opencode-morph-fast-apply)
        ++ (lib.optional cfg.plugins.opencode-mem.enable pkgs.opencode-mem)
        ++ (lib.optional cfg.plugins.devcontainers.enable pkgs.opencode-devcontainers);
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
        # with a configured key file; otherwise the stock package.
        package =
          if morphEnabledWithKey
          then opencodeMorphWrapper
          else inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
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
          ]);
        tui.theme = "tokyonight";
        settings = lib.mkMerge [
          {
            model = "glm-5.3-flash";
            small_model = "glm-5.3-flash";
            compaction = {
              auto = true;
              tail_turns = 12;
            };
            permission = {
              read = {
                "/nix/store/**" = "allow";
                "/tmp/**" = "allow";
              };
              external_directory = {
                "/nix/store/**" = "allow";
                "/tmp/**" = "allow";
              };
            };
            lsp = {
              python = {
                command = ["pyrefly" "lsp"];
                extensions = [".py" ".pyi"];
              };
              # Built-in pyright would try a runtime npm auto-download of
              # pyright-langserver (non-hermetic on NixOS) and duplicate the
              # .py/.pyi LSP already provided by pyrefly.
              pyright.disabled = true;
              # nixd replaces the previous `nil` entry. The settings key must
              # be "nixd" (opencode's built-in nixd LSP) so this entry
              # overrides the built-in instead of running two Nix servers.
              # opencode spawns LSP servers with cwd = project root, so
              # `toString ./.` anchors to the repo opencode was opened in:
              # foreign flakes (e.g. borg) get their own nixpkgs. In non-flake
              # dirs the eval fails; nixd logs it and keeps its startup
              # default `import <nixpkgs> { }` resolved via NIX_PATH.
              # Exact per-repo option trees are supplied by each repo's
              # opencode.json.
              nixd = {
                command = ["nixd"];
                extensions = [".nix"];
                env.NIX_PATH = "nixpkgs=${inputs.nixpkgs}";
                initialization.nixd.nixpkgs.expr = ''
                  import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }'';
              };
              # helm-ls: charts/templates diagnostics; it launches the
              # installed yaml-language-server itself for non-template YAML
              # (no separate `yaml` LSP entry — would double diagnostics).
              helm_ls = {
                command = ["helm_ls" "serve"];
                extensions = [".yaml" ".yml"];
              };
              gleam = {
                command = ["gleam" "lsp"];
                extensions = [".gleam"];
              };
            };
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
            mcp = {
              nixos = {
                type = "local";
                command = ["${lib.getExe inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos}"];
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.openrouter.enable {
            mcp = {
              openrouter = {
                # Remote hosted server: no local install, no docker/uvx.
                # opencode handles the OAuth login automatically on first
                # tool use (minted key expires after 7 days).
                type = "remote";
                url = "https://mcp.openrouter.ai/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.playwright.enable {
            mcp = {
              playwright = {
                # Hermetic local server: the nixpkgs wrapper pins the
                # browser bundle (playwright-driver.browsers) and the
                # playwright node modules, so nothing is downloaded at
                # runtime. --headless so it works on displayless agents;
                # chromium is the nixpkgs default browser.
                type = "local";
                command = ["${lib.getExe pkgs.playwright-mcp}" "--headless"];
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.github.enable {
            mcp = {
              github =
                if cfg.mcp.github.auth == "pat"
                then {
                  # Local stdio server with PAT auth: the wrapper reads the
                  # clan-var-deployed PAT file and exports
                  # GITHUB_PERSONAL_ACCESS_TOKEN at server start.
                  type = "local";
                  command = ["${githubMcpWrapper}/bin/github-mcp-server-opencode"];
                  enabled = true;
                }
                else {
                  # Remote hosted server: no local install, no PAT file.
                  # opencode handles the browser OAuth flow automatically on
                  # first tool use.
                  type = "remote";
                  url = "https://api.githubcopilot.com/mcp/";
                  enabled = true;
                };
            };
          })
          # Cloudflare remote MCP servers: hosted by Cloudflare, no local
          # install. opencode handles the Cloudflare OAuth flow on first
          # tool use (the docs server is public).
          (lib.mkIf cfg.mcp.cloudflare.enable {
            mcp = {
              cloudflare = {
                type = "remote";
                url = "https://mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-docs.enable {
            mcp = {
              cloudflare-docs = {
                type = "remote";
                url = "https://docs.mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-bindings.enable {
            mcp = {
              cloudflare-bindings = {
                type = "remote";
                url = "https://bindings.mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-builds.enable {
            mcp = {
              cloudflare-builds = {
                type = "remote";
                url = "https://builds.mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-browser.enable {
            mcp = {
              cloudflare-browser = {
                type = "remote";
                url = "https://browser.mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.cloudflare-containers.enable {
            mcp = {
              cloudflare-containers = {
                type = "remote";
                url = "https://containers.mcp.cloudflare.com/mcp";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.mdn.enable {
            mcp = {
              # MDN Web Docs, hosted by Mozilla — no local install.
              mdn = {
                type = "remote";
                url = "https://mcp.mdn.mozilla.net/";
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.artifacthub.enable {
            mcp = {
              # ArtifactHub, local stdio server — hermetic nix build from the
              # pinned v1.1.1 source (packages/artifacthub-mcp.nix); no
              # docker/npx runtime downloads.
              artifacthub = {
                type = "local";
                command = ["${lib.getExe pkgs.artifacthub-mcp}"];
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.mcp.kubernetes.enable {
            mcp = {
              # Kubernetes MCP server (containers/kubernetes-mcp-server):
              # hermetic Go build, stdio is the default transport (no
              # --stdio flag). Uses the user's kubeconfig; optional
              # --read-only restricts to readOnlyHint tools.
              kubernetes = {
                type = "local";
                command =
                  ["${lib.getExe pkgs.kubernetes-mcp-server}"]
                  ++ lib.optional cfg.mcp.kubernetes.readOnly "--read-only";
                enabled = true;
              };
            };
          })
          (lib.mkIf headroomEnabled {
            mcp = {
              headroom = {
                type = "local";
                command = ["${lib.getExe headroomCfg.package}" "mcp" "serve"];
                enabled = true;
              };
            };
            provider = {
              deepseek = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
              anthropic = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
              openai = {
                options = {
                  baseURL = headroomProxyUrl;
                };
              };
            };
          })
          # Morph Fast Apply: point the agent at the always-on instruction
          # (packaged file synced to the xdg path above).
          (lib.mkIf cfg.plugins.morph-fast-apply.enable {
            instructions = ["~/.config/opencode/instructions/morph-tools.md"];
          })
          # TypeUI: hosted design-skills MCP (OAuth on first use).
          (lib.mkIf cfg.mcp.typeui.enable {
            mcp = {
              typeui = {
                type = "remote";
                url = "https://mcp.typeui.sh/mcp";
                enabled = true;
              };
            };
          })
          # Plugin entries: single definition so mkMerge never sees two
          # conflicting `plugin` lists. Each entry is an absolute store
          # path (the headroom pattern), so nothing is fetched from npm at
          # runtime; the packages are kept alive via home.packages.
          (lib.mkIf (pluginEntries != []) {
            plugin = pluginEntries;
          })
        ];
      };
    };
  };
}
