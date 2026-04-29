{...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    apps = {
      tmp-pod = {
        type = "app";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "tmp-pod";
          runtimeInputs = with pkgs; [
            k3s
          ];
          text = builtins.readFile ./tmp-pod.sh;
        });
      };
    };
  };
}
