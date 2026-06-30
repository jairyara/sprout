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

## Files

```
sdd/
├── config.yaml          ← stack context, test/lint/build commands, strict_tdd, rules
├── spec.prompt.md       ← brief template (source for `sprout sdd spec new`; or a global brief)
├── templates/
│   ├── spec.md          ← shape of a spec
│   └── plan.md          ← shape of a phased plan
└── specs/<feature>/     ← created per feature: brief.md + spec.md + plan.md live here
```

## First time

Open `config.yaml` and fill in the `commands:` (test/lint/build) and `context:` for this
repo — that's what makes `sdd-build` and `sdd-verify` actually run your checks. If you ran
`sprout sdd init`, some of it was detected for you; review it.
