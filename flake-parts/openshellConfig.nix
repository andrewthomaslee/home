# OpenShell sandbox config, generated: the code-agent sandbox POLICY
# (openshell/policies/code-agent.yaml) and the github-agent PROVIDER
# PROFILE (openshell/profiles/github-agent.yaml), rendered from their
# templates with the exact store paths of the image's own package set.
#
# Why generated: the gateway admits egress per process, matching
# /proc/pid/exe against the binary lists in these files, and the sandbox
# image is content-rebuilt from this flake on every input bump.
# Hand-written `/nix/store/*-pkg-*/bin/pkg` globs drift silently — the
# github MCP server's pin existed in git but not on the gateway, and its
# api.github.com egress died with EACCES while `gh` kept working. The
# templates carry structure + comments; this module interpolates the
# store paths from the SAME pkgs the image is built from
# (flake-parts/ociImages/code-agent.nix), so image and gateway config
# can never disagree about which binary may call which host.
#
# Resolved exes, not bin/ symlinks: the supervisor matches
# /proc/<pid>/exe — the RESOLVED exe — and nixpkgs bin/ entries are not
# always real files. `nix`'s bin/nix is a symlink into another output;
# pinning the symlink path silently denied EVERY nix egress (github.com
# tarball fetches EACCES'd while git/curl worked — same bug class as
# gh's .gh-wrapped and pi's libexec/pi/pi). Every placeholder is
# therefore filled with the readlink -f target, resolved inside the
# render derivation (no IFD), and an unresolved placeholder or
# non-executable target fails the build.
#
# Runtime lifecycle (devenv script): `code-sandbox sync` renders these
# and pushes them to the gateway on drift; `code-sandbox doctor`
# reports read-only; `code-sandbox create` syncs automatically.
#
# Deliberate exception: the kimi_for_coding policy entry keeps the
# `*-nodejs*/bin/node` wildcard (see the policy template) — kimi-code's
# nodejs comes from the llm-agents input's own nixpkgs closure, not this
# flake's pkgs.nodejs, so an interpolated path could deny kimi egress
# after an input bump.
{
  inputs',
  self,
  ...
}: {
  perSystem = {
    pkgs,
    customLib,
    ...
  }: let
    inherit (pkgs) lib;

    # Fill a template's @bin_*@ placeholders with the RESOLVED exe
    # paths of the given binaries (see the header above).
    renderSandboxConfig = name: template: bins:
      pkgs.runCommand name {} ''
        cp ${template} $out
        for pair in ${
          lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "${n}:${v}") bins)
        }; do
          placeholder="''${pair%%:*}"
          binary="''${pair#*:}"
          target="$(readlink -f "$binary")"
          if [ ! -x "$target" ]; then
            echo "renderSandboxConfig: $binary does not resolve to an executable" >&2
            exit 1
          fi
          sed -i "s|@''${placeholder}@|$target|g" $out
        done
        # A leftover @bin_<name>@ means the template and this list
        # drifted apart — fail loudly instead of shipping a literal
        # placeholder to the gateway.
        if grep -qE '@bin_[a-z_]+@' $out; then
          echo "renderSandboxConfig: unresolved @bin_*@ placeholder in ${template}" >&2
          exit 1
        fi
      '';
  in {
    packages = {
      # The installable wrapper: baked with THIS repo's source store
      # path (not ".") so hosts can put it on PATH (pkgs.code-sandbox
      # via overlays/default.nix) and run it from ANY directory — no
      # checkout, flake, or devenv required at the call site. All
      # image/policy/profile attrs resolve against the baked ref;
      # `--flake REF` overrides per invocation. `remoteFlake` backs the
      # rev-pinning fallback: with no git metadata in the baked source
      # path, the image builds from the public flake at remote HEAD so
      # the in-image briefing pins a real commit (see
      # documentation/docs/openshell/code-sandbox.md).
      code-sandbox = pkgs.writeShellScriptBin "code-sandbox" (customLib.mkCodeSandbox {
        flakeRef = builtins.toString self;
        remoteFlake = "github:external-systems/home";
      });
      code-agent-policy = renderSandboxConfig "code-agent-policy" (customLib.relativeToRoot "openshell/policies/code-agent.yaml") {
        bin_nix = "${pkgs.nix}/bin/nix";
        bin_git = "${pkgs.git}/bin/git";
        bin_curl = "${pkgs.curl}/bin/curl";
        bin_claude = "${pkgs.claude-code}/bin/claude";
        bin_claude_wrapped = "${pkgs.claude-code}/bin/.claude-wrapped";
        bin_pi = "${pkgs.pi-coding-agent}/libexec/pi/pi";
        bin_headroom = "${pkgs.headroom-slim}/bin/headroom";
        bin_python3 = "${pkgs.python3}/bin/python3";
        # pip runs in-process, so its connections carry the RESOLVED
        # interpreter exe — pin the resolved paths of both (nixpkgs'
        # bin/python3 is a symlink to the versioned binary).
        bin_python3_real = "${pkgs.python3}/bin/${pkgs.python3.interpreter}";
        bin_uv = "${pkgs.uv}/bin/uv";
        bin_mcp_nixos = "${inputs'.mcp-nixos.packages.mcp-nixos}/bin/mcp-nixos";
      };

      github-agent-profile = renderSandboxConfig "github-agent-profile" (customLib.relativeToRoot "openshell/profiles/github-agent.yaml") {
        bin_git = "${pkgs.git}/bin/git";
        bin_gh = "${pkgs.gh}/bin/gh";
        bin_gh_wrapped = "${pkgs.gh}/bin/.gh-wrapped";
        bin_github_mcp_server = "${pkgs.unstable.github-mcp-server}/bin/github-mcp-server";
      };
    };
  };
}
