# Custom opencode Skills

Repo-local skills for opencode, merged into `~/.config/opencode/skills` by
`flake-parts/homeModules/opencode.nix` via `inputs.agents.lib.mkSkills`
(a `pkgs.linkFarm` over custom + external skill sources).

## Convention

One directory per skill, each containing a `SKILL.md` with YAML frontmatter:

```
skills/
  my-skill/
    SKILL.md        # required: name + description frontmatter
    references/     # optional: details loaded on demand (progressive
    ...             #   disclosure keeps always-on context small)
```

```markdown
---
name: my-skill
description: When this skill should be used (drives agent triggering).
---
```

Keep `SKILL.md` lean (rules the agent needs every time) and push
detail (worked examples, deep reference material) into `references/`
linked from `SKILL.md`.

## Current skills

- `nix-flake` — generic conventions for Nix flake repos: Determinate Nix,
  FlakeHub, GitHub Actions (self-hosted runners), `nix build .#<thing>`,
  alejandra/statix/deadnix tool loop, hermetic NixOS VM tests.
  Repo-specific facts live in each repo's `AGENTS.md`, not here.
- `baton-pass` — session handoff: saves the full state of an in-progress
  task to `.baton-pass/` (timestamped markdown file + `LATEST.md` pointer,
  auto-gitignored) so a different agent or model can resume where the
  session stopped, or resume from an existing handoff. Language- and
  repo-agnostic.
- `devenv` — expert guide to devenv 2.x: devenv.nix/devenv.yaml/devenv.lock
  authoring, the full devenv CLI, devenv.yaml inputs and lock discipline,
  the v2 changes (native process manager migration, breaking changes),
  flake-parts and plain-flake integration (worked example: the borg repo's
  dual-mode CLI + flake-parts wiring), devcontainer.json for GitHub
  Codespaces, monorepo/polyrepo composition, cross-platform patterns,
  containers/CI, Claude Code integration, and a devenv.sh doc map.

## Precedence

- Custom skills (this folder) override external skills with the same name.
- Among external sources (`anthropics/skills`, `payloadcms/skills`), earlier
  entries in `externalSkills` win collisions.

## Notes

- Nix evaluates the flake from the git tree: `git add` new skill files before
  `nix build` / `nix flake check` will see them.
- Skills are global (all machines with `homeSpec.programs.opencode.enable`).
  For project-level skills, use a project `.agents/skills` directory instead.
