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
    ...
  }: let
    cfg = config.homeSpec.programs.opencode;
    headroomCfg = config.homeSpec.programs.headroom;
    headroomEnabled = config.homeSpec.programs.headroom.enable or false;
    headroomProxyUrl = "http://${headroomCfg.proxy.host}:${toString headroomCfg.proxy.port}/v1";
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
      # Enable the mcp-nixos MCP server (NixOS / Home Manager / nix-darwin
      # package & option search) in opencode settings.
      enableNixMcp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the mcp-nixos MCP server in opencode settings.";
      };
      # Enable the OpenRouter remote MCP server (live model catalog,
      # pricing, credits, benchmarks, docs search). Nothing is installed
      # locally: OpenRouter hosts it and opencode runs the OAuth flow on
      # first use.
      enableOpenrouterMcp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the OpenRouter remote MCP server in opencode settings.";
      };
      # Enable the Playwright MCP server (browser automation via
      # accessibility snapshots) using the hermetic nixpkgs playwright-mcp
      # package: browsers are pinned in the store (PLAYWRIGHT_BROWSERS_PATH
      # is set by the wrapper), so no npx/docker/uvx runtime downloads.
      enablePlaywrightMcp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the Playwright MCP server (nixpkgs playwright-mcp) in opencode settings.";
      };
    };
    config = lib.mkIf cfg.enable {
      # add skills to config
      xdg.configFile."opencode/skills".source = inputs.agents.lib.mkSkills {
        inherit pkgs;
        customSkills = "${inputs.skills-anthropic}/skills";
        externalSkills = [
          # Include all skills from anthropics/skills
          # {src = inputs.skills-anthropic;}
          # Or cherry-pick specific skills:
          # { src = inputs.skills-anthropic; selectSkills = [ "mcp-builder" ]; }
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
        ]))
        ++ (lib.optionals cfg.enablePlaywrightMcp [
          pkgs.playwright-mcp
        ]);
      programs.opencode = {
        enable = true;
        package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
        extraPackages =
          (with pkgs.unstable; [
            actionlint
            uv
            nix
            pyrefly
            nil
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
          ]))
          ++ (lib.optionals cfg.enablePlaywrightMcp [
            pkgs.playwright-mcp
          ]);
        tui.theme = "tokyonight";
        settings = lib.mkMerge [
          {
            model = "z-ai/glm-5.3-flash";
            small_model = "z-ai/glm-5.3-flash";
            compaction = {
              auto = true;
              tail_turns = 32;
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
              nix = {
                command = ["nil"];
                extensions = [".nix"];
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
          (lib.mkIf cfg.enableNixMcp {
            mcp = {
              nixos = {
                type = "local";
                command = ["${lib.getExe inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos}"];
                enabled = true;
              };
            };
          })
          (lib.mkIf cfg.enableOpenrouterMcp {
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
          (lib.mkIf cfg.enablePlaywrightMcp {
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
          (lib.mkIf headroomEnabled {
            mcp = {
              headroom = {
                type = "local";
                command = ["${lib.getExe headroomCfg.package}" "mcp" "serve"];
                enabled = true;
              };
            };
            plugin = [
              "${headroomCfg.package}/${pkgs.unstable.python313.sitePackages}/headroom/providers/opencode/_dist/entry.opencode.js"
            ];
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
        ];
      };
    };
  };
}
