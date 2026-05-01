{
  pkgs,
  # config,
  kubenix,
  name,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
in {
  imports = [
    kubenix.modules.k8s
    kubenix.modules.helm
  ];

  kubenix.project = name;
  kubernetes = {
    version = kubeVersion;
    namespace = "default";
    helm.releases = {};
    objects = [];
  };
}
