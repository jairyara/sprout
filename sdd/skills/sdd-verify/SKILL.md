---
name: sdd-verify
description: Run the project's checks and validate a phase/feature against its spec.
metadata:
  scope: sdd
  auto_invoke: "verifying a phase or feature against its spec"
---

# sdd-verify

Use this to confirm a phase (or the whole feature) actually meets the spec. Single agent —
do not spawn subagents.

## Steps

1. Read `sdd/config.yaml`, the feature's `spec.md`, and `plan.md`.
2. Run each non-empty command in `config.yaml` `commands:` (`typecheck`, `lint`, `test`,
   `build`). Report each as pass/fail with the relevant output. Don't paper over failures.
3. Go through the acceptance criteria covered by the phase (or all of them, if verifying
   the feature). For each, state **explicitly** whether it's met and the evidence (a test,
   a command, an observed behavior). Use the project's `verify` skill / real app run when a
   criterion needs human-observable behavior, not just a green test.
4. Summarize: which ACs pass, which don't, and what's left.

## Rules

- Report honestly. If a check fails or was skipped, say so with the output — never claim
  done on a red or unrun check.
- Honor `rules.verify` in `config.yaml`.
- If everything for the phase passes, confirm the phase is `█ done` in `plan.md` and point
  to the next phase. If the whole plan is done, say the feature is complete and suggest a
  commit (the `conventional-commits` skill).
