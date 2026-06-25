---
name: skill-creator
description: Scaffold a new, well-formed Agent Skill (correct folder + SKILL.md frontmatter).
metadata:
  scope: meta
  auto_invoke: "creating or authoring a new skill"
---

# skill-creator

Use this when you need to author a new Agent Skill so it matches the standard sprout
expects and resolves cleanly through the registry.

## Layout

A skill is a self-contained folder:

```
<skill-name>/
├── SKILL.md       # required: frontmatter + instructions
├── scripts/       # optional: executables the skill calls
├── assets/        # optional: templates, schemas
└── references/    # optional: local docs (offline "always-current" docs, no MCP)
```

## Required frontmatter

```markdown
---
name: <kebab-case-id>          # must match the folder and the registry row
description: <one line>         # used when listing / recalling the skill
metadata:
  scope: core|web|fullstack|…   # when the skill applies
  auto_invoke: "<short trigger phrase>"   # fed into the AGENTS.md auto-invoke table
---
```

## Rules

- `name` is unique, kebab-case, and identical to the folder name and the `sets/*.list`
  / `registry.tsv` entry.
- `auto_invoke` is a short phrase describing *when* to reach for the skill — keep it
  action-oriented ("debugging a bug", "creating UI components"). `skill-sync` reads it.
- Keep `SKILL.md` instructions concise and imperative. Put long material in `references/`.
- All skill content is written in **English**.

## After creating

Run the `skill-sync` skill (or `skills/sync-agents.sh <project>`) so the new skill
appears in the project's AGENTS.md auto-invoke table.
