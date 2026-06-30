# cli.sh — recipe for command-line tools (and dev utilities like sprout/divvy).
# Stacks (--stack):
#   sh    posix sh  — self-scaffolded: main script + lib/common.sh + install.sh (default)
#   rust  cargo + clap (single binary)
#   go    go mod + cobra (single binary)
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK AGENTS_SEL SKILLS_SEL DRY_RUN GIT_INIT
# (no JS package manager — these are not JS projects)

# ── interactive stack questions (wizard only) ─────────────────────────────────
recipe_configure() {
    head "configure your CLI tool"
    STACK="$(pick_one '1 · language' 'sh' "$(printf '%s\n' \
        'sh|posix sh  — script + lib/ + install.sh (like sprout/divvy)' \
        'rust|rust     — cargo + clap (single binary)' \
        'go|go       — go mod + cobra (single binary)')")"
    if ask_yn '2 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
}

# ── helpers ───────────────────────────────────────────────────────────────────
# _emit <dest>  — write a heredoc (on stdin) to <dest>, substituting __NAME__ with the
# project name. Use a QUOTED heredoc so $VERSION etc. stay literal; only __NAME__ is filled.
_emit() { sed "s|__NAME__|$PROJECT_NAME|g" > "$1"; }

_cli_stack_label() {
    case "$STACK" in
        sh)   echo "posix sh" ;;
        rust) echo "rust (clap)" ;;
        go)   echo "go (cobra)" ;;
        *)    echo "$STACK" ;;
    esac
}

