# Agent sandbox variant: `devenv --profile agent shell` (CLI) or
# `nix develop .#agent` (flake). The image itself is the generic default
# `shell:latest` built from devenv/default.nix — this module only adds
# agent-runtime conveniences. Keep it free of flake-only references.
_: let
  repo = "home";
  repoDir = "/env/${repo}";
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

    CLAN_DIR = repoDir;
    REPO_ROOT = repoDir;
    PI_CODING_AGENT_DIR = "/tmp/pi-agent";
  };
}
