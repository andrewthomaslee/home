{inputs, ...}: {
  # ------ Per-System ------ #
  perSystem = {
    system,
    customLib,
    ...
  }: {
    packages.kubenix =
      (inputs.kubenix.evalModules.${system} {
        module = customLib.custom.relativeToRoot "kubenix.nix";
      }).config.kubernetes.result;
  };
}
