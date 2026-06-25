#!/bin/sh
# setup.sh — wire the project's single AGENTS.md + vendored skills/ to each chosen
# agent via symlinks, and add the generated links to .gitignore.
#
# Usage:  setup.sh <project_dir> "<agents>"      e.g. "claude gemini codex copilot"
#
# Model (prowler-style): AGENTS.md is the single source of truth; every agent reads
# its own filename pointing at the same content. skills/ is linked per agent too.
set -e

SPROUT_DIR="${SPROUT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$SPROUT_DIR/lib/common.sh"

PROJECT_DIR="$1"; AGENTS="${2:-claude}"
[ -n "$PROJECT_DIR" ] || { err "setup.sh: missing <project_dir>"; exit 1; }

if [ "${DRY_RUN:-0}" = 1 ] && [ ! -d "$PROJECT_DIR" ]; then
    say "would link agents [$AGENTS] in $PROJECT_DIR (CLAUDE.md/GEMINI.md/… -> AGENTS.md, .<agent>/skills -> ../skills)"
    exit 0
fi
cd "$PROJECT_DIR"
[ -f AGENTS.md ] || { err "setup.sh: AGENTS.md not found in $PROJECT_DIR"; exit 1; }

GITIGNORE=".gitignore"
ignore() { grep -qxF "$1" "$GITIGNORE" 2>/dev/null || run sh -c "printf '%s\n' '$1' >> '$GITIGNORE'"; }

link() { # link <target> <linkname>
    run rm -rf "$2"
    run ln -s "$1" "$2"
    ignore "$2"
}

say "linking agents: $AGENTS"
for agent in $AGENTS; do
    case "$agent" in
        claude)
            link AGENTS.md CLAUDE.md
            run mkdir -p .claude
            link ../skills .claude/skills ;;
        gemini)
            link AGENTS.md GEMINI.md
            run mkdir -p .gemini
            link ../skills .gemini/skills ;;
        codex)
            # Codex reads AGENTS.md natively; just expose skills.
            run mkdir -p .codex
            link ../skills .codex/skills ;;
        copilot)
            run mkdir -p .github
            link ../AGENTS.md .github/copilot-instructions.md ;;
        opencode)
            link AGENTS.md OPENCODE.md
            run mkdir -p .opencode
            link ../skills .opencode/skills ;;
        *)
            warn "unknown agent '$agent' — skipping" ;;
    esac
done
ok "agent links ready"
