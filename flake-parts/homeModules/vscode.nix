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
        package = pkgs.vscodium;
        mutableExtensionsDir = true;
        profiles = {
          default = {
            extensions = with pkgs.vscode-extensions; [
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
            ];
            userSettings = {
              "security.workspace.trust.untrustedFiles" = "open";
              "terminal.integrated.defaultProfile.linux" = "bash";
              "workbench.sideBar.location" = "right";
              "workbench.colorTheme" = "Red";
              "workbench.iconTheme" = "catppuccin-macchiato";
              "redhat.telemetry.enabled" = false;
              "workbench.startupEditor" = "none";
              "editor.minimap.renderCharacters" = false;
              "editor.minimap.size" = "fill";
              "editor.minimap.enabled" = false;
              "explorer.confirmDragAndDrop" = false;
              "git.autofetch" = true;
              "explorer.confirmDelete" = false;
              "explorer.confirmPasteNative" = false;
              "python.createEnvironment.trigger" = "off";
              "python.defaultInterpreterPath" = "";
              "tailwindCSS.classAttributes" = [
                "class"
                "className"
                "ngClass"
                "class:list"
                "_klass"
                "klass"
                "_style"
                "style"
              ];
              "tailwindCSS.includeLanguages" = {
                python = "html";
              };
              "git.enableSmartCommit" = true;
              "git.confirmSync" = false;
              "python.experiments.enabled" = false;
              "[jsonc]" = {
                "editor.defaultFormatter" = "esbenp.prettier-vscode";
              };
              "python.languageServer" = "Default";
              "ruff.configurationPreference" = "filesystemFirst";
              "supermaven.enable" = {
                "*" = true;
              };
              "sqltools.useNodeRuntime" = true;
              "tailwind-fold.autoFold" = false;
              "[python]" = {
                "editor.formatOnSave" = true;
                "editor.defaultFormatter" = "charliermarsh.ruff";
              };
              "yaml.schemaStore.url" = "https://raw.githubusercontent.com/weaveworks/eksctl/main/pkg/apis/eksctl.io/v1alpha5/assets/schema.json";
              "[dockercompose]" = {
                "editor.insertSpaces" = true;
                "editor.tabSize" = 2;
                "editor.autoIndent" = "advanced";
                "editor.defaultFormatter" = "redhat.vscode-yaml";
              };
              "[github-actions-workflow]" = {
                "editor.defaultFormatter" = "redhat.vscode-yaml";
              };
              "workbench.secondarySideBar.defaultVisibility" = "hidden";
              "vs-kubernetes" = {
                "vs-kubernetes.crd-code-completion" = "enabled";
              };
              "terminal.integrated.enableMultiLinePasteWarning" = "never";
              "[nix]" = {
                "editor.defaultFormatter" = "kamadorueda.alejandra";
                "editor.formatOnPaste" = false;
                "editor.formatOnSave" = true;
                "editor.formatOnType" = false;
              };
              "alejandra.program" = "alejandra";
              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nil";
              "nix.formatterPath" = "alejandra";
              "nix.serverSettings" = {
                nil = {
                  formatting = {
                    command = ["alejandra"];
                  };
                  nix = {
                    maxMemoryMB = 4096;
                    flake = {
                      autoArchive = true;
                      autoEvalInputs = true;
                    };
                  };
                };
              };
              "roo-cline.allowedCommands" = [
                "git log"
                "git diff"
                "git show"
                "nix flake check --all-systems --show-trace"
                "nix eval"
                "nix flake show"
                "nix build"
                "nix flake check"
              ];
              "terminal.integrated.initialHint" = false;
              "roo-cline.debug" = false;
              "roo-cline.deniedCommands" = [];
            };
          };
        };
      };
      home.packages = with pkgs; [
        pyrefly
        ruff
        helm-ls
        terraform-ls
        kubectl
        alejandra
        devcontainer
        devpod
      ];

      programs.bash = {
        shellAliases = {
          c = "codium .";
          cvscode = "codium /home/netsa/nixos/home-manager/modules/vscode/settings.json";
          cknownhosts = "codium ~/.ssh/known_hosts";
        };
      };
    };
  };
}
