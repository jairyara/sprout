 # Skill registry — intake

Fill in the blanks below. Once done, I (or `sprout`) regenerate `skills/registry.tsv`
from this file. One block per skill. Leave a block as-is if you don't have the info yet —
unfinished skills are skipped with a warning, they don't break scaffolding.

## Source strategy — prefer `git`, fall back to `skillsh`

**Default to `git`.** sprout clones the repo, pins the exact commit in `skills.lock`,
and caches it for offline reuse — full reproducibility, and no Node needed at scaffold
time. Use `skillsh` only for a skill that is *not* available as a plain git repo.

A skills.sh command like

```
npx skills add https://github.com/anthropics/skills --skill frontend-design
```

is just a wrapper that clones that repo and copies `skills/frontend-design/`. Record it
as a **git** source instead — same result, but pinned and offline-friendly:

```
git:https://github.com/anthropics/skills#skills/frontend-design
```

> Rule of thumb: `npx skills add <url> --skill <name>`  ⟶  `git:<url>#skills/<name>`
> (the standard layout of skills repos is `skills/<name>/SKILL.md`).

| | `git` (sprout resolver) | `skillsh` (`npx skills add`) |
|---|---|---|
| version pin | exact SHA in `skills.lock` | repo's latest, not pinned |
| offline | cached, reusable | re-fetches each time |
| dependencies | `git` only | Node + `npx` + network |
| non-JS projects | works | needs Node toolchain |

## Skills that document a CLI (two-plane tools)

Some skills exist to teach the agent how to drive a command-line tool (e.g.
`webapp-testing` documents **playwright**). The skill and the binary are two separate
planes, pinned independently — don't conflate them:

- **the binary** — where the tool comes from. Either `global` (a row in
  `clis/manifest.tsv`, installed via brew/pacman) or `project` (a devDependency
  installed by the package manager, pinned in `package.json`). Playwright is `project`:
  the project-pinned `@playwright/test` is the source of truth; a global install is just
  ad-hoc convenience.
- **the skill** — the `SKILL.md` (patterns, commands, gotchas), vendored from the
  registry and pinned in `skills.lock`.

Use the new **pairs with CLI** field below to record the binary a skill documents. It's
purely informational (links the planes for docs); it does not couple their versions.

## What each field means

- **name** — unique id (kebab-case). Must match the folder created and `sets/*.list`. Fixed.
- **source type** — one of: `git` · `skillsh` · `other`. Prefer `git` (see above).
- **git url** — clone URL, e.g. `https://github.com/owner/repo`.
- **subpath** — folder *inside* the repo that contains the skill's `SKILL.md`
  (leave empty if the `SKILL.md` is at the repo root).
- **skill file** — only if the file is NOT named `SKILL.md` (e.g. impeccable ships
  `skill/SKILL.src.md`). Tell me the real path and I'll handle the rename on vendor.
- **ref** — tag / branch / commit to pin. Default `main`. Use a tag like `v1.2.0` to freeze.
- **skills.sh command** — only for `source type: skillsh`. Paste the exact install command
  (e.g. `npx skills add <url> --skill <name>`). Prefer converting it to a `git` source.
- **scope** — `core` | `web` | `fullstack` | … (when it applies). Already set, change if wrong.
- **auto_invoke** — short trigger phrase shown in the AGENTS.md table. Already drafted, edit freely.
- **pairs with CLI** — optional. If this skill documents a CLI, write `<cli> (<global|project>)`,
  e.g. `playwright (project)`. Leave empty for pure-knowledge skills.

### Resulting registry.tsv source string (for reference)

- git:    `git:<url>#<subpath>`   (omit `#<subpath>` if root)
- skillsh: `skillsh:<owner>/<id>`
- not ready yet: leave `source type:` blank or write `TODO`

---

## CORE skills (every project)

### systematic-debugging
- source type: `git`
- git url: `https://github.com/obra/superpowers`
- subpath: `skills/systematic-debugging`
- skill file: (default SKILL.md)
- ref: `main`
- scope: `core`
- auto_invoke: `debugging a bug or unexpected behavior`

### brainstorming
- source type: `git`
- git url: `https://github.com/obra/superpowers`
- subpath: `skills/brainstorming`
- skill file: (default SKILL.md)
- ref: `main`
- scope: `core`
- auto_invoke: `exploring ideas or scoping a feature`

### conventional-commits
- source type: `git`
- git url: `https://github.com/github/awesome-copilot` 
- subpath: `skills/conventional-commit`
- skill file: (default SKILL.md)
- ref: `main`
- scope: `core`
- auto_invoke: `writing a commit or opening a PR`

