#!/bin/sh
# resolve.sh — download the requested skills from the registry, cache them, vendor
# a copy into the project, and record exact versions in skills.lock.
#
# Usage:  resolve.sh <project_dir> <skill[@ref]> [skill[@ref] ...]
#
# Honors:  DRY_RUN=1   SPROUT_DIR=<repo>   SPROUT_CACHE=<dir>
set -e

SPROUT_DIR="${SPROUT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$SPROUT_DIR/lib/common.sh"

PROJECT_DIR="$1"; shift || true
[ -n "$PROJECT_DIR" ] || { err "resolve.sh: missing <project_dir>"; exit 1; }
[ $# -gt 0 ] || { warn "resolve.sh: no skills requested"; exit 0; }

REGISTRY="$SPROUT_DIR/skills/registry.tsv"
CACHE="${SPROUT_CACHE:-$HOME/.cache/sprout/skills}"
DEST="$PROJECT_DIR/skills"
LOCK="$PROJECT_DIR/skills.lock"

run mkdir -p "$CACHE" "$DEST"

# registry_field <name> <col-index 2..5> -> prints the field or empty
registry_field() {
    awk -F '\t' -v n="$1" -v c="$2" '
        /^[[:space:]]*#/ { next } { gsub(/^[ \t]+|[ \t]+$/, "", $1) }
        $1 == n { print $c; exit }
    ' "$REGISTRY"
}

# fetch_git <url> <ref> <cache_path> -> clones/updates, prints resolved SHA on fd1
fetch_git() {
    _url="$1"; _ref="$2"; _cp="$3"
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf '  would run:\033[0m git clone --depth 1 --branch %s %s %s\n' "$_ref" "$_url" "$_cp" >&2
        echo "DRYRUN-SHA"; return 0
    fi
    if [ -d "$_cp/.git" ]; then
        git -C "$_cp" fetch --depth 1 origin "$_ref" >/dev/null 2>&1 || true
        git -C "$_cp" checkout -q FETCH_HEAD 2>/dev/null || git -C "$_cp" checkout -q "$_ref"
    else
        rm -rf "$_cp"
        if ! git clone --depth 1 --branch "$_ref" "$_url" "$_cp" >/dev/null 2>&1; then
            # ref may be a bare commit: full clone then checkout
            git clone "$_url" "$_cp" >/dev/null 2>&1
            git -C "$_cp" checkout -q "$_ref"
        fi
    fi
    git -C "$_cp" rev-parse HEAD
}

lock_tmp="$(mktemp 2>/dev/null || echo "$LOCK.tmp")"
[ "${DRY_RUN:-0}" = 1 ] || : > "$lock_tmp"

for spec in "$@"; do
    name="${spec%@*}"; ref_override=""
    case "$spec" in *@*) ref_override="${spec##*@}" ;; esac

    source="$(registry_field "$name" 2)"
    def_ref="$(registry_field "$name" 3)"
    [ -n "$source" ] || { warn "skill '$name' not in registry — skipping"; continue; }

    ref="${ref_override:-$def_ref}"; [ "$ref" = latest ] && ref=main

    case "$source" in
        TODO:*)
            warn "skill '$name': source not wired yet (TODO in registry) — skipping"
            continue ;;
        skillsh:*)
            # skills.sh CLI fetch. Source: skillsh:<repo-url>#<skill-id>
            # We run `npx skills add <url> --skill <id> --copy` in a throwaway dir,
            # then lift its canonical .agents/skills/<id> copy into our skills/<name>.
            sh_url="${source#skillsh:}"; skill_id="$name"
            case "$sh_url" in *#*) skill_id="${sh_url##*#}"; sh_url="${sh_url%%#*}" ;; esac
            if ! have npx; then
                warn "skill '$name': skills.sh source needs Node/npx — skipping"; continue
            fi
            if [ "${DRY_RUN:-0}" = 1 ]; then
                printf '\033[2m  would run:\033[0m npx --yes skills add %s --skill %s --copy --yes\n' "$sh_url" "$skill_id"
                ok "would vendor $name -> skills/$name (skills.sh)"; continue
            fi
            say "fetching $name via skills.sh ($skill_id)"
            work="$CACHE/.skillsh/$name"
            rm -rf "$work"; mkdir -p "$work"
            if ! ( cd "$work" && npx --yes skills add "$sh_url" --skill "$skill_id" --copy --yes ) >/dev/null 2>&1; then
                warn "skill '$name': skills.sh fetch failed (network or unknown skill) — skipping"; rm -rf "$work"; continue
            fi
            produced="$(find "$work/.agents/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed -n '1p')"
            if [ -z "$produced" ] || [ ! -f "$produced/SKILL.md" ]; then
                warn "skill '$name': skills.sh produced no SKILL.md — skipping"; rm -rf "$work"; continue
            fi
            sha="$(awk -F'"' '/computedHash/{print $4; exit}' "$work/skills-lock.json" 2>/dev/null)"
            [ -n "$sha" ] || sha="skillsh"
            rm -rf "$DEST/$name"
            cp -R "$produced" "$DEST/$name"
            rm -rf "$DEST/$name/.git" "$work"
            printf '%s\t%s\t%s\t%s\n' "$name" "$source" "latest" "$sha" >> "$lock_tmp"
            ok "vendored $name -> skills/$name (skills.sh)" ;;
        git:*)
            url="${source#git:}"; subpath=""
            case "$url" in *#*) subpath="${url##*#}"; url="${url%%#*}" ;; esac
            case "$subpath" in *TODO*) warn "skill '$name': subpath is a TODO placeholder — skipping"; continue ;; esac
            cache_path="$CACHE/$name@$ref"
            say "fetching $name ($ref)"
            sha="$(fetch_git "$url" "$ref" "$cache_path")"
            src_dir="$cache_path"; [ -n "$subpath" ] && src_dir="$cache_path/$subpath"
            if [ "${DRY_RUN:-0}" != 1 ] && [ ! -f "$src_dir/SKILL.md" ]; then
                warn "skill '$name': no SKILL.md at $src_dir — check source/subpath"; continue
            fi
            run rm -rf "$DEST/$name"
            run cp -R "$src_dir" "$DEST/$name"
            run rm -rf "$DEST/$name/.git"
            [ "${DRY_RUN:-0}" = 1 ] || printf '%s\t%s\t%s\t%s\n' "$name" "$source" "$ref" "$sha" >> "$lock_tmp"
            ok "vendored $name -> skills/$name" ;;
        *)
            warn "skill '$name': unknown source scheme '$source' — skipping" ;;
    esac
done

if [ "${DRY_RUN:-0}" != 1 ]; then
    {
        echo "# skills.lock — exact versions vendored into this project. Do not edit by hand."
        echo "# name<TAB>source<TAB>ref<TAB>sha"
        cat "$lock_tmp"
    } > "$LOCK"
    rm -f "$lock_tmp"
    ok "wrote $LOCK"
fi
