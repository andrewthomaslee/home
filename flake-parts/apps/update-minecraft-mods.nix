{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps.update-minecraft-mods = {
      type = "app";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "update-minecraft-mods";
        runtimeInputs = with pkgs; [
          python3
          coreutils
        ];
        text = ''
          python3 - << 'PYEOF'
          import re

          with open("flake.nix", "r") as f:
              content = f.read()

          pattern = re.compile(r"([A-Za-z0-9-]+)\s*=\s*\{[^}]*?url\s*=\s*\"([^\"]+)\";", re.DOTALL)
          urls = dict(pattern.findall(content))

          filepath = "documentation/docs/minecraft/mc-andrewlee-fun.md"

          with open(filepath, "r") as f:
              md_content = f.read()

          lines = md_content.split("\n")
          updated = False
          for i, line in enumerate(lines):
              match = re.match(r"^\s*\|\s*\[([^\]]+)\].*?\[Download\]\([^)]+\)", line)
              if match:
                  mod_name = match.group(1)
                  if mod_name in urls:
                      new_url = urls[mod_name]
                      new_line = re.sub(r"\[Download\]\([^)]+\)", f"[Download]({new_url})", line)
                      if new_line != line:
                          lines[i] = new_line
                          updated = True
                          print(f"Updated {mod_name} to {new_url}")

          if updated:
              with open(filepath, "w") as f:
                  f.write("\n".join(lines))
              print(f"Successfully updated {filepath}")
          else:
              print(f"No mod links needed updating in {filepath}")
          PYEOF
        '';
      });
    };
  };
}
