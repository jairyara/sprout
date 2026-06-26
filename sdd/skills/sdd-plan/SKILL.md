---
name: sdd-plan
description: Slice a spec into the smallest phases that each ship a verifiable deliverable.
metadata:
  scope: sdd
  auto_invoke: "breaking a spec into a phased plan"
---

# sdd-plan

Use this to turn `sdd/specs/<feature>/spec.md` into a phased `plan.md` in the same folder.
Single agent — do not spawn subagents.

## Steps

1. Read the feature's `spec.md` and `sdd/config.yaml`. If multiple features exist, confirm
   which one with the user.
2. Slice the work into **the smallest phases that each ship a verifiable deliverable**.
   Prefer 2–5 phases. Each phase should:
   - map to one or more acceptance criteria (`Covers: AC1, AC2`),
   - have a concrete **Deliverable** (something that exists/works at the end),
   - have a **Verification** line naming the command and the AC it proves.
3. Write `plan.md` from `sdd/templates/plan.md`:
   - Fill the phase-overview status bars (all `░ todo`).
   - Give each phase a short task checklist (`- [ ]`).
   - Order phases so each builds on the last; a walking-skeleton/first-vertical-slice
     phase usually comes first.

## Rules

- Every acceptance criterion in the spec must be covered by at least one phase.
- Honor `rules.plan` in `config.yaml` (smallest verifiable slices).
- If `strict_tdd: true`, each phase's tasks should start with "write failing test".
- Stop after writing the plan. Show the phase overview and ask the user to confirm before
  building. Next step: the `sdd-build` skill, one phase at a time.
