#!/bin/sh
# sync-agents.sh — (re)generate the "Auto-invoke Skills" table in AGENTS.md from the
# frontmatter of every vendored skill (its `name` + `auto_invoke`). This is what the
# `skill-sync` meta-skill runs; agents do not reliably self-invoke on Trigger alone,
# so the table in AGENTS.md forces it.
#
# Usage:  sync-agents.sh <project_dir>
set -e

SPROUT_DIR="${SPROUT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$SPROUT_DIR/lib/common.sh"

PROJECT_DIR="$1"
[ -n "$PROJECT_DIR" ] || { err "sync-agents.sh: missing <project_dir>"; exit 1; }
AGENTS_MD="$PROJECT_DIR/AGENTS.md"
SKILLS_DIR="$PROJECT_DIR/skills"
if [ ! -f "$AGENTS_MD" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
        say "would regenerate the auto-invoke table in $AGENTS_MD"; exit 0
    fi
    err "AGENTS.md not found in $PROJECT_DIR"; exit 1
fi

BEGIN='<!-- BEGIN AUTO-INVOKE -->'
END='<!-- END AUTO-INVOKE -->'

# read a frontmatter scalar (first match) from a SKILL.md: fm_get <file> <key>
fm_get() {
    awk -v key="$2" '
        NR==1 && $0=="---" { infm=1; next }
        infm && $0=="---"  { exit }
        infm {
            line=$0; sub(/^[ \t]+/, "", line)
            if (line ~ "^" key ":") {
                sub("^" key ":[ \t]*", "", line)
                gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", line)
                print line; exit
            }
        }
    ' "$1"
}

# build the table body
table="| When you are about to…            | Invoke FIRST the skill(s)        |
|-----------------------------------|----------------------------------|"
found=0
if [ -d "$SKILLS_DIR" ]; then
    for sk in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$sk" ] || continue
        name="$(fm_get "$sk" name)"; [ -n "$name" ] || name="$(basename "$(dirname "$sk")")"
        trig="$(fm_get "$sk" auto_invoke)"; [ -n "$trig" ] || trig="(see skill description)"
        table="$table
| $trig | $name |"
        found=1
    done
fi
[ "$found" = 1 ] || table="$table
| (no skills vendored yet) | — |"

if [ "${DRY_RUN:-0}" = 1 ]; then
    head "AGENTS.md auto-invoke table (dry-run)"; printf '%s\n' "$table"; exit 0
fi

# splice the table between the markers (create the block if missing).
# The table is multi-line, so pass it via a temp file (awk -v can't hold newlines).
tmp="$(mktemp)"; tbl="$(mktemp)"
printf '%s\n' "$table" > "$tbl"
if grep -qF "$BEGIN" "$AGENTS_MD"; then
    awk -v b="$BEGIN" -v e="$END" -v tblfile="$tbl" '
        index($0, b) { print; while ((getline line < tblfile) > 0) print line; skip=1; next }
        index($0, e) { skip=0 }
        !skip        { print }
    ' "$AGENTS_MD" > "$tmp"
else
    {
        cat "$AGENTS_MD"
        printf '\n## Auto-invoke Skills\n\n%s\n' "$BEGIN"
        cat "$tbl"
        printf '%s\n' "$END"
    } > "$tmp"
fi
mv "$tmp" "$AGENTS_MD"
rm -f "$tbl"
ok "synced auto-invoke table in AGENTS.md"
