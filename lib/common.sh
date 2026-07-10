# common.sh — shared helpers for sprout: logging, dry-run, package managers, paths.
# Sourced by `sprout` and the recipes. POSIX sh, no bashisms.

# ── logging ─────────────────────────────────────────────────────────────────
say()  { printf '\033[1;35m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31m   x\033[0m %s\n' "$1" >&2; }
head() { printf '\n\033[1;36m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

# ── dry-run aware command runner ─────────────────────────────────────────────
# Usage: run cmd arg...   Honors DRY_RUN=1 (prints instead of executing).
# Scaffold sub-commands always read stdin from /dev/null so they run
# non-interactively: launched from the wizard, stdin is the terminal, and
# scaffolders (pnpm create vite, create-astro, pnpm install, laravel new, …)
# would otherwise draw their own prompt, block on it, and — under `set -e` —
# abort the whole pipeline. The wizard already collected every choice, so these
# must never prompt. Interactive prompts (pick_one/ask_yn) read /dev/tty or
# stdin directly, not through these runners, so this redirect is safe.
run() {
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '\033[2m  would run:\033[0m %s\n' "$*"
        return 0
    fi
    "$@" </dev/null
}

# ── presence check ───────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command inside $PROJECT_DIR, honoring DRY_RUN (prints instead of running).
in_project() {
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '\033[2m  would run (in %s):\033[0m %s\n' "${PROJECT_NAME:-project}" "$*"
        return 0
    fi
    ( cd "$PROJECT_DIR" && "$@" </dev/null )
}

# Run a command inside an explicit <dir>, honoring DRY_RUN. Like in_project but for
# a directory the caller names (e.g. a monorepo subpackage such as api/).
in_dir() {
    _d="$1"; shift
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '\033[2m  would run (in %s):\033[0m %s\n' "${_d##*/}" "$*"
        return 0
    fi
    ( cd "$_d" && "$@" </dev/null )
}

# in_list <needle> <space-separated haystack> -> 0 if present, 1 otherwise
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ── package manager detection (macOS / Arch / Debian / Fedora / openSUSE) ────
detect_pm() {
    if   have brew;    then echo brew
    elif have pacman;  then echo pacman
    elif have apt-get; then echo apt
    elif have dnf;     then echo dnf
    elif have zypper;  then echo zypper
    else echo none; fi
}

# Install a package by its manager-specific name.
# Args: brew_name pacman_name apt_name dnf_name zypper_name
# A `-` (or empty) name means "not packaged for this manager" → manual-install hint.
# Cross-manager npm-global CLIs use an `npm:<pkg>` spec in all columns; they install
# via `npm install -g <pkg>` regardless of the system package manager.
pkg_install() {
    case "$1" in
        npm:*)
            if have npm; then run npm install -g "${1#npm:}"
            else warn "npm not found — install Node.js, then: npm install -g ${1#npm:}"; fi
            return ;;
    esac
    _pm="$(detect_pm)"
    case "$_pm" in
        brew)   _p="$1" ;;
        pacman) _p="$2" ;;
        apt)    _p="$3" ;;
        dnf)    _p="$4" ;;
        zypper) _p="$5" ;;
        none)   warn "no supported package manager (brew/pacman/apt/dnf/zypper); install '$1' manually"; return ;;
    esac
    case "$_p" in
        ''|-) warn "'$1' has no $_pm package — install it manually" ;;
        *)
            case "$_pm" in
                brew)   run brew install "$_p" ;;
                pacman) run sudo pacman -S --needed --noconfirm "$_p" ;;
                apt)    run sudo apt-get install -y "$_p" ;;
                dnf)    run sudo dnf install -y "$_p" ;;
                zypper) run sudo zypper install -y "$_p" ;;
            esac ;;
    esac
}

# link_alias <cmd> — some distros ship a tool under a different binary name (Debian:
# fd→fdfind, bat→batcat), so it's installed but not usable under the expected command.
# Symlink the real binary to <cmd> in ~/.local/bin so the normal name works.
# Returns 0 only if it actually linked (or would, in dry-run); 1 when there's nothing to do.
link_alias() {
    case "$1" in
        fd)  _alt=fdfind ;;
        bat) _alt=batcat ;;
        *)   return 1 ;;
    esac
    have "$_alt" || return 1
    _bin="${BIN_DIR:-$HOME/.local/bin}"
    if [ "${DRY_RUN:-0}" = 1 ]; then dim "  would link $1 -> $_alt in $_bin"; return 0; fi
    mkdir -p "$_bin"
    ln -sf "$(command -v "$_alt")" "$_bin/$1" || return 1
    ok "linked $1 -> $_alt ($_bin/$1)"
    case ":$PATH:" in *":$_bin:"*) ;; *) warn "$_bin not on PATH — add it so '$1' works in new shells" ;; esac
    return 0
}

