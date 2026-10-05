# OpenShell gateway nixosModule, exercised hermetically: a throwaway PKI is
# generated at build time and handed to the module via the provisionSecrets
# = false overrides, so no clan vars machinery is needed in the test.
#
# Tiers (gated on `size`):
#   sm/md — gateway unit comes up, the managed VM driver subprocess spawns
#           its UDS, the CLI's system registration + mTLS bundle are in
#           place, and `openshell status` reports Connected/Authenticated.
#   lg    — additionally creates a real sandbox (pulls the image from
#           nvcr.io): sandboxed nix builds have no external network, so run
#           this tier with
#           `nix run .#vm-test -- openshell-gateway-lg --driver`.
{
  self,
  inputs,
  pkgs,
  lib,
  size,
  sizeCfg,
}:
pkgs.testers.runNixOSTest {
  name = "openshell-gateway";
  globalTimeout = sizeCfg.global_timeout;

  nodes.machine = {pkgs, ...}: let
    # Throwaway CA + leaf certs + JWT keys (never leaves the store).
    fakeSecrets = pkgs.runCommand "openshell-fake-secrets" {nativeBuildInputs = [pkgs.openssl];} ''
      mkdir -p $out
      work=$(mktemp -d)
      cd $work

      openssl req -x509 -newkey rsa:3072 -nodes \
        -keyout $out/ca.key -out $out/ca.crt -days 30 -subj "/CN=openshell-local-ca" \
        -addext "basicConstraints=critical,CA:TRUE"

      openssl req -newkey rsa:2048 -nodes \
        -keyout $out/gateway.key -out gateway.csr -subj "/CN=openshell-gateway-vmtest"
      printf 'subjectAltName=DNS:localhost,DNS:vmtest,IP:127.0.0.1\nextendedKeyUsage=serverAuth,clientAuth\n' > ext
      openssl x509 -req -in gateway.csr -CA $out/ca.crt -CAkey $out/ca.key \
        -CAcreateserial -out $out/gateway.crt -days 30 -sha256 -extfile ext

      openssl req -newkey rsa:2048 -nodes \
        -keyout $out/client.key -out client.csr -subj "/CN=openshell-client-vmtest"
      printf 'extendedKeyUsage=clientAuth\n' > extc
      openssl x509 -req -in client.csr -CA $out/ca.crt -CAkey $out/ca.key \
        -CAcreateserial -out $out/client.crt -days 30 -sha256 -extfile extc

      openssl genpkey -algorithm Ed25519 -out $out/signing.pem
      openssl pkey -in $out/signing.pem -pubout -out $out/public.pem
      echo vmtest-kid > $out/kid
    '';
  in {
    imports = [
      inputs.clan-core.nixosModules.clanCore
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.nix-ld
      self.nixosModules.openshell-gateway
    ];

    # A non-root user with the openshell CLI enabled and *no* openshell
    # settings at all: the NixOS module's home-manager sharedModules
    # injection must default the system gateway mirror in for them.
    users.users.alice = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };
    home-manager = {
      useGlobalPkgs = true;
      users.alice = {
        imports = [self.homeModules.openshell];
        home.stateVersion = "26.11";
        homeSpec.programs.openshell.enable = true;
      };
    };

    # Minimal clan wiring so the module's clan.core.vars.generators
    # declarations evaluate (generators stay disabled via
    # provisionSecrets = false; secrets come from the fake store paths).
    clan.core.settings = {
      directory = self;
      machine.name = "vmtest";
    };

    hostSpec.services.nix-ld.enable = true;
    hostSpec.services.openshell.gateway = {
      enable = true;
      provisionSecrets = false;
      gatewayCertFile = "${fakeSecrets}/gateway.crt";
      gatewayKeyFile = "${fakeSecrets}/gateway.key";
      caFile = "${fakeSecrets}/ca.crt";
      clientCertFile = "${fakeSecrets}/client.crt";
      clientKeyFile = "${fakeSecrets}/client.key";
      jwtSigningKeyFile = "${fakeSecrets}/signing.pem";
      jwtPublicKeyFile = "${fakeSecrets}/public.pem";
      jwtKidFile = "${fakeSecrets}/kid";
    };

    # Nested KVM for the libkrun microVMs; the wrong-vendor module is inert.
    boot.kernelModules = ["kvm-amd" "kvm-intel"];
    boot.extraModprobeConfig = ''
      options kvm_amd nested=1
      options kvm_intel nested=1
    '';

    # runNixOSTest pins its own pkgs (nixpkgs.overlays is read-only there),
    # so apply the repo overlay by overriding the whole package set instead.
    nixpkgs.pkgs = lib.mkDefault (import pkgs.path {
      inherit (pkgs.stdenv.hostPlatform) system;
      overlays = [self.overlays.default];
    });

    virtualisation = {
      memorySize =
        if size == "lg"
        then 8192
        else 4096;
      cores = 4;
    };
  };

  testScript = ''
    import time

    def wait_unit_or_fail(m, unit, timeout=300):
        """wait_for_unit that fails fast: aborts as soon as the unit enters
        the failed state (or a short deadline passes) instead of hanging
        until the driver's global_timeout."""
        deadline = time.time() + timeout
        while True:
            state = m.execute(
                f"systemctl show -p ActiveState --value {unit} 2>/dev/null || true"
            )[1].strip()
            if state == "active":
                m.log(f"{unit} is active")
                return
            if state == "failed":
                m.log(m.execute(f"journalctl -u {unit} -n 80 --no-pager || true")[1])
                raise Exception(f"{unit} entered the failed state on {m.name}")
            if state == "inactive":
                m.log(m.execute(f"journalctl -u {unit} -n 80 --no-pager || true")[1])
                raise Exception(f"{unit} is inactive (exited without becoming active) on {m.name}")
            if time.time() > deadline:
                m.log(m.execute(f"journalctl -u {unit} -n 80 --no-pager || true")[1])
                raise Exception(f"timeout ({timeout}s) waiting for {unit}, last state: {state}")
            time.sleep(3)


    machine.wait_for_unit("multi-user.target", timeout=300)
    wait_unit_or_fail(machine, "openshell-gateway.service")

    with subtest("gateway serves TLS health endpoint"):
        machine.wait_for_open_port(17670, addr="127.0.0.1", timeout=120)
        machine.wait_for_open_port(17671, addr="127.0.0.1", timeout=120)

    with subtest("managed VM driver subprocess spawned its UDS"):
        machine.wait_for_file("/var/lib/openshell/vm/run/compute-driver.sock", timeout=120)

    with subtest("system-seeded client registration with mTLS bundle"):
        machine.succeed("grep -q '\"auth_mode\":\"mtls\"' /etc/openshell/gateways/local/metadata.json")
        machine.succeed("grep -q local /etc/openshell/active_gateway")
        machine.succeed("test -s /etc/openshell/gateways/local/mtls/tls.key")
        machine.succeed("openshell --version")

    with subtest("CLI connects over mTLS via the system registration"):
        # Only active_gateway/metadata.json fall back to the /etc/openshell
        # system registry — the mTLS bundle is per-user state
        # (~/.config/openshell). Symlink the system registry into root's
        # config (what a user gets with: ln -s /etc/openshell ~/.config/openshell).
        machine.succeed("mkdir -p /root/.config && ln -sfn /etc/openshell /root/.config/openshell")
        # Capture to a file first: `grep -q` exits early and the CLI panics
        # on the resulting EPIPE.
        machine.succeed("HOME=/root openshell status > /tmp/status.txt")
        machine.succeed("grep -q 'Status: Connected' /tmp/status.txt")
        machine.succeed("grep -q 'Authentication: Authenticated' /tmp/status.txt")
        machine.succeed("HOME=/root openshell gateway info > /tmp/info.txt")
        machine.succeed("grep -qi 'vm' /tmp/info.txt")

    with subtest("non-root user uses the gateway with zero openshell config"):
        # home-manager activation materialized alice's ~/.config/openshell
        # mirror (symlinked mtls bundle + active gateway), injected by the
        # NixOS module's sharedModules defaults.
        machine.succeed("test -L /home/alice/.config/openshell/gateways/local/mtls/tls.key")
        machine.succeed("su - alice -c 'openshell status > /tmp/alice-status.txt'")
        machine.succeed("grep -q 'Status: Connected' /tmp/alice-status.txt")
        machine.succeed("grep -q 'Authentication: Authenticated' /tmp/alice-status.txt")

    ${lib.optionalString (size == "lg") ''
      with subtest("create a sandbox (pulls image, boots nested microVM)"):
          machine.succeed("HOME=/root openshell sandbox create --name demo")
          machine.wait_until_succeeds(
              "HOME=/root openshell sandbox list > /tmp/sandboxes.txt && grep -q demo /tmp/sandboxes.txt",
              timeout=2400,
          )

      with subtest("exec inside the microVM"):
          out = machine.succeed("HOME=/root openshell sandbox exec -n demo -- uname -r")
          print(out)
          machine.succeed("HOME=/root openshell sandbox delete demo")
    ''}
  '';
}
