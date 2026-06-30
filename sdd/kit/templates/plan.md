# Plan — {{FEATURE}}

> Written by `sdd-plan` from `spec.md`. The work is sliced into the smallest phases that
> each ship something verifiable. `sdd-build` executes ONE phase at a time and ticks its
> tasks; `sdd-verify` checks the phase against its acceptance criteria. Mirrors the
> phased style of sprout's own PLAN.md (each phase carries a status bar).
>
> Each phase also carries **Agent** (who runs it — `claude` by default; single-agent unless
> you opt into multi-agent) and **Depends on** (phase numbers that must finish first). Those
> two fields drive the "waves" model: `sprout sdd waves <feature>` reads them to show what
> runs in parallel vs what waits, and `sprout sdd handoff <feature> <phase>` emits a
> self-contained brief to paste into that phase's agent. See `sdd-orchestrate`.

- **Spec:** ./spec.md
- **Status legend:** ░ todo · ▓ in progress · █ done

## Phase overview

```
Phase 1  ░░░░░░░░░░  <title>
Phase 2  ░░░░░░░░░░  <title>
```

---

## Phase 1 — <title>

- **Status:** ░ todo
- **Covers:** AC1 <!-- which acceptance criteria from the spec this phase satisfies -->
- **Deliverable:** <!-- what exists/works at the end of this phase -->
- **Verification:** <!-- how we'll know it works: which command + which AC -->
- **Agent:** claude <!-- any label from config.yaml orchestration.agents; default claude. Use one agent or many — your choice -->
- **Depends on:** — <!-- phase numbers that must finish first, e.g. "Phase 1, Phase 2"; "—" = none -->

### Tasks
- [ ] 
- [ ] 

---

## Phase 2 — <title>

- **Status:** ░ todo
- **Covers:** AC2
- **Deliverable:** 
- **Verification:** 
- **Agent:** claude
- **Depends on:** —

### Tasks
- [ ] 
- [ ] 
