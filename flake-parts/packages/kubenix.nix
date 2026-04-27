{inputs, ...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
  in {
    packages = {
      kubenix-home =
        (inputs.kubenix.evalModules.${system} {
          module = {kubenix, ...}: {
            imports = [
              kubenix.modules.k8s
              kubenix.modules.helm
            ];

            kubenix.project = "home";
            kubernetes = {
              version = kubeVersion;
              helm.releases = {};
            };
          };
        }).config.kubernetes.result;

      kubenix-helsinki =
        (inputs.kubenix.evalModules.${system} {
          module = {kubenix, ...}: {
            imports = [
              kubenix.modules.k8s
              kubenix.modules.helm
            ];

            kubenix.project = "helsinki";
            kubernetes = {
              version = kubeVersion;
              helm.releases = {};
            };
          };
        }).config.kubernetes.result;
    };
  };
}