### prompt-engineering
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/wshobson/agents --skill prompt-engineering-patterns`
- ref: `latest`
- scope: `core`
- auto_invoke: `writing prompts for an agent or model`

---

## WEB skills

### frontend-design
- source type: `git`
- git url: `https://github.com/anthropics/skills`
- subpath: `skills/frontend-design`   
- skill file: (default SKILL.md)
- ref: `main`
- scope: `web`
- auto_invoke: `creating or editing UI components`
- pairs with CLI: (none)

### webapp-testing
- source type: `git`   
- git url: `https://github.com/anthropics/skills`
- subpath: `skills/webapp-testing`  
- skill file: (default SKILL.md)
- ref: `main`
- scope: `web`
- auto_invoke: `writing or running browser / e2e tests`
- pairs with CLI: `playwright (project)`   

### interface-design
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/dammyjay93/interface-design --skill interface-design` 
- ref: `latest`
- scope: `web`
- auto_invoke: `designing screens, layout or interaction`

### impeccable
- source type: `git`
- git url: `https://github.com/pbakaus/impeccable`
- subpath: `skill`
- skill file: `skill/SKILL.src.md`   
- ref: `main`
- scope: `web`
- auto_invoke: `polishing visual design, styles, spacing`

### vercel-react-best-practices
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/vercel-labs/agent-skills --skill vercel-react-best-practices` 
- ref: `latest`
- scope: `web`
- auto_invoke: `writing React in a Next.js/Vercel app`

### accessibility
- source type:  `skillsh`
- skills.sh command: `npx skills add https://github.com/addyosmani/web-quality-skills --skill accessibility` 
- ref: `latest`
- scope: `web`
- auto_invoke: `checking a11y, semantics or ARIA`

### taste
- source type: `git`  
- git url: `https://github.com/Leonxlnx/taste-skill`
- subpath: `skills/taste-skill`  
- skill file: (default SKILL.md)
- ref: `main`
- scope: `web`
- auto_invoke: `applying refined frontend design taste`
- pairs with CLI: (none)

### webgpu
- source type: `git`   
- git url: `https://github.com/dgreenheck/webgpu-claude-skill`
- subpath: `skills/webgpu-threejs-tsl`
- skill file: (default SKILL.md)
- ref: `main`
- scope: `web`   
- auto_invoke: `writing WebGPU / Three.js TSL shaders`
- pairs with CLI: (none)

### ui-ux-pro-max
- source type: `skillsh`   
- skills.sh command: `npx skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max`
- ref: `latest`
- scope: `web`
- auto_invoke: `high-end UI/UX design intelligence`
- pairs with CLI: (none)




---

## FULLSTACK skills

### api-design-principles
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/wshobson/agents --skill api-design-principles`
- ref: `latest`
- scope: `fullstack`
- auto_invoke: `designing an HTTP endpoint or API`

### error-handling-patterns
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/wshobson/agents --skill error-handling-patterns`
- ref: `latest`
- scope: `fullstack`
- auto_invoke: `handling errors or failure paths`

### postgresql
- source type: `skillsh`
- git url: `npx skills add https://github.com/wshobson/agents --skill postgresql-table-design` 
- ref: `latest`
- scope: `fullstack`
- auto_invoke: `writing SQL or schema for PostgreSQL`

### changelog-generator
- source type: `skillsh`
- skills.sh command: `npx skills add https://github.com/composiohq/awesome-claude-skills --skill changelog-generator` 
- ref: `latest`
- scope: `fullstack`
- auto_invoke: `generating a changelog or release notes`

---

## Add more skills below (copy a block)

### <skill-name>
- source type: ____________   (prefer `git`)
- git url / skills.sh command: ____________
- subpath: ____________
- skill file: ____________
- ref: `main`
- scope: ____________
- auto_invoke: `____________`
- pairs with CLI: ____________   (e.g. `playwright (project)`, or leave empty)

---

## Notes / open questions for me

- If a repo uses a non-standard skill filename (like impeccable's `SKILL.src.md`),
  I'll teach `resolve.sh` to copy it as `SKILL.md` in the vendored project.
- `skills.sh` sources are now wired: `resolve.sh` runs `npx skills add <url> --skill
  <id> --copy` in a temp dir, lifts the canonical `.agents/skills/<id>` copy into
  `skills/<name>`, and pins the CLI's `computedHash` in `skills.lock`. Needs Node/npx.
