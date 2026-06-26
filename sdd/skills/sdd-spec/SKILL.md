---
name: sdd-spec
description: Turn the editable spec brief into a real, acceptance-criteria-driven spec.
metadata:
  scope: sdd
  auto_invoke: "drafting or refining a feature spec"
---

# sdd-spec

Use this to turn `sdd/spec.prompt.md` (the human-filled brief) into a proper spec at
`sdd/specs/<feature>/spec.md`. This is the FIRST step of the SDD flow. Work as a single
agent — do not spawn subagents.

## Steps

1. Read `sdd/spec.prompt.md` and `sdd/config.yaml` (for stack/context). If the brief is
   mostly empty, ask the user to fill it rather than inventing requirements.
2. **Resolve ambiguity before writing.** Ask the user about every item under "Open
   questions" and any acceptance criterion that isn't observable/checkable. Don't guess on
   anything that changes scope.
3. Derive `<feature>` from the brief's feature name (kebab-case). Create
   `sdd/specs/<feature>/` and write `spec.md` from `sdd/templates/spec.md`:
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
