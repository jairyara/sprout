#!/bin/sh
# sync-agents.sh — (re)generate two tables in AGENTS.md:
#   1. "Auto-invoke Skills"  — from the frontmatter of every VENDORED skill (forced use).
#   2. "More skills you can add" — the registry catalog MINUS what's vendored, so the agent
#      can suggest installing a better-fitting skill via `sprout skills add <name>`.
# Agents don't reliably self-invoke on Trigger alone, and they can't suggest what they
# can't see — so both tables live in AGENTS.md.
#
# Usage:  sync-agents.sh <project_dir>
set -e

SPROUT_DIR="${SPROUT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$SPROUT_DIR/lib/common.sh"

PROJECT_DIR="$1"
[ -n "$PROJECT_DIR" ] || { err "sync-agents.sh: missing <project_dir>"; exit 1; }
AGENTS_MD="$PROJECT_DIR/AGENTS.md"
SKILLS_DIR="$PROJECT_DIR/skills"
REGISTRY="$SPROUT_DIR/skills/registry.tsv"
TAB="$(printf '\t')"
if [ ! -f "$AGENTS_MD" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
        say "would regenerate the skill tables in $AGENTS_MD"; exit 0
    fi
    err "AGENTS.md not found in $PROJECT_DIR"; exit 1
fi

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

# ── 1 · auto-invoke table (vendored skills) ─────────────────────────────────────
table="| When you are about to…            | Invoke FIRST the skill(s)        |
|-----------------------------------|----------------------------------|"
vendored=" "
found=0
if [ -d "$SKILLS_DIR" ]; then
    for sk in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$sk" ] || continue
        name="$(fm_get "$sk" name)"; [ -n "$name" ] || name="$(basename "$(dirname "$sk")")"
        trig="$(fm_get "$sk" auto_invoke)"; [ -n "$trig" ] || trig="(see skill description)"
        table="$table
| $trig | $name |"
        vendored="$vendored$name "
        found=1
    done
fi
[ "$found" = 1 ] || table="$table
| (no skills vendored yet) | — |"

# ── 2 · catalog table (registry minus vendored) ─────────────────────────────────
catalog="| For… (when it fits the task)      | Skill            | Install with                |
|-----------------------------------|------------------|-----------------------------|"
catfound=0
if [ -f "$REGISTRY" ]; then
    while IFS="$TAB" read -r rname rsrc rref rscope rinv rcli; do
        case "$rname" in ''|\#*|name) continue ;; esac
        case "$vendored" in *" $rname "*) continue ;; esac   # already vendored — skip
        [ -n "$rinv" ] || rinv="(see registry)"
        catalog="$catalog
| $rinv | $rname | sprout skills add $rname |"
        catfound=1
    done < "$REGISTRY"
fi
[ "$catfound" = 1 ] || catalog="$catalog
| (all catalog skills are installed) | — | — |"

# ── 3 · tooling table (manifest core CLIs the agent should prefer) ──────────────
# Replacement-class CLIs get a "use X instead of Y" directive; the rest are listed as
# additive tools. Interactive TUIs (fzf/lazygit) are for humans, not agents — skipped.
MANIFEST="$SPROUT_DIR/clis/manifest.tsv"
tooling="| Use   | Instead of | For                                |
|-------|------------|------------------------------------|"
extras=""; toolfound=0
if [ -f "$MANIFEST" ]; then
    while IFS="$TAB" read -r cname cbrew cpac capt cdnf czyp cphase ctypes cdesc; do
        case "$cname" in ''|\#*|name) continue ;; esac
        echo "$ctypes" | tr ',' '\n' | grep -qx core 2>/dev/null || continue
        case "$cname" in
            rg)          inst="grep / recursive grep" ;;
            fd)          inst="find" ;;
            bat)         inst="cat" ;;
            delta)       inst="plain git diff" ;;
            fzf|lazygit) continue ;;                       # interactive TUIs — not for agents
            *)           extras="$extras, \`$cname\`"; continue ;;
        esac
        tooling="$tooling
| \`$cname\` | $inst | $cdesc |"
        toolfound=1
    done < "$MANIFEST"
fi
[ "$toolfound" = 1 ] || tooling="$tooling
| (no preferred CLIs configured) | — | — |"
[ -n "$extras" ] && tooling="$tooling

Also on PATH when relevant (additive — use when the task calls for it): ${extras#, }."

if [ "${DRY_RUN:-0}" = 1 ]; then
    head "AGENTS.md auto-invoke table (dry-run)";  printf '%s\n' "$table"
    head "AGENTS.md skill catalog (dry-run)";      printf '%s\n' "$catalog"
    head "AGENTS.md tooling table (dry-run)";       printf '%s\n' "$tooling"
    exit 0
fi

# splice <begin> <end> <section-title> <tblfile> — replace block, or append section if absent
splice() {
    _b="$1"; _e="$2"; _title="$3"; _tf="$4"; _tmp="$(mktemp)"
    if grep -qF "$_b" "$AGENTS_MD"; then
        awk -v b="$_b" -v e="$_e" -v tblfile="$_tf" '
            index($0, b) { print; while ((getline line < tblfile) > 0) print line; skip=1; next }
            index($0, e) { skip=0 }
            !skip        { print }
        ' "$AGENTS_MD" > "$_tmp"
    else
        { cat "$AGENTS_MD"; printf '\n%s\n\n%s\n' "$_title" "$_b"; cat "$_tf"; printf '%s\n' "$_e"; } > "$_tmp"
    fi
    mv "$_tmp" "$AGENTS_MD"
}

tbl="$(mktemp)";  printf '%s\n' "$table"   > "$tbl"
cat="$(mktemp)";  printf '%s\n' "$catalog" > "$cat"
too="$(mktemp)";  printf '%s\n' "$tooling" > "$too"
splice '<!-- BEGIN TOOLING -->'       '<!-- END TOOLING -->'       '## Tooling — prefer these CLIs over the defaults' "$too"
splice '<!-- BEGIN AUTO-INVOKE -->'   '<!-- END AUTO-INVOKE -->'   '## Auto-invoke Skills'        "$tbl"
splice '<!-- BEGIN SKILL-CATALOG -->' '<!-- END SKILL-CATALOG -->' '## More skills you can add'   "$cat"
rm -f "$tbl" "$cat" "$too"
ok "synced tooling + auto-invoke + catalog tables in AGENTS.md"
