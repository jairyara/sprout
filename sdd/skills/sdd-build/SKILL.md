---
name: sdd-build
description: Implement exactly ONE phase of an SDD plan, keeping the diff small.
metadata:
  scope: sdd
  auto_invoke: "implementing a phase of an SDD plan"
---

# sdd-build

Use this to execute a single phase from `sdd/specs/<feature>/plan.md`. Single agent — do
NOT delegate to subagents (this project runs single-agent by default).

## Steps

1. Read `plan.md`, the feature's `spec.md`, and `sdd/config.yaml`. Identify the target
   phase — the user names it, otherwise the first phase not marked `█ done`.
2. Set that phase's status to `▓ in progress` (and the overview bar).
3. If `strict_tdd: true` in `config.yaml`: write the failing test(s) for the phase's
   acceptance criteria FIRST, run `commands.test`, confirm they fail, then implement until
   they pass.
4. Implement **only this phase's tasks**. Follow the repo's existing conventions and
   `context.style`. Keep the diff small and focused. Tick each task `- [x]` as you finish.
5. Run the phase's own **Verification** command from the plan. If it passes, set the phase
   to `█ done` (and its overview bar).

## Rules

- One phase only. Do **not** start the next phase — stop and hand back to the user.
- Honor `rules.build` in `config.yaml`. Don't expand scope beyond the phase's tasks.
- If you hit something the spec didn't anticipate, stop and ask rather than guessing; if it
  changes the spec, note it and suggest re-running `sdd-spec`/`sdd-plan`.
- After the phase, suggest running the `sdd-verify` skill before moving on.
