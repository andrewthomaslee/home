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
    ...             # optional supporting files (reference docs, scripts)
```

```markdown
---
name: my-skill
description: When this skill should be used (drives agent triggering).
---
```

## Precedence

- Custom skills (this folder) override external skills with the same name.
- Among external sources (`anthropics/skills`, `payloadcms/skills`), earlier
  entries in `externalSkills` win collisions.

## Notes

- Nix evaluates the flake from the git tree: `git add` new skill files before
  `nix build` / `nix flake check` will see them.
- Skills are global (all machines with `homeSpec.programs.opencode.enable`).
  For project-level skills, use a project `.agents/skills` directory instead.
