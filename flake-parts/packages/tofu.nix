{self, ...}: {
  # ------ Per-System ------ #
  perSystem = {
    pkgs,
    lib,
    self',
    customLib,
    ...
  }:
    with pkgs; let
      # Create a derivation containing the flake source and the generated terraform config
      tofu-source-dir = stdenv.mkDerivation {
        name = "tofu-source-dir";
        src = self;
        installPhase = ''
          mkdir -p $out
          cp -a $src/. $out/
          chmod +w $out
          cp ${self'.packages.tofu.config} $out/config.tf.json
        '';
      };

      tfRunnerBase = dockerTools.pullImage {
        imageName = "ghcr.io/flux-iac/tf-runner";
        imageDigest = "sha256:b5e52b3262efda1a0fa4819c8f3fdfdaa533e50c5f31da476a7932f4e7567c26";
        hash = "sha256-7UEDglxAuHiS4pCDeJu/3RdI/aJNszenLCdK8ErI4Bs=";
        finalImageName = "ghcr.io/flux-iac/tf-runner";
        finalImageTag = "v0.16.0-base";
      };
    in {
      # oci containers for flux opentofu controller
      packages = {
        # The OCI artifact used as the source for the Terraform CRD
        oci-tofu-source = dockerTools.buildImage {
          name = "home/flux-iac/tf-source/tofu";
          extraCommands = ''
            cp -a ${tofu-source-dir}/. .
          '';
        };

        # The custom runner image for tf-controller containing tofu and dependencies
        oci-tofu-runner = dockerTools.buildLayeredImage {
          name = "home/flux-iac/tf-runner/tofu";
          fromImage = tfRunnerBase;
          contents = [self'.packages.tofu.terraform];
          config = {
            User = "65532:65532";
            Entrypoint = [
              "/sbin/tini"
              "--"
              "tf-runner"
            ];
            Env = [
              "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
              "GNUPGHOME=/tmp"
            ];
          };
        };
      };
    };
}
