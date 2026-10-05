_: {
  # ------ Per-System ------ #
  # OCI image for OpenShell sandboxes that run the pi coding agent against
  # the kimi-for-coding endpoint. Credentials never bake into the image:
  # the OpenShell provider attached at `sandbox create` injects
  # $KIMI_API_KEY, and models.json below points the built-in kimi-coding
  # provider at it via env interpolation.
  #
  # Delivery to the VM driver (openshell-driver-vm): the driver first
  # checks the host container engine's local image store (so
  # `docker load < $(nix build -A pi-agent-image --print-out-paths)` is
  # enough — the gateway's `openshell` user is in the `docker` group) and
  # falls back to an OCI registry pull for anything not found locally.
  perSystem = {pkgs, ...}: let
    # ~/.pi/agent/models.json rendered into the image. pi composes
    # models.json overrides above its built-in providers, so this only
    # swaps the auth source of the built-in kimi-coding provider.
    pi-models = pkgs.writeText "pi-models.json" ''
      {
        "providers": {
          "kimi-coding": {
            "apiKey": "$KIMI_API_KEY"
          }
        }
      }
    '';
  in {
    packages.pi-agent-image = pkgs.dockerTools.buildLayeredImage {
      name = "pi-agent";
      tag = "latest";

      contents = with pkgs; [
        pi-coding-agent # wraps its own nodejs 24 runtime (global undici EnvHttpProxyAgent honors the sandbox proxy)
        git
        gh
        curl
        cacert
        jq
        less
        openssh
        python3
        ripgrep
        bashInteractive
        coreutils
      ];

      # fakeroot so chown to the unmapped UID works; plain extraCommands
      # runs as the nix build user where chown(1000) fails with EINVAL.
      fakeRootCommands = ''
        # No OCI USER is set on purpose: OpenShell runs USER-less images as
        # UID/GID 1000, so bake the home and workdir with that owner to
        # match the policy filesystem identity.
        mkdir -p home/agent/.pi/agent sandbox
        cp ${pi-models} home/agent/.pi/agent/models.json
        chown -R 1000:1000 home/agent sandbox
      '';

      config = {
        Env = [
          "HOME=/home/agent"
          "PI_PROVIDER=kimi-coding"
          "PI_MODEL=kimi-for-coding"
        ];
        WorkingDir = "/sandbox";
      };
    };
  };
}
