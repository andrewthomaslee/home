---
name: add-skill-or-reference
description: Add a new opencode skill or reference to the home flake repo (github.com/andrewthomaslee/home). Use when the user asks to add, create, or document a skill or a reference in this repo — covers the skill-vs-reference decision, where files go, which Nix wiring each needs, and the house rules (git add, lint loop, README updates).
---

# Add a Skill or Reference (home repo)

How to extend this repo's agent material. Two kinds of content live under
the repo root, both merged into `~/.config/opencode/` by
`flake-parts/homeModules/opencode.nix`:

- **Skills** (`skills/<name>/SKILL.md`) — a procedure the agent should
  *do* (steps, rules, a workflow).
- **References** (`references/<name>/index.md`) — deep "how things work"
  docs the agent should *read* on demand.

Decision rule: if it tells the agent how to *behave*, it is a skill; if
it explains how something *works*, it is a reference. When both apply,
write the skill lean and push the deep material into a reference (skill
frontmatter descriptions are always in context; reference bodies load
only when attached).

## Adding a skill — no Nix changes

1. Create `skills/<kebab-case-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: kebab-case-name
   description: When this skill should be used (drives agent triggering).
   ---
   ```

   The `description` is the only trigger mechanism — write it as a
   when-to-use sentence naming the phrases a user would say.
2. Optional: add a `references/` subdir inside the skill dir for
   progressive disclosure (details loaded on demand, as baton-pass does).
3. Keep `SKILL.md` lean. Do not duplicate material that already exists in
   the repo's `references/` tree — point at the alias instead.
4. **That is the whole wiring.** `flake-parts/homeModules/opencode.nix`
   merges the entire `skills/` tree via
   `inputs.agents.lib.mkSkills { customSkills = relativeToRoot "skills"; }`.
   Skills are global: every machine with
   `homeSpec.programs.opencode.enable` gets them — there is no per-skill
   option and no profile opt-in. Custom skills override external skills
   (anthropics/skills, davidondrej/skills, ...) on name collision.

## Adding a reference — two Nix edits

1. Create `references/<name>/index.md` (one directory per reference,
   `index.md` required; extra files are fine).
2. Add the alias and its default description to `availableReferences` in
   `flake-parts/homeModules/opencode.nix`. The `lib.genAttrs` there
   auto-generates the `homeSpec.programs.opencode.references.<name>`
   option (`enable` + overridable `description`) and the
   `settings.references` plumbing — do not edit the options block.
3. Enable it per profile in
   `flake-parts/homeModules/profiles/netsa.nix`
   (`references.<name>.enable = true;`). References are opt-in per
   profile, unlike skills.
4. Keep the description one dense sentence: topic + subtopics +
   "Load when ..." trigger. It is advertised verbatim in agent
   instructions.

## House rules (both kinds)

- Update `skills/README.md`: the Current skills list or the references
  table. It is the human-facing index of this tree.
- `git add` every new file before any `nix build` / `nix flake check` —
  Nix evaluates the flake from the git tree; untracked files do not
  exist.
- If a `.nix` file changed, run the mandatory lint loop before declaring
  done: `nix fmt .` → `statix check .` → `deadnix --fail .`, then
  `nix flake check`. Skill/reference markdown alone needs none of these.
- Public repo: no secrets in any file (skills, references, README
  included).
- Changes reach machines via the FlakeHub pull deploy (release →
  `fh apply`), not immediately — say so if the user expects instant
  availability.
- Verify with `ls ~/.config/opencode/skills` / `.../references` on the
  next activation, or run the opencode VM test (`nix run .#vm-test --
  opencode-sm`) only if asked.

## Cross-reference

For SKILL.md craft in general (triggering accuracy, structure, evals),
load the external `effective-agent-skills` skill. This skill covers only
this repo's wiring and conventions.
