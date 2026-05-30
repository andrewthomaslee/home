{
  pkgs,
  kubenix,
  ...
}: let
  kubeVersion = builtins.substring 0 4 "${pkgs.k3s.version}";
in {
  imports = [kubenix.modules.k8s];

  kubenix.project = "base";
  kubernetes = {
    version = kubeVersion;
    namespace = "base";
    resources.namespaces = {
      base = {};
      cert-manager = {};
    };
    objects = [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "sealed-secrets-oci";
          namespace = "base";
        };
        spec = {
          type = "oci";
          interval = "5h";
          url = "oci://registry-1.docker.io/bitnamicharts";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "sealed-secrets";
          namespace = "base";
        };
        spec = {
          targetNamespace = "kube-system";
          interval = "5h";
          chart.spec = {
            chart = "sealed-secrets";
            version = "2.18.x";
            reconcileStrategy = "ChartVersion";
            sourceRef = {
              kind = "HelmRepository";
              name = "sealed-secrets-oci";
            };
          };
          install.crds = "CreateReplace";
          upgrade.crds = "CreateReplace";
          values = {
            fullnameOverride = "sealed-secrets-controller";
            ingress.enabled = true;
            nodeSelector.role = "server";
            resources = {
              limits = {
                cpu = "500m";
                memory = "256Mi";
              };
              requests = {
                cpu = "1m";
                memory = "2Mi";
              };
            };
          };
        };
      }
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "HelmRepository";
        metadata = {
          name = "cert-manager-oci";
          namespace = "base";
        };
        spec = {
          type = "oci";
          interval = "5h";
          url = "oci://quay.io/jetstack/charts";
        };
      }
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2";
        kind = "HelmRelease";
        metadata = {
          name = "cert-manager";
          namespace = "base";
        };
        spec = {
          interval = "5h";
          targetNamespace = "cert-manager";
          chart = {
            spec = {
              chart = "cert-manager";
              version = "1.20.x";
              reconcileStrategy = "ChartVersion";
              sourceRef = {
                kind = "HelmRepository";
                name = "cert-manager-oci";
                namespace = "base";
              };
            };
          };
          install.crds = "CreateReplace";
          upgrade.crds = "CreateReplace";
          values = {
            crds.enabled = true;
            nodeSelector.role = "server";
            resources = {
              limits = {
                cpu = "500m";
                memory = "256Mi";
              };
              requests = {
                cpu = "1m";
                memory = "2Mi";
              };
            };
          };
        };
      }
    ];
  };
}
