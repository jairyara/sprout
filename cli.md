# CLI catalog 🛠️

What every command-line tool in sprout is for, when you'd reach for it, and how to
run it. Two groups: **global system CLIs** (installed once on your machine, Plane 1)
and **project-level dev tools** (installed per project by your package manager).

> Why the split? A global CLI like `rg` is one binary on your `PATH` you use across
> every repo. A tool like `playwright` is a project dependency pinned in each repo's
> `package.json` — installing it "globally" is an anti-pattern (version drift, no
> reproducibility). sprout used to list playwright as global; that was the bug behind
> the false "playwright missing" warning. It now lives in the project, not on `PATH`.

---

## Plane 1 · Global system CLIs (`clis/manifest.tsv`)

Installed via `brew` (macOS) / `pacman` (Arch). sprout checks presence and offers to
install the missing ones. These are the **core** set — every project gets them.

| CLI | Phase | What it is / does | Typical use |
|---|---|---|---|
| **rg** (ripgrep) | scaffold | Ultra-fast recursive text search; respects `.gitignore`. Drop-in `grep` replacement. | `rg "useState" src/` — find every usage in milliseconds. |
| **fd** | scaffold | Fast, friendly `find` replacement; intuitive syntax, ignores VCS noise. | `fd .tsx src` — list all `.tsx` files. |
| **fzf** | scaffold | Interactive fuzzy finder; pipe anything in, filter by typing. | `git branch \| fzf` to pick a branch; `Ctrl-R` fuzzy history. |
| **bat** | scaffold | `cat` with syntax highlighting, line numbers, git gutter. | `bat src/index.ts` — read a file with colors. |
| **jq** | build | Command-line JSON processor: query, filter, transform JSON. | `cat pkg.json \| jq .dependencies`. |
| **yq** | build | Like `jq`, but for YAML (and TOML/XML). | `yq '.services.web.image' compose.yml`. |
| **gh** | ship | Official GitHub CLI: PRs, issues, releases, repo ops from the terminal. Feeds the commit/PR skills. | `gh pr create`, `gh pr view --web`. |
| **delta** | review | Syntax-highlighted, side-by-side `git diff` pager. | Set as git's pager; `git diff` becomes readable. |
| **lazygit** | ship | Full-screen terminal UI for git: stage, commit, branch, rebase visually. | Run `lazygit` in a repo. |
| **just** | build | Command runner (a saner `make`): define recipes in a `justfile`. | `just build`, `just test`. |
| **gitleaks** | review | Scans the repo/history for hardcoded secrets (keys, tokens). | `gitleaks detect` before pushing. |

**Install all missing at once:** `sprout web my-site --install-clis`
**Pick which to install:** run the wizard (`sprout`) → CLI step → space to toggle.
**Just check what's present:** `sprout doctor`.

---

## JS package managers (you pick one per project)

sprout asks which one to use and drives the scaffolder with it. Default: **pnpm** if
installed, else npm. Pass `--pm pnpm|npm|yarn|bun` to set it non-interactively.

| PM | What it is | Why pick it |
|---|---|---|
| **pnpm** | Fast, disk-efficient (content-addressed store, hard links); strict by default. | Saves disk across projects, catches phantom-dependency bugs. The project default. |
| **npm** | The default that ships with Node. | Zero extra install; maximum compatibility. |
| **yarn** | Alternative manager; Berry (v2+) adds PnP and workspaces features. | Team already on yarn / yarn-specific workflows. |
| **bun** | All-in-one runtime + package manager + bundler; very fast installs. | Bleeding-edge speed; using Bun as the runtime too. |

How sprout maps them (see `lib/common.sh`):

| Action | pnpm | npm | yarn | bun |
|---|---|---|---|---|
| run a one-off binary (`npx`-like) | `pnpm dlx` | `npx --yes` | `yarn dlx` | `bunx` |
| run a project-local binary | `pnpm exec` | `npx` | `yarn` | `bun x` |
| add a dev dependency | `pnpm add -D` | `npm install -D` | `yarn add -D` | `bun add -d` |

---

## Project-level dev tools (NOT global — installed by your PM)

These belong in each project's `devDependencies`, pinned and reproducible. You run
them through your package manager, never as a bare global command. This is why
`command -v playwright` finds nothing even when you "have" it — it lives inside a
project's `node_modules`, invoked via `pnpm exec playwright` / `npx playwright`.

| Tool | What it is / does | How to add & run (pnpm example) |
|---|---|---|
| **playwright** | End-to-end browser testing: drive Chromium/Firefox/WebKit, assert on real pages, record traces. Also a CLI for codegen and running tests. | `pnpm add -D @playwright/test` → `pnpm exec playwright install` (downloads browsers, one-time) → `pnpm exec playwright test`. Generate tests by recording: `pnpm exec playwright codegen example.com`. |
| **biome** | Fast all-in-one linter + formatter (Rust); replaces ESLint + Prettier for most setups. | `pnpm add -D --save-exact @biomejs/biome` → `pnpm exec biome check --write .`. |
| **bun** | Listed above as a package manager, but also a JS/TS runtime and test runner. Optional — only if you want it as your stack's runtime. | Install once globally (`brew install bun`) if you want it; otherwise skip. |

> New to playwright? The fastest way to learn it: scaffold a project, then run
> `pnpm exec playwright codegen <your-url>` — it opens a browser, you click around,
> and it writes the test code for you. That's the usual entry point.

### One-off npx generators (no install)

Some tools are run on demand via `npx`, never installed or pinned — you invoke them
when you want output, and they leave nothing behind in your dependencies.

| Tool | What it is / does | How to run |
|---|---|---|
| **skillui** | UI generator (`amaancoderx/npxskillui`) — scaffolds UI components on demand. Not an Agent Skill (no `SKILL.md`) and not a dependency. | `npx skillui` — generates UI; nothing added to the project. |

---

## Where each piece is defined

- Global CLIs and their brew/pacman package names → `clis/manifest.tsv`
- Package-manager abstraction (dlx/exec/add helpers) → `lib/common.sh`
- Which tools a project type pulls in → the web recipe `recipes/web.sh` + `sets/`
- This catalog → `cli.md` (keep it in sync when you add a tool)
