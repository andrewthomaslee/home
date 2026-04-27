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
              helm.releases = {
                cilium = {
                  inherit kubeVersion;
                  chart = kubenix.lib.helm.fetch {
                    repo = "https://helm.cilium.io/";
                    chart = "cilium";
                    version = "1.19.3";
                    sha256 = "sha256-rt3TlLpIMTLyN+DZFRpHItt7tadQ3k+BghkfwhI8Yaw=";
                  };
                  values = {
                    cni.resources.limits.cpu = "4"; # TODO: Set no limit

                    rollOutCiliumPods = true;

                    devices = "cm";
                    MTU = 1370;
                    operator.replicas = 1;
                    kubeProxyReplacement = true;
                    k8sServiceHost = "kamrui-p1.cm";
                    k8sServicePort = "6443";

                    ipv4.enabled = true;
                    ipv6.enabled = true;

                    ipam.mode = "kubernetes";
                  };
                };
              };
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
              helm.releases = {
                cilium = {
                  inherit kubeVersion;
                  chart = kubenix.lib.helm.fetch {
                    repo = "https://helm.cilium.io/";
                    chart = "cilium";
                    version = "1.19.3";
                    sha256 = "sha256-rt3TlLpIMTLyN+DZFRpHItt7tadQ3k+BghkfwhI8Yaw=";
                  };
                  values = {
                    cni.resources.limits.cpu = "4"; # TODO: Set no limit

                    rollOutCiliumPods = true;

                    devices = "cm";
                    MTU = 1370;
                    operator.replicas = 1;
                    kubeProxyReplacement = true;
                    k8sServiceHost = "hel-1.cm";
                    k8sServicePort = "6443";

                    ipv4.enabled = true;
                    ipv6.enabled = true;

                    ipam.mode = "kubernetes";
                  };
                };
              };
            };
          };
        }).config.kubernetes.result;
    };
  };
}
