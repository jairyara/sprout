---
name: sdd-spec
description: Turn the editable spec brief into a real, acceptance-criteria-driven spec.
metadata:
  scope: sdd
  auto_invoke: "drafting or refining a feature spec"
---

# sdd-spec

Use this to turn the human-filled brief into a proper spec at `sdd/specs/<feature>/spec.md`.
This is the FIRST step of the SDD flow. Work as a single agent — do not spawn subagents.

## Steps

1. Read the brief and `sdd/config.yaml` (for stack/context). Prefer a per-feature brief at
   `sdd/specs/<feature>/brief.md` (created by `sprout sdd spec new <feature>`); fall back to
   the global `sdd/spec.prompt.md`. If the brief is mostly empty, ask the user to fill it
   rather than inventing requirements.
2. **Resolve ambiguity before writing.** Ask the user about every item under "Open
   questions" and any acceptance criterion that isn't observable/checkable. Don't guess on
   anything that changes scope.
3. **Skills check.** Read the brief's "Skills to use / add" section and compare against
   AGENTS.md ("More skills you can add" catalog). If the feature would benefit from a skill
   that isn't installed yet — whether the user named it or you spot the need — surface the
   best-fitting catalog skill(s), explain what each does, and offer to install with
   `sprout skills add <name>`. Only run it after the user confirms; never auto-install.
4. Derive `<feature>` from the brief — its folder name if you read a per-feature
   `brief.md`, otherwise the brief's feature-name field (kebab-case). Create
   `sdd/specs/<feature>/` (already exists if a brief.md is there) and write `spec.md` from
   `sdd/templates/spec.md`:
   - Fill `{{FEATURE}}` and `{{DATE}}` (today, YYYY-MM-DD).
   - **Number the acceptance criteria** (AC1, AC2, …) — plan and verify reference them.
   - Keep it implementation-free: capture WHAT and WHY, not HOW.
   - Move every answered "open question" into "Resolved questions" with the decision.

## Rules

- Acceptance criteria must be observable and testable. Rewrite vague ones ("fast", "nice")
  into checkable statements.
- Honor `rules.spec` in `config.yaml`.
- Stop after writing the spec. Show the user the acceptance criteria and ask them to
  confirm before planning. Next step: the `sdd-plan` skill.