# ── JS package manager (pnpm/npm/yarn/bun) abstraction ───────────────────────
# These are PROJECT package managers (run inside the generated project), distinct
# from the system pkg manager above (brew/pacman) that installs global CLIs.

# default_pm_js -> first installed JS pm, preferring pnpm; falls back to npm.
default_pm_js() {
    for _p in pnpm npm yarn bun; do have "$_p" && { echo "$_p"; return 0; }; done
    echo npm
}

# pm_dlx <pm> — prefix to run a package's binary without a global install (npx-like)
pm_dlx() {
    case "$1" in
        pnpm) echo "pnpm dlx" ;;
        yarn) echo "yarn dlx" ;;
        bun)  echo "bunx" ;;
        *)    echo "npx --yes" ;;
    esac
}

# pm_exec <pm> — prefix to run a binary already installed in the project
pm_exec() {
    case "$1" in
        pnpm) echo "pnpm exec" ;;
        yarn) echo "yarn" ;;
        bun)  echo "bun x" ;;
        *)    echo "npx" ;;
    esac
}

# pm_add <pm> — command to add a dev dependency (append package names)
pm_add() {
    case "$1" in
        pnpm) echo "pnpm add -D" ;;
        yarn) echo "yarn add -D" ;;
        bun)  echo "bun add -d" ;;
        *)    echo "npm install -D" ;;
    esac
}

# pm_create <create-pkg> <name> <flags...> — run `<PM> create <pkg> <name> [-- ]<flags>`.
# npm needs the `--` separator before the create script's own flags; the others don't.
# Uses the global $PM and the `run` wrapper (so it honours DRY_RUN).
pm_create() {
    _pkg="$1"; _name="$2"; shift 2
    # shellcheck disable=SC2068
    case "$PM" in
        npm)  run npm  create "$_pkg" "$_name" -- "$@" ;;
        pnpm) run pnpm create "$_pkg" "$_name"    "$@" ;;
        yarn) run yarn create "$_pkg" "$_name"    "$@" ;;
        bun)  run bun  create "$_pkg" "$_name"    "$@" ;;
        *)    run npm  create "$_pkg" "$_name" -- "$@" ;;
    esac
}

# pm_install <pm> — command to install all declared dependencies
pm_install()     { case "$1" in yarn) echo yarn ;; *) echo "$1 install" ;; esac; }

# pm_runtime_add <pm> — command to add a runtime (non-dev) dependency
pm_runtime_add() { case "$1" in pnpm) echo "pnpm add" ;; yarn) echo "yarn add" ;; bun) echo "bun add" ;; *) echo "npm install" ;; esac; }

# ensure_pm <pm> — make a JS package manager available (best effort).
# pnpm/yarn ship via Corepack (bundled with Node); bun via brew/pacman.
ensure_pm() {
    have "$1" && return 0
    case "$1" in
        bun)
            pkg_install bun bun ;;
        pnpm|yarn)
            if have corepack; then
                run corepack enable >/dev/null 2>&1 || true
                run corepack prepare "$1@latest" --activate || warn "corepack could not provision $1"
            elif have npm; then
                run npm install -g "$1"
            else
                warn "cannot install $1 automatically — install it manually"
            fi ;;
        npm)
            warn "npm ships with Node.js — install Node to get it" ;;
        *)
            warn "unknown package manager: $1" ;;
    esac
}

# ── filesystem helpers ───────────────────────────────────────────────────────
# resolve_self <path-to-$0> -> prints the real directory, following symlinks.
resolve_self() {
    _s="$1"
    while [ -L "$_s" ]; do
        _l="$(readlink "$_s")"
        case "$_l" in
            /*) _s="$_l" ;;
            *)  _s="$(dirname "$_s")/$_l" ;;
        esac
    done
    cd "$(dirname "$_s")" && pwd
}

# Read one space-separated list from a set file, skipping comments/blanks.
read_list() {
    [ -f "$1" ] || return 0
    sed -e 's/#.*$//' "$1" | tr '\n' ' ' | tr -s ' '
}

# ── SDD markdown helpers (used by `sprout sdd handoff|waves`) ─────────────────
# extract_md_section <file> <start-regex> — print from the first line matching
# <start-regex> up to (but not including) the next top-level boundary (a `## ` heading
# or a `---` rule). Lets us pull one `## Section` (or one `## Phase N` block) verbatim
# from our own templated spec.md / plan.md.
extract_md_section() {
    awk -v re="$2" '
        !grab && $0 ~ re { grab=1; print; next }
        grab && (/^## / || /^---[[:space:]]*$/) { exit }
        grab { print }
    ' "$1"
}
