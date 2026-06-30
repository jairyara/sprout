---
name: sdd-orchestrate
description: Coordinate a multi-agent build across phases using the waves model (opt-in).
metadata:
  scope: sdd
  auto_invoke: "coordinating a multi-agent build across phases or waves"
---

# sdd-orchestrate

Use this to drive a **multi-agent** build of a planned feature: route each phase to its
agent and run the phases in dependency-ordered **waves** (independent phases in a wave run
in parallel; dependent phases wait for the previous wave). This is **opt-in** — single-agent
projects just use `sdd-build` phase by phase and ignore this.

The roster is **agnostic**: it's whatever the user listed in `config.yaml`
`orchestration.agents` — one agent, two, or many, under any names. Work with that roster as
given; never assume a specific set (no fixed "claude + gemini + minimax", no fixed front/back
split). If the roster has a single agent, this collapses to the normal single-agent flow.

Sprout does NOT auto-dispatch to other CLIs: the artifact is the API between agents and the
dispatch is **manual**, with you (the human) in the loop. This skill prepares the briefs and
tells you what to run when; you open each agent and paste its brief.

## Preconditions

- `plan.md` exists with each phase's **Agent** and **Depends on** filled (see `sdd-plan`).
- If any wave runs phases in parallel across a front/back or service boundary, the spec's
  **Contract** is filled and frozen, and the Contract-freezing phase is its own first wave.

## Steps

1. Read `sdd/config.yaml`, the feature's `spec.md` and `plan.md`. Confirm the feature with
   the user if there are several.
2. Compute the waves: run `sprout sdd waves <feature>` (or derive them yourself from each
   phase's `Depends on:`). Show the user the wave plan — which phases run together, which
   wait, and which agent owns each.
3. **Freeze the Contract first.** If a parallel wave depends on the Contract, make sure that
   phase is done and the Contract in `spec.md` is stable before fanning out. Never start a
   parallel wave against an unfrozen Contract.
4. For each phase in the current wave, generate its brief:
   `sprout sdd handoff <feature> <phase>` → `sdd/specs/<feature>/handoffs/phase-<n>.md`.
   Tell the user to open each phase's agent and paste **only that phase's brief**.
   - If a phase's agent is `claude` and that's you, you may implement it directly with
     `sdd-build` instead of pasting into a separate session.
5. As each phase comes back, **review it against its acceptance criteria** with `sdd-verify`
   (review is single-brain — `claude` — even when other agents wrote the code). Mark the
   phase `█ done` in `plan.md`. Don't advance the wave until each phase in it passes.
6. Move to the next wave and repeat from step 4. After the last wave, run `sdd-verify` on the
   whole feature.

## Rules

- Honor `rules.orchestrate` in `config.yaml`. One brain plans and reviews; the others code.
- A wave only runs in parallel if its phases are independent **at the file level** (no shared
  files) and share a frozen Contract. If not, serialize them.
- Each brief is self-contained and scoped: the target agent does ONLY its phase. Don't hand
  an agent the whole plan and trust it to filter — hand it only its `handoff/phase-<n>.md`.
- Manual dispatch: don't try to invoke other agents' CLIs from here. Prepare, instruct, wait,
  review.
