{
  # inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.vscode = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.vscode;
  in {
    options.homeSpec.programs.vscode.enable = lib.mkEnableOption "default vscode configuration";
    config = lib.mkIf (cfg.enable && config.home.username != "root") {
      # VSCode
      programs.vscode = {
        enable = true;
        package = pkgs.unstable.vscodium;
        mutableExtensionsDir = true;
        profiles = {
          default = {
            extensions = with pkgs.unstable.vscode-extensions; [
              kamadorueda.alejandra
              jnoortheen.nix-ide
              supermaven.supermaven
              bradlc.vscode-tailwindcss
              redhat.vscode-yaml
              redhat.vscode-xml
              charliermarsh.ruff
              ms-python.python
              tamasfe.even-better-toml
              esbenp.prettier-vscode
              ecmel.vscode-html-css
              catppuccin.catppuccin-vsc-icons
              rooveterinaryinc.roo-cline
              irongeek.vscode-env
              hashicorp.terraform
              budparr.language-hugo-vscode
              gruntfuggly.todo-tree
              ms-azuretools.vscode-docker
              github.vscode-github-actions
              github.vscode-pull-request-github
              github.codespaces
            ];
            userSettings = {
              security.workspace.trust.untrustedFiles = "open";
              terminal.integrated = {
                defaultProfile.linux = "bash";
                enableMultiLinePasteWarning = "never";
                initialHint = false;
              };
              workbench = {
                sideBar.location = "right";
                colorTheme = "Red";
                iconTheme = "catppuccin-macchiato";
                startupEditor = "none";
                secondarySideBar.defaultVisibility = "hidden";
              };
              redhat.telemetry.enabled = false;
              editor.minimap = {
                renderCharacters = false;
                size = "fill";
                enabled = false;
              };
              explorer = {
                confirmDragAndDrop = false;
                confirmDelete = false;
                confirmPasteNative = false;
              };
              git = {
                autofetch = true;
                enableSmartCommit = true;
                confirmSync = false;
              };
              python = {
                createEnvironment.trigger = "off";
                defaultInterpreterPath = "";
                experiments.enabled = false;
                languageServer = "Default";
              };
              tailwindCSS = {
                classAttributes = [
                  "class"
                  "className"
                  "ngClass"
                  "class:list"
                  "_klass"
                  "klass"
                  "_style"
                  "style"
                ];
                includeLanguages.python = "html";
              };
              "[jsonc]".editor.defaultFormatter = "esbenp.prettier-vscode";
              ruff.configurationPreference = "filesystemFirst";
              supermaven.enable."*" = true;
              sqltools.useNodeRuntime = true;
              tailwind-fold.autoFold = false;
              "[python]" = {
                editor.formatOnSave = true;
                editor.defaultFormatter = "charliermarsh.ruff";
              };
              "[dockercompose]".editor = {
                insertSpaces = true;
                tabSize = 2;
                autoIndent = "advanced";
                defaultFormatter = "redhat.vscode-yaml";
              };
              "[github-actions-workflow]".editor.defaultFormatter = "redhat.vscode-yaml";
              vs-kubernetes.vs-kubernetes.crd-code-completion = "enabled";
              "[nix]".editor = {
                defaultFormatter = "kamadorueda.alejandra";
                formatOnPaste = false;
                formatOnSave = true;
                formatOnType = false;
              };
              alejandra.program = "alejandra";
              yaml = {
                schemaStore.url = "https://raw.githubusercontent.com/weaveworks/eksctl/main/pkg/apis/eksctl.io/v1alpha5/assets/schema.json";
                schemas = {
                  "https://squidfunk.github.io/mkdocs-material/schema.json" = "mkdocs.yml";
                };
                customTags = [
                  "!ENV scalar"
                  "!ENV sequence"
                  "!relative scalar"
                ];
              };
              nix = {
                enableLanguageServer = true;
                serverPath = "nil";
                formatterPath = "alejandra";
                serverSettings.nil = {
                  formatting.command = ["alejandra"];
                  nix = {
                    maxMemoryMB = 6144;
                    flake = {
                      autoArchive = true;
                      autoEvalInputs = true;
                    };
                  };
                };
              };
              roo-cline = {
                debug = false;
                allowedCommands = [
                  "git log"
                  "git diff"
                  "git show"
                  "nix flake check --all-systems --show-trace"
                  "nix eval"
                  "nix flake show"
                  "nix build"
                  "nix flake check"
                  "clan show"
                ];
                deniedCommands = [
                  "nix run"
                  "nixos-rebuild"
                ];
              };
            };
          };
        };
      };
      # Home-manager Packages
      home.packages = with pkgs.unstable; [
        pyrefly
        ruff
        helm-ls
        terraform-ls
        kubectl
        alejandra
        devcontainer
        devpod
      ];

      programs.bash.shellAliases = {
        c = "codium .";
        cknownhosts = "codium ~/.ssh/known_hosts";
      };
    };
  };
}
