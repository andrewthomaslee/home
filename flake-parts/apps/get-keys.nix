{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    inputs',
    ...
  }: let
    get-keys-pkg = pkgs.writeShellApplication {
      name = "get-keys";
      runtimeInputs = with pkgs; [
        inputs'.clan-core.packages.clan-cli
        python3
      ];
      text = ''
        python3 - << 'PYEOF'
        import subprocess
        import json


        def get_clan_output(cmd):
            """Run a command and filter out warning lines from stdout."""
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            # Filter out warnings and empty lines
            return [
                line.strip()
                for line in res.stdout.splitlines()
                if line.strip() and not line.startswith("warning:")
            ]


        def main():
            try:
                # Get list of all machines
                machines = get_clan_output(["clan", "machines", "list"])

                keys = {}
                for m in machines:
                    # Extract the age key for each machine
                    key_lines = get_clan_output(["clan", "secrets", "get", f"{m}-age.key"])
                    keys[m] = "\n".join(key_lines)

                # Output JSON format suitable for Terraform external data source
                print(json.dumps(keys))
            except subprocess.CalledProcessError as e:
                # Pass errors to stderr
                print(f"Error executing clan CLI: {e.stderr}", file=sys.stderr)
                exit(1)


        if __name__ == "__main__":
            import sys
            main()
        PYEOF
      '';
    };
  in {
    packages.get-keys = get-keys-pkg;
    apps.get-keys = {
      type = "app";
      program = lib.getExe get-keys-pkg;
    };
  };
}
