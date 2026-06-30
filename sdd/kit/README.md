# SDD kit — spec-driven development for this project

This folder is sprout's **process plane**: an editable spec brief, templates, and a config
the agent reads to take a feature from idea → spec → phased plan → build → verify. It's all
markdown/yaml — nothing here is parsed by a tool; the SDD skills (vendored in `../skills/`)
read these files. Single-agent by default (no subagent fan-out).

## The flow

```
1. sprout sdd spec new <feature>    ← scaffolds specs/<feature>/brief.md from the template
2. edit   specs/<feature>/brief.md  ← write the brief (goal, users, acceptance criteria)
3. "draft the spec"   → sdd-spec    ← asks what's missing, writes specs/<feature>/spec.md
4. "plan it"          → sdd-plan    ← slices the spec into phases  → specs/<feature>/plan.md
5. "build phase 1"    → sdd-build   ← implements ONE phase, ticks its tasks (TDD if enabled)
6. "verify"           → sdd-verify  ← runs the checks + checks each acceptance criterion
   ↳ repeat 5–6 per phase until the plan is done
```

`spec.prompt.md` at the root is the template `sprout sdd spec new` copies from (and the
fallback if you'd rather keep a single global brief instead of one per feature).

The agent reaches for each skill automatically via the **Auto-invoke Skills** table in
`AGENTS.md` — you just describe what you want ("draft the spec", "build the next phase").

## Multi-agent (opt-in): waves

Single-agent is the default. The agent roster is **yours to choose** — list one, two, or as
many agents as you like in `config.yaml` `orchestration.agents` under any names (sprout never
invokes them; dispatch is manual). To split a feature across agents (e.g. `claude` plans +
reviews, `gemini` does frontend, `minimax` does backend — but use whatever set fits), assign
each phase an **Agent** and **Depends on** in `plan.md` (sdd-plan fills these), fill the
spec's **Contract**, then:

```
sprout sdd waves <feature>            ← shows the execution waves: what runs in parallel ║, what waits
sprout sdd handoff <feature> <phase>  ← writes specs/<feature>/handoffs/phase-<n>.md (self-contained brief)
"orchestrate <feature>"  → sdd-orchestrate   ← runs the wave loop: brief → dispatch → review per phase
```

The rule: freeze the **Contract** before any parallel wave; phases in a wave run in parallel
only if independent at the file level. Dispatch is manual — you open each agent and paste its
brief. Review (`sdd-verify`) stays single-brain (claude).

## Files

```
sdd/
├── config.yaml          ← context, commands, strict_tdd, rules, orchestration (agents roster)
├── spec.prompt.md       ← brief template (source for `sprout sdd spec new`; or a global brief)
├── templates/
│   ├── spec.md          ← shape of a spec (incl. Contract for front/back boundaries)
│   └── plan.md          ← shape of a phased plan (each phase: Agent + Depends on)
└── specs/<feature>/     ← per feature: brief.md + spec.md + plan.md + handoffs/phase-<n>.md
```

## First time

Open `config.yaml` and fill in the `commands:` (test/lint/build) and `context:` for this
repo — that's what makes `sdd-build` and `sdd-verify` actually run your checks. If you ran
`sprout sdd init`, some of it was detected for you; review it.
