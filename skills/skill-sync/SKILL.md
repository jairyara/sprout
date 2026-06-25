---
name: skill-sync
description: Regenerate the AGENTS.md auto-invoke table from the vendored skills' frontmatter.
metadata:
  scope: meta
  auto_invoke: "after adding, removing or editing a project skill"
---

# skill-sync

Agents do not reliably auto-invoke a skill just because its `Trigger`/`auto_invoke`
matches. sprout works around this by forcing it: the project's `AGENTS.md` carries an
**Auto-invoke Skills** table that maps "when you are about to X" → "invoke skill Y".

This skill keeps that table in sync with what is actually vendored in `skills/`.

## What it does

Reads every `skills/*/SKILL.md`, extracts `name` and `auto_invoke` from the frontmatter,
and rewrites the table between these markers in `AGENTS.md`:

```
<!-- BEGIN AUTO-INVOKE -->
…generated table…
<!-- END AUTO-INVOKE -->
```

If the markers are missing it appends a fresh `## Auto-invoke Skills` section.

## How to run

```sh
skills/sync-agents.sh <project_dir>
# or, dry-run to preview the table without writing:
DRY_RUN=1 skills/sync-agents.sh <project_dir>
```

Run it after `sprout skills add`, `sprout skills update`, or any manual edit to a
skill's `auto_invoke`.
