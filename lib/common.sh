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
run() {
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '\033[2m  would run:\033[0m %s\n' "$*"
        return 0
    fi
    "$@"
}

# ── presence check ───────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command inside $PROJECT_DIR, honoring DRY_RUN (prints instead of running).
in_project() {
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '\033[2m  would run (in %s):\033[0m %s\n' "${PROJECT_NAME:-project}" "$*"
        return 0
    fi
    ( cd "$PROJECT_DIR" && "$@" )
}

# in_list <needle> <space-separated haystack> -> 0 if present, 1 otherwise
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ── package manager detection (macOS / Arch) ─────────────────────────────────
detect_pm() {
    if   have brew;   then echo brew
    elif have pacman; then echo pacman
    else echo none; fi
}

# Install a package by its manager-specific name. Args: brew_name pacman_name
pkg_install() {
    _pm="$(detect_pm)"
    case "$_pm" in
        brew)   run brew install "$1" ;;
        pacman) run sudo pacman -S --needed --noconfirm "$2" ;;
        none)   warn "no supported package manager (brew/pacman); install '$1' manually" ;;
    esac
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
