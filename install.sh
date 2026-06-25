#!/bin/sh
# install.sh — assisted installer for sprout.
#   1. symlinks the `sprout` command into a bin dir on your PATH (~/.local/bin)
#   2. persists that dir in your shell rc (idempotent, marker-fenced) so the
#      command survives a new terminal
#   3. installs the missing core CLIs (Plane 1) via brew/pacman
#   4. verifies the result
# POSIX sh, no bashisms. Honors --dry-run.
set -e

# ── resolve own dir (install.sh lives next to `sprout`) ───────────────────────
SELF="$0"
while [ -L "$SELF" ]; do
    L="$(readlink "$SELF")"
    case "$L" in /*) SELF="$L" ;; *) SELF="$(dirname "$SELF")/$L" ;; esac
done
SPROUT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
export SPROUT_DIR

. "$SPROUT_DIR/lib/common.sh"

TAB="$(printf '\t')"

# ── defaults / flags ──────────────────────────────────────────────────────────
DRY_RUN=0
INSTALL_CLIS=1
BIN_DIR="$HOME/.local/bin"

MARK_BEGIN='# >>> sprout >>>'
MARK_END='# <<< sprout <<<'

usage() {
    cat <<EOF
install.sh — assisted installer for sprout.

Usage:
  ./install.sh [options]

Options:
  --bin-dir <dir>   where to symlink the sprout command (def: ~/.local/bin)
  --no-clis         do not install the core global CLIs (only wire the command)
  --dry-run         print every step, change nothing
  -h, --help        this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bin-dir) BIN_DIR="$2"; shift 2 ;;
        --no-clis) INSTALL_CLIS=0; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown option: $1"; usage; exit 1 ;;
    esac
done
export DRY_RUN

# append a block of text to a file, honoring dry-run (run() only wraps exec).
append_block() {  # <file>  (block on stdin)
    _f="$1"
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would append the sprout PATH block to $_f"
        cat >/dev/null
        return 0
    fi
    cat >> "$_f"
}

# ensure the marker-fenced PATH block exists in <rcfile> exactly once.
ensure_path_block() {  # <rcfile> <line-to-add>
    _rc="$1"; _line="$2"
    if [ -f "$_rc" ] && grep -qF "$MARK_BEGIN" "$_rc" 2>/dev/null; then
        ok "PATH already configured in $_rc"
        return 0
    fi
    [ -f "$_rc" ] || { [ "$DRY_RUN" = 1 ] && dim "  would create $_rc" || { mkdir -p "$(dirname "$_rc")"; : > "$_rc"; }; }
    say "adding $BIN_DIR to PATH in $_rc"
    printf '\n%s\n%s\n%s\n' "$MARK_BEGIN" "$_line" "$MARK_END" | append_block "$_rc"
}

# ── 1. symlink the command ────────────────────────────────────────────────────
head "sprout installer"
say "linking sprout into $BIN_DIR"
[ "$DRY_RUN" = 1 ] || mkdir -p "$BIN_DIR"
run ln -sf "$SPROUT_DIR/sprout" "$BIN_DIR/sprout"
ok "command: $BIN_DIR/sprout -> $SPROUT_DIR/sprout"

# ── 2. persist on PATH via shell rc ───────────────────────────────────────────
head "PATH"
POSIX_LINE="export PATH=\"$BIN_DIR:\$PATH\""
case "$(basename "${SHELL:-sh}")" in
    zsh)
        ensure_path_block "$HOME/.zshrc" "$POSIX_LINE" ;;
    bash)
        ensure_path_block "$HOME/.bashrc" "$POSIX_LINE"
        # macOS login shells source .bash_profile, not .bashrc
        [ "$(uname)" = Darwin ] && ensure_path_block "$HOME/.bash_profile" "$POSIX_LINE" ;;
    fish)
        ensure_path_block "$HOME/.config/fish/config.fish" "fish_add_path \"$BIN_DIR\"" ;;
    *)
        warn "unrecognized shell '${SHELL:-?}' — adding to ~/.profile"
        ensure_path_block "$HOME/.profile" "$POSIX_LINE" ;;
esac

# ── 3. install missing core CLIs (Plane 1) ────────────────────────────────────
if [ "$INSTALL_CLIS" = 1 ]; then
    head "core CLIs (global)"
    if [ "$(detect_pm)" = none ]; then
        warn "no brew/pacman found — skipping CLI install (see README for manual steps)"
    else
        while IFS="$TAB" read -r name brew pac phase types desc; do
            case "$name" in ''|\#*|name) continue ;; esac
            echo "$types" | tr ',' '\n' | grep -qx core 2>/dev/null || continue
            if have "$name"; then ok "present: $name"
            else say "installing $name"; pkg_install "$brew" "$pac"; fi
        done < "$SPROUT_DIR/clis/manifest.tsv"
    fi
else
    dim "skipping core CLI install (--no-clis)"
fi

# ── 4. verify ─────────────────────────────────────────────────────────────────
head "verify"
if [ "$DRY_RUN" = 1 ]; then
    dim "  dry-run: nothing was changed"
elif [ -x "$BIN_DIR/sprout" ]; then
    ok "installed: $("$BIN_DIR/sprout" --version 2>/dev/null || echo sprout)"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ok "$BIN_DIR is already on PATH in this shell" ;;
        *)              warn "open a new terminal (or run: exec \"\$SHELL\" -l) so 'sprout' is on PATH" ;;
    esac
    dim "  next: sprout doctor"
else
    err "something went wrong — $BIN_DIR/sprout is not executable"
    exit 1
fi
