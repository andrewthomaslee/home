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
# Runtime lifecycle (devenv script): `code-sandbox sync` renders these
# and pushes them to the gateway on drift; `code-sandbox doctor`
# reports read-only; `code-sandbox create` syncs automatically.
#
# Deliberate exception: the kimi_for_coding policy entry keeps the
# `*-nodejs*/bin/node` wildcard (see the policy template) — kimi-code's
# nodejs comes from the llm-agents input's own nixpkgs closure, not this
# flake's pkgs.nodejs, so an interpolated path could deny kimi egress
# after an input bump.
{self, ...}: {
  perSystem = {
    pkgs,
    customLib,
    ...
  }: {
    packages = {
      # The installable wrapper: baked with THIS repo's source store
      # path (not ".") so hosts can put it on PATH (pkgs.code-sandbox
      # via overlays/default.nix) and run it from ANY directory — no
      # checkout, flake, or devenv required at the call site. All
      # image/policy/profile attrs resolve against the baked ref;
      # `--flake REF` overrides per invocation.
      code-sandbox = pkgs.writeShellScriptBin "code-sandbox" (customLib.mkCodeSandbox {
        flakeRef = builtins.toString self;
      });
      # replaceVars (strict: errors on placeholders not listed below, so
      # a template/placeholder typo fails the build instead of shipping
      # a literal @bin_*@ to the gateway).
      code-agent-policy = pkgs.replaceVars (customLib.relativeToRoot "openshell/policies/code-agent.yaml") {
        bin_nix = "${pkgs.nix}/bin/nix";
        bin_git = "${pkgs.git}/bin/git";
        bin_curl = "${pkgs.curl}/bin/curl";
        bin_claude = "${pkgs.claude-code}/bin/claude";
        bin_claude_wrapped = "${pkgs.claude-code}/bin/.claude-wrapped";
        bin_pi = "${pkgs.pi-coding-agent}/libexec/pi/pi";
        bin_headroom = "${pkgs.headroom-slim}/bin/headroom";
        bin_python3 = "${pkgs.python3}/bin/python3";
        # pip runs in-process, so its connections carry the RESOLVED
        # interpreter exe — nixpkgs' bin/python3 is a symlink to the
        # versioned binary; pin both (as with gh/.gh-wrapped).
        bin_python3_real = "${pkgs.python3}/bin/${pkgs.python3.interpreter}";
        bin_uv = "${pkgs.uv}/bin/uv";
      };

      github-agent-profile = pkgs.replaceVars (customLib.relativeToRoot "openshell/profiles/github-agent.yaml") {
        bin_git = "${pkgs.git}/bin/git";
        bin_gh = "${pkgs.gh}/bin/gh";
        bin_gh_wrapped = "${pkgs.gh}/bin/.gh-wrapped";
        bin_github_mcp_server = "${pkgs.unstable.github-mcp-server}/bin/github-mcp-server";
      };
    };
  };
}
