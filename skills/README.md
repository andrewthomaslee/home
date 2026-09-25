# Repo-local opencode Skills and References

Repo-local agent material for opencode, merged into `~/.config/opencode/`
by `flake-parts/homeModules/opencode.nix`:

- **Skills** (`~/.config/opencode/skills`) — behavior/procedure packs
  merged by `inputs.agents.lib.mkSkills` (a `pkgs.linkFarm` over custom +
  external skill sources). Always discoverable via their frontmatter
  description; the agent loads `SKILL.md` when the description matches.
- **References** (`~/.config/opencode/references`) — topic doc bundles
  (OpenCode V2 `references` config field), one directory per reference
  from this repo's top-level `references/` tree, advertised via
  `settings.references` with a description and attachable by alias.
  Deep "how things work" material lives here so skills stay lean.

## Skill convention

One directory per skill, each containing a `SKILL.md` with YAML
frontmatter:

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
detail into the shared `references/` tree instead — reference aliases
are advertised with when-to-use descriptions, so there is no reason to
duplicate deep material per skill.

## Current skills

- `baton-pass` — session handoff: saves the full state of an in-progress
  task to `.baton-pass/` (timestamped markdown file + `LATEST.md`
  pointer, auto-gitignored) so a different agent or model can resume
  where the session stopped, or resume from an existing handoff.
  Language- and repo-agnostic.

## Reference convention

One directory per reference under the repo-root `references/` tree,
each with an `index.md`:

```
references/
  nix-style/index.md     # Nix style guide + mandatory tool loop
  flake-parts/index.md
  import-tree/index.md
  determinate/index.md
  home-manager/index.md
  clan-core/index.md
  devenv/index.md
  vm-tests/index.md
```

Enabling is per profile:
`homeSpec.programs.opencode.references.<name>.enable` (description has
a module default per alias, overridable via
`...references.<name>.description`). When enabled, the module installs
`~/.config/opencode/references/<name>` (symlink to the store copy) and
emits a `settings.references.<name>` entry (`path` +
`description`), which opencode advertises in agent instructions.

## Current references

| Alias | Covers |
|---|---|
| `nix-style` | Nix code style (nesting, quoting, inherit, repo-root paths, module system), the mandatory alejandra/statix/deadnix tool loop, devShell + agent rules |
| `flake-parts` | mkFlake/perSystem mechanics, what the infra provides, input handling, lint gate, integrations |
| `import-tree` | flake-parts auto-import: mechanics, tree layout conventions, agent rules |
| `determinate` | Determinate docs map, FlakeHub publishing/cache/private flakes, semver (rolling `0.1.<commits>`), `fh` CLI + `fh apply` |
| `home-manager` | HM with flakes + flake-parts, worked example: `homeModules/profiles/netsa.nix` |
| `clan-core` | inventory, clanServices, exports + strict-eval check, vars/generators, clan CLI, machine updates, clanService VM tests |
| `devenv` | devenv 2.x CLI reference, CLI-native vs flake embedding, borg hybrid pattern, devcontainer.json, monorepo/polyrepo, containers/K8s, Claude Code integration |
| `vm-tests` | Hermetic NixOS VM tests: structure, size variants, running, agent loop |

## Precedence

- Custom skills (this folder) override external skills with the same
  name.
- Among external sources (`anthropics/skills`, `payloadcms/skills`),
  earlier entries in `externalSkills` win collisions.

## Notes

- Nix evaluates the flake from the git tree: `git add` new skill or
  reference files before `nix build` / `nix flake check` will see them.
- Skills are global (all machines with
  `homeSpec.programs.opencode.enable`). References are opt-in per
  profile (currently `profile-netsa`). For project-level skills, use a
  project `.agents/skills` directory instead.
