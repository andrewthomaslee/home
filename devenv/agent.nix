# Agent sandbox variant: `devenv --profile agent shell` (CLI) or
# `nix develop .#agent` (flake). The image itself is the generic
# `shell:latest` built from devenv/default.nix — this module only adds
# agent-runtime conveniences. Keep it free of flake-only references.
{
  pkgs,
  lib,
  config,
  ...
}: let
  repo = "home";
  repoDir = "/env/${repo}";

  # pi provider wiring for the sandbox image: point the built-in
  # kimi-coding provider at the key the OpenShell provider injects as
  # $KIMI_API_KEY (models.json apiKey supports env interpolation), so no
  # auth.json with a real key ever ships in an image.
  pi-models = pkgs.writeText "pi-models.json" ''
    {
      "providers": {
        "kimi-coding": {
          "apiKey": "$KIMI_API_KEY"
        }
      }
    }
  '';

  # nix user config for the sandbox ($HOME is /env): flakes on,
  # sandbox = false because the microVM is the isolation boundary and an
  # unprivileged guest user cannot load the seccomp BPF program the nix
  # build sandbox requires.
  nix-conf = pkgs.writeText "nix.conf" ''
    experimental-features = nix-command flakes
    sandbox = false
    # The OpenShell supervisor stacks its own seccomp filters on sandbox
    # workloads; nix's builder-child hardening (default on) cannot install
    # its filter underneath them and every build dies with
    # "unable to load seccomp BPF program: Operation not permitted".
    # The microVM is the boundary; builders here are trusted nixpkgs
    # derivations, so skipping the in-builder filter is safe.
    filter-syscalls = false

    # Mirror the host's FlakeHub caches (public keys, non-secret) so
    # FlakeHub-originated artifacts substitute instead of building.
    extra-substituters = https://cache.flakehub.com/ https://edge.cache.flakehub.com/
    extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y=
  '';

  # Skeleton for the container's HOME (/env): the pi key wiring and nix
  # config above, nothing else. The worktree is deliberately NOT baked in
  # (secrets); the agent clones it at runtime.
  agent-home = pkgs.runCommand "devenv-agent-home" {} ''
    mkdir -p $out/.pi/agent $out/.config/nix
    cp ${pi-models} $out/.pi/agent/models.json
    cp ${nix-conf} $out/.config/nix/nix.conf
  '';

  # The shell env as a self-contained bash (devenv's stock container
  # entrypoint builds this via config.lib.getInputs; kept in sync here so
  # the custom entrypoint can source the same envScript).
  agent-shell =
    (config.lib.getInputs [
      {
        name = "mk-shell-bin";
        url = "github:rrbutani/nix-mk-shell-bin";
        attribute = "containers";
      }
    ]).mk-shell-bin.lib.mkShellBin {
      drv = config.shell;
      nixpkgs = pkgs;
    };
in {
  # `env` lands in the activated environment (and therefore in the
  # container) even when the entrypoint is not `devenv shell` — OpenShell
  # launches `pi` directly, so `enterShell` is not guaranteed to run.
  env = {
    # Never prompt for credentials; the sandbox receives GITHUB_TOKEN from
    # `openshell sandbox create --env`.
    GIT_TERMINAL_PROMPT = "0";

    # HTTPS credential helper set purely via git's env config. This makes
    # `git clone`/`git push` work without `gh auth setup-git`; git expands
    # $GITHUB_TOKEN when it invokes the helper.
    GIT_CONFIG_COUNT = "1";
    GIT_CONFIG_KEY_0 = "credential.https://github.com.helper";
    GIT_CONFIG_VALUE_0 = "!f() { echo username=x-access-token; echo password=$GITHUB_TOKEN; }; f";

    # Ephemeral repo clone: keep the coding agent's state out of it.
    REPO_URL = "https://github.com/andrewthomaslee/${repo}.git";

    # Commit identity: the external-systems machine account, so the
    # agent's commits/pushes are attributed to the bot (and its PRs are
    # visibly authored by the bot, not by the operator).
    GIT_AUTHOR_NAME = "andrewthomaslee-agent";
    GIT_AUTHOR_EMAIL = "agent@external.systems";
    GIT_COMMITTER_NAME = "andrewthomaslee-agent";
    GIT_COMMITTER_EMAIL = "agent@external.systems";

    CLAN_DIR = repoDir;
    REPO_ROOT = repoDir;
    PI_CODING_AGENT_DIR = "/tmp/pi-agent";

    # pi defaults to the kimi-for-coding subscription endpoint; the key
    # itself is injected by the attached OpenShell provider.
    PI_PROVIDER = "kimi-coding";
    PI_MODEL = "kimi-for-coding";

    # NOTE: nix settings live in /env/.config/nix/nix.conf (baked into the
    # image via agent-home below), not in NIX_CONFIG — multiline env
    # values do not survive the shell envScript export.

    # NOTE: pointing NIX_SSL_CERT_FILE here is not enough — nix's nixpkgs
    # setup hook re-exports it when the shell env is composed, overriding
    # the supervisor's TLS-interception CA bundle and making nix distrust
    # the policy proxy. The custom containers.shell.entrypoint below fixes
    # it after the envScript is sourced.
  };

  # This shell's container is the OpenShell sandbox image: full devenv
  # environment (incl. pi + nix) via the stock entrypoint, user 1000 with
  # HOME=/env, initialized nix DB. Load it into the host docker store —
  # where the OpenShell VM driver looks first — with the flake app
  # `nix run .#load-agent-image` (pure git-tree eval, no devenv CLI
  # state); the older `devenv container copy shell --profile agent` pulls
  # in the CLI/PWD eval. In-sandbox commands run through the image's
  # entrypoint so PATH/env pick up the devenv environment:
  #   openshell sandbox exec -n agent -- <entrypoint> nix build .
  # (entrypoint path: `docker inspect -f '{{json .Config.Entrypoint}}'
  # devenv-agent:latest`).
  containers.shell = {
    name = lib.mkForce "devenv-agent";
    copyToRoot = lib.mkForce [agent-home];

    # Same shape as devenv's stock container entrypoint, plus one fixup
    # after the envScript is sourced: nix's nixpkgs setup hook exports
    # NIX_SSL_CERT_FILE pointing at the image's own CA bundle, which
    # overrides the supervisor's SSL_CERT_FILE and makes nix distrust the
    # OpenShell policy proxy's TLS-interception CA. Re-point it at the
    # supervisor bundle (SSL_CERT_FILE, set by the supervisor) so
    # cache.nixos.org and the GitHub endpoints verify.
    entrypoint = [
      (pkgs.writeScript "agent-entrypoint" ''
        #!${pkgs.bashInteractive}/bin/bash
        export PATH=/bin
        source ${agent-shell.envScript}
        # The OpenShell supervisor sets HOME to the workdir (/sandbox);
        # pin HOME back to the image home so nix reads
        # /env/.config/nix/nix.conf and pi finds /env/.pi/agent/models.json.
        export HOME=/env
        export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
        cmd="$(echo "$@" | ${pkgs.envsubst}/bin/envsubst)"
        exec ${pkgs.bashInteractive}/bin/bash -c "$cmd"
      '')
    ];
  };
}
