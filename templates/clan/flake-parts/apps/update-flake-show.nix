{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps.update-flake-show = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "update-flake-show";
        runtimeInputs = with pkgs; [
          python3
          nix
          gnugrep
          gnused
          coreutils
        ];
        text = ''
          # Generate the clean flake outputs
          nix flake show --no-update-lock-file 2>&1 | grep -v "evaluating" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" > flake_outputs_clean.txt
          sed -i '1s/.*//' flake_outputs_clean.txt && sed -i '1d' flake_outputs_clean.txt

          python3 - << 'PYEOF'
          import re

          def update_file(filepath):
              with open(filepath, 'r') as f:
                  content = f.read()

              with open('flake_outputs_clean.txt', 'r') as f:
                  flake_outputs = f.read().rstrip()

              new_outputs_block = f"```console\n$ nix flake show\n{flake_outputs}\n```"

              pattern = re.compile(r"```console\n\$ nix flake show\n.*?```", re.DOTALL)

              if pattern.search(content):
                  new_content = pattern.sub(new_outputs_block, content)
                  with open(filepath, 'w') as f:
                      f.write(new_content)
                  print(f"Updated {filepath}")
              else:
                  print(f"Could not find pattern in {filepath}")

          update_file('README.md')
          update_file('documentation/docs/index.md')
          PYEOF

          rm flake_outputs_clean.txt
        '';
      });
    };
  };
}