# ── scaffolds ───────────────────────────────────────────────────────────────────
_cli_scaffold_sh() {
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would self-scaffold posix-sh CLI: $PROJECT_NAME + lib/common.sh + install.sh"
        return 0
    fi
    mkdir -p "$PROJECT_DIR/lib"

    _emit "$PROJECT_DIR/$PROJECT_NAME" <<'EOF'
#!/bin/sh
# __NAME__ — TODO: one-line description. POSIX sh, no bashisms.
set -e

# resolve real dir (follow symlinks) so lib/ loads from the install location
SELF="$0"
while [ -L "$SELF" ]; do
    L="$(readlink "$SELF")"
    case "$L" in /*) SELF="$L" ;; *) SELF="$(dirname "$SELF")/$L" ;; esac
done
APP_DIR="$(cd "$(dirname "$SELF")" && pwd)"
. "$APP_DIR/lib/common.sh"

VERSION="0.1.0"

usage() {
    cat <<USAGE
__NAME__ $VERSION — TODO: what it does.

Usage:
  __NAME__ <command> [options]

Commands:
  hello [name]      print a greeting
  version           print version
  help              this help
USAGE
}

cmd_hello() { say "hello, ${1:-world}"; }

case "${1:-help}" in
    hello)              shift; cmd_hello "$@" ;;
    version|--version)  echo "__NAME__ $VERSION" ;;
    help|-h|--help)     usage ;;
    *)                  err "unknown command: $1"; usage; exit 1 ;;
esac
EOF
    chmod +x "$PROJECT_DIR/$PROJECT_NAME"

    _emit "$PROJECT_DIR/lib/common.sh" <<'EOF'
# common.sh — shared helpers for __NAME__: logging + presence check. POSIX sh.
say()  { printf '\033[1;35m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31m   x\033[0m %s\n' "$1" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
EOF

    _emit "$PROJECT_DIR/install.sh" <<'EOF'
#!/bin/sh
# install.sh — symlink __NAME__ into a bin dir on your PATH (default: ~/.local/bin).
set -e
NAME="__NAME__"
SRC="$(cd "$(dirname "$0")" && pwd)/$NAME"
BIN="${BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN"
ln -sf "$SRC" "$BIN/$NAME"
echo "linked $BIN/$NAME -> $SRC"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: add $BIN to your PATH" ;; esac
EOF
    chmod +x "$PROJECT_DIR/install.sh"
    ok "scaffolded posix-sh CLI ($PROJECT_NAME + lib/common.sh + install.sh)"
}

_cli_scaffold_rust() {
    if ! have cargo; then
        warn "cargo not found — install Rust via rustup.rs; creating an empty dir for now"
        run mkdir -p "$PROJECT_DIR"; return 0
    fi
    run cargo new "$PROJECT_NAME" --bin
    in_project cargo add clap --features derive
    if [ "$DRY_RUN" != 1 ]; then
        _emit "$PROJECT_DIR/src/main.rs" <<'EOF'
use clap::{Parser, Subcommand};

/// TODO: describe __NAME__.
#[derive(Parser)]
#[command(name = "__NAME__", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Print a greeting
    Hello { name: Option<String> },
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Commands::Hello { name } => {
            println!("hello, {}", name.unwrap_or_else(|| "world".into()));
        }
    }
}
EOF
        ok "wrote src/main.rs (clap skeleton)"
    fi
}

_cli_scaffold_go() {
    if ! have go; then
        warn "go not found — install Go (go.dev); creating an empty dir for now"
        run mkdir -p "$PROJECT_DIR"; return 0
    fi
    run mkdir -p "$PROJECT_DIR"
    in_project go mod init "$PROJECT_NAME"
    in_project go get github.com/spf13/cobra@latest
    if [ "$DRY_RUN" != 1 ]; then
        mkdir -p "$PROJECT_DIR/cmd"
        _emit "$PROJECT_DIR/main.go" <<'EOF'
package main

import "__NAME__/cmd"

func main() {
	cmd.Execute()
}
EOF
        _emit "$PROJECT_DIR/cmd/root.go" <<'EOF'
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// TODO: describe __NAME__.
var rootCmd = &cobra.Command{
	Use:   "__NAME__",
	Short: "TODO: what it does",
}

var helloCmd = &cobra.Command{
	Use:   "hello [name]",
	Short: "Print a greeting",
	Run: func(_ *cobra.Command, args []string) {
		name := "world"
		if len(args) > 0 {
			name = args[0]
		}
		fmt.Printf("hello, %s\n", name)
	},
}

func init() {
	rootCmd.AddCommand(helloCmd)
}

// Execute runs the root command.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
EOF
        ok "wrote main.go + cmd/root.go (cobra skeleton)"
    fi
    in_project go mod tidy
}

# ── git ───────────────────────────────────────────────────────────────────────
_cli_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" \
        || warn "nothing committed (empty or git user not configured)"
}

# ── pipeline ──────────────────────────────────────────────────────────────────
recipe_run() {
    STACK="${STACK:-sh}"
    case "$STACK" in sh|rust|go) ;; *) warn "unknown cli stack '$STACK' — using sh"; STACK=sh ;; esac
    LABEL="$(_cli_stack_label)"

    # 1 ── scaffold ──────────────────────────────────────────────────────────────
    head "1 · scaffold (cli: $STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        sh)   _cli_scaffold_sh ;;
        rust) _cli_scaffold_rust ;;
        go)   _cli_scaffold_go ;;
    esac
    [ "$DRY_RUN" = 1 ] && run mkdir -p "$PROJECT_DIR"

    # 2 ── overlay ───────────────────────────────────────────────────────────────
    head "2 · overlay"
    apply_overlay "$PROJECT_DIR" cli

    # 3 ── agent context ─────────────────────────────────────────────────────────
    head "3 · AGENTS.md"
    render_agents_md "$PROJECT_DIR" "$PROJECT_NAME" "$TYPE" "$LABEL"

    # 4 ── resolve + vendor skills ───────────────────────────────────────────────
    head "4 · skills (download & vendor)"
    # shellcheck disable=SC2086
    DRY_RUN="$DRY_RUN" "$SPROUT_DIR/skills/resolve.sh" "$PROJECT_DIR" $SKILLS_SEL

    # 4b ─ SDD plane (kit + flow skills) — opt-in via --sdd / wizard ─────────────
    if [ "${SDD_INIT:-0}" = 1 ]; then
        head "4b · SDD kit"
        render_sdd_kit "$PROJECT_DIR"
    fi

    # 5 ── link agents ───────────────────────────────────────────────────────────
    head "5 · link agents"
    "$SPROUT_DIR/skills/setup.sh" "$PROJECT_DIR" "$AGENTS_SEL"

    # 6 ── sync auto-invoke table ────────────────────────────────────────────────
    head "6 · skill-sync (AGENTS.md table)"
    "$SPROUT_DIR/skills/sync-agents.sh" "$PROJECT_DIR"

    # 7 ── validate global CLIs ──────────────────────────────────────────────────
    validate_clis "$TYPE"

    # 8 ── git (optional) ────────────────────────────────────────────────────────
    _cli_git

    # done ───────────────────────────────────────────────────────────────────────
    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: $LABEL"
    case "$STACK" in
        sh)   dim "  next:  cd $PROJECT_NAME  &&  ./$PROJECT_NAME help   (install: ./install.sh)" ;;
        rust) dim "  next:  cd $PROJECT_NAME  &&  cargo run -- hello" ;;
        go)   dim "  next:  cd $PROJECT_NAME  &&  go run . hello" ;;
    esac
}
