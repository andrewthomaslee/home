# OpenCode Skills — Declarative Skill Management

OpenCode skills are packaged instructions (`SKILL.md` + optional supporting
files) that extend agent capabilities. This flake manages them declaratively:
`flake-parts/homeModules/opencode.nix` builds a single merged skills folder
and symlinks it to `~/.config/opencode/skills` via `xdg.configFile`. Every
machine with `homeSpec.programs.opencode.enable` gets the same global skill
set.

## Composition

Merging is done by `inputs.agents.lib.mkSkills`
([AGENTS](https://code.m3ta.dev/m3tam3re/AGENTS)), which builds a
`pkgs.linkFarm "opencode-skills"` — one symlink per skill directory:

```nix
xdg.configFile."opencode/skills".source = inputs.agents.lib.mkSkills {
  inherit pkgs;
  customSkills = ../../skills;
  externalSkills = [
    {src = inputs.skills-anthropic;}   # anthropics/skills, skills/ dir
    {src = inputs.skills-payloadcms;}  # payloadcms/skills, skills/ dir
  ];
};
```

### Sources

| Source | Type | Skills |
|---|---|---|
| `skills/` (this repo) | custom | `dendritic-nix` (repo conventions for agents) |
| [anthropics/skills](https://github.com/anthropics/skills) | external | docx, pdf, pptx, xlsx, mcp-builder, frontend-design, ... |
| [payloadcms/skills](https://github.com/payloadcms/skills) | external | `payload` (Payload development guidelines), `cms-migration` (CMS → Payload migration workflow) |

External sources are flake inputs with `flake = false`; `mkSkills` reads each
repo's `skills/` directory (override with `skillsDir`, cherry-pick with
`selectSkills = [...]`).

### Precedence

1. Custom skills (`skills/`) override same-named externals.
2. Among externals, earlier entries in `externalSkills` win.

## Adding a custom skill

One directory per skill under `skills/`, containing a `SKILL.md` with YAML
frontmatter (`name`, `description` — the description drives agent triggering):

```
skills/
  my-skill/
    SKILL.md
    reference/   # optional supporting files
```

Then `git add skills/my-skill/` — Nix evaluates the flake from the git tree,
so untracked files are invisible to `nix build` / `nix flake check`.

## Adding an external source

Add a `flake = false` input in `flake.nix` and an entry in `externalSkills`:

```nix
# flake.nix
skills-acme = {
  url = "github:acme/skills";
  flake = false;
};
```

```nix
# flake-parts/homeModules/opencode.nix
externalSkills = [
  {src = inputs.skills-anthropic;}
  {src = inputs.skills-payloadcms;}
  {src = inputs.skills-acme;}
];
```

The repo root must contain a `skills/` directory (or set `skillsDir`).

## Verify

- Eval + symlink path:
  `nix eval --raw .#nixosConfigurations.<name>.config.home-manager.users.netsa.xdg.configFile."opencode/skills".source`
  — prints the `opencode-skills` linkFarm store path; `ls` it to see the
  merged skill set.
- `nix flake check --show-trace` evaluates all machines (CI parity).
- Build a machine toplevel to exercise the module end-to-end:
  `nix build .#nixosConfigurations.ghost.config.system.build.toplevel`
