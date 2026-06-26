# web.sh — recipe for web projects.
# Step 1 (scaffold) is a small decision tree:
#   base      astro | vanilla(vite)
#   css       none | sass | less | tailwind | bootstrap
#   lang      ts | js
#   linter    none | biome | eslint(+prettier)
#   testing   none | playwright | vitest
#   git       init + first commit (optional)
#
# The wizard calls recipe_configure() to gather these interactively; the
# non-interactive path takes them from flags (--base/--css/--lang/--linter/--test/--git).
# Env in:  PROJECT_NAME PROJECT_DIR TYPE PM AGENTS_SEL SKILLS_SEL DRY_RUN
#          BASE CSS LANG LINTER TESTING GIT_INIT

# ── interactive stack questions (wizard only) ─────────────────────────────────
recipe_configure() {
    head "configure your web project"
    BASE="$(pick_one '1 · base framework' 'astro' "$(printf '%s\n' \
        'astro|astro    — content-first framework (islands, MPA/SSR)' \
        'vanilla|vanilla  — no framework, just Vite (dev server + build)')")"

    CSS="$(pick_one '2 · CSS' 'tailwind' "$(printf '%s\n' \
        'none|none         — plain CSS' \
        'preprocessor|preprocessor — Sass or Less (asked next)' \
        'tailwind|tailwind     — utility-first' \
        'bootstrap|bootstrap    — component framework')")"
    if [ "$CSS" = preprocessor ]; then
        CSS="$(pick_one '    which preprocessor' 'sass' "$(printf '%s\n' \
            'sass|sass — .scss syntax' \
            'less|less — .less syntax')")"
    fi

    LANG="$(pick_one '3 · language' 'ts' "$(printf '%s\n' \
        'ts|typescript' \
        'js|javascript')")"

    LINTER="$(pick_one '4 · linter + formatter (optional)' 'none' "$(printf '%s\n' \
        'none|none' \
        'biome|biome  — fast all-in-one (lint + format)' \
        'eslint|eslint + prettier')")"

    TESTING="$(pick_many '5 · testing (optional — space to pick any/both)' '' "$(printf '%s\n' \
        'playwright|playwright — e2e / browser (pairs with the webapp-testing skill)' \
        'vitest|vitest    — unit')")"

    if ask_yn '6 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
}

# ── per-package-manager helpers ──────────────────────────────────────────────
# _create <create-pkg> <name> <flags...>  — `<pm> create <pkg> <name> [-- ]<flags>`
_create() {
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
_pm_install()     { case "$PM" in yarn) echo yarn ;; *) echo "$PM install" ;; esac; }
_pm_runtime_add() { case "$PM" in pnpm) echo "pnpm add" ;; yarn) echo "yarn add" ;; bun) echo "bun add" ;; *) echo "npm install" ;; esac; }

# ── scaffold ──────────────────────────────────────────────────────────────────
_web_scaffold() {
    if [ "$BASE" = vanilla ]; then
        _tpl=vanilla; [ "$LANG" = ts ] && _tpl=vanilla-ts
        if have "$PM"; then
            _create vite@latest "$PROJECT_NAME" --template "$_tpl" --no-interactive
            in_project $(_pm_install)          # vite does not auto-install
        else
            warn "$PM not found — creating an empty project dir instead"; run mkdir -p "$PROJECT_DIR"
        fi
    else
        _flags="--template minimal --install --no-git --skip-houston --yes"
        [ "$CSS" = tailwind ] && _flags="$_flags --add tailwind"   # official Astro integration
        if have "$PM"; then
            # shellcheck disable=SC2086
            _create astro@latest "$PROJECT_NAME" $_flags
        else
            warn "$PM not found — creating an empty project dir instead"; run mkdir -p "$PROJECT_DIR"
        fi
    fi
    # in dry-run nothing was really created; make a placeholder so later steps narrate
    if [ "$DRY_RUN" = 1 ]; then run mkdir -p "$PROJECT_DIR"; fi
    return 0
}

# ── css ───────────────────────────────────────────────────────────────────────
_web_css() {
    case "$CSS" in
        none|"")   ok "css: plain CSS (nothing to add)" ;;
        tailwind)
            if [ "$BASE" = astro ]; then
                ok "css: tailwind (added during scaffold via --add tailwind)"
            else
                say "css: tailwind (Vite + @tailwindcss/vite)"
                # shellcheck disable=SC2086
                in_project $(pm_add "$PM") tailwindcss @tailwindcss/vite
                _web_vite_tailwind_wire
            fi ;;
        sass)
            say "css: sass"
            # shellcheck disable=SC2086
            in_project $(pm_add "$PM") sass
            if [ "$BASE" = vanilla ]; then _web_vite_preprocessor scss
            else dim "  import .scss from your components/layout (Astro handles Sass natively)"; fi ;;
        less)
            say "css: less"
            # shellcheck disable=SC2086
            in_project $(pm_add "$PM") less
            if [ "$BASE" = vanilla ]; then _web_vite_preprocessor less
            else dim "  import .less from your components/layout"; fi ;;
        bootstrap)
            say "css: bootstrap"
            # shellcheck disable=SC2086
            in_project $(_pm_runtime_add) bootstrap
            dim "  import 'bootstrap/dist/css/bootstrap.min.css' in your entry" ;;
        *) warn "unknown css option '$CSS' — skipping" ;;
    esac
}

# Locate the Vite vanilla css/entry files (real template layout: src/style.css, src/main.{js,ts}).
# NOTE: use `sed -n 1p`, not `head -1` — common.sh defines a log function head() that
# would shadow the binary here.
_vite_css_entry()  { find "$PROJECT_DIR" -maxdepth 2 \( -name style.css -o -name styles.css -o -name main.css \) 2>/dev/null | sed -n '1p'; }
_vite_main_entry() { find "$PROJECT_DIR" -maxdepth 2 \( -name 'main.ts' -o -name 'main.js' \) 2>/dev/null | sed -n '1p'; }

# Wire Tailwind v4 into a Vite vanilla project (no framework integration available).
# Idempotent: won't clobber an existing vite.config and won't double-import.
_web_vite_tailwind_wire() {
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would add @tailwindcss/vite to vite.config and '@import \"tailwindcss\";' to the css entry"
        return 0
    fi
    _ext=js; [ "$LANG" = ts ] && _ext=ts
    if [ -e "$PROJECT_DIR/vite.config.js" ] || [ -e "$PROJECT_DIR/vite.config.ts" ]; then
        warn "vite.config already exists — add the @tailwindcss/vite plugin to it yourself"
    else
        cat > "$PROJECT_DIR/vite.config.$_ext" <<'EOF'
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [tailwindcss()],
})
EOF
        ok "wrote vite.config.$_ext with the @tailwindcss/vite plugin"
    fi
    _css="$(_vite_css_entry)"
    if [ -z "$_css" ]; then
        warn "no css entry found — add '@import \"tailwindcss\";' to your main stylesheet manually"; return 0
    fi
    if grep -q 'tailwindcss' "$_css" 2>/dev/null; then
        dim "  $(basename "$_css") already imports tailwindcss"
    else
        { printf '@import "tailwindcss";\n\n'; cat "$_css"; } > "$_css.sprout" && mv "$_css.sprout" "$_css"
        ok "added '@import \"tailwindcss\";' to $(basename "$_css")"
    fi
}

# Switch a Vite vanilla project's stylesheet to a preprocessor: rename src/style.css ->
# style.<ext> and update the import in the main entry. Arg: scss | less.
_web_vite_preprocessor() {
    _pp="$1"
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would rename style.css -> style.$_pp and update the import in the main entry"; return 0
    fi
    _css="$(_vite_css_entry)"
    if [ -z "$_css" ] || [ "$(basename "$_css")" != style.css ]; then
        dim "  write .$_pp and import it from your entry"; return 0
    fi
    _new="${_css%/*}/style.$_pp"
    mv "$_css" "$_new"
    _main="$(_vite_main_entry)"
    if [ -n "$_main" ] && grep -q 'style\.css' "$_main" 2>/dev/null; then
        sed "s/style\.css/style.$_pp/" "$_main" > "$_main.sprout" && mv "$_main.sprout" "$_main"
        ok "renamed style.css -> style.$_pp and updated the import in $(basename "$_main")"
    else
        ok "renamed style.css -> style.$_pp"
        dim "  import it from your entry:  import './style.$_pp'"
    fi
}

# ── linter / formatter ────────────────────────────────────────────────────────
_web_linter() {
    case "$LINTER" in
        none|"") : ;;
        biome)
            say "linter: biome (lint + format)"
            # shellcheck disable=SC2086
            in_project $(pm_add "$PM") --save-exact @biomejs/biome
            # shellcheck disable=SC2086
            in_project $(pm_exec "$PM") biome init ;;
        eslint)
            say "linter: eslint + prettier"
            # shellcheck disable=SC2086
            in_project $(pm_add "$PM") eslint prettier
            dim "  add your eslint.config.js / .prettierrc to taste" ;;
        *) warn "unknown linter '$LINTER' — skipping" ;;
    esac
}

# ── testing ───────────────────────────────────────────────────────────────────
_web_testing() {
    [ -n "$TESTING" ] || return 0
    for _t in $TESTING; do
        case "$_t" in
            none|"") : ;;
            playwright)
                say "testing: playwright (@playwright/test) — e2e"
                # shellcheck disable=SC2086
                in_project $(pm_add "$PM") @playwright/test
                dim "  one-time browser download:  $(pm_exec "$PM") playwright install"
                dim "  usage patterns: see the vendored webapp-testing skill" ;;
            vitest)
                say "testing: vitest — unit"
                # shellcheck disable=SC2086
                in_project $(pm_add "$PM") vitest
                dim "  run with:  $(pm_exec "$PM") vitest" ;;
            *) warn "unknown testing option '$_t' — skipping" ;;
        esac
    done
}

# ── git ───────────────────────────────────────────────────────────────────────
_web_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" \
        || warn "nothing committed (empty or git user not configured)"
}

# ── human-readable stack label for AGENTS.md ─────────────────────────────────
_web_stack_label() {
    _b="$BASE"; [ "$BASE" = vanilla ] && _b="vanilla (vite)"
    _c="$CSS";  [ "$CSS" = none ] && _c="plain css"
    printf '%s · %s · %s' "$_b" "$_c" "$LANG"
    { [ "$LINTER" != none ] && [ -n "$LINTER" ]; } && printf ' · %s' "$LINTER"
    for _t in $TESTING; do [ "$_t" != none ] && printf ' · %s' "$_t"; done
    return 0
}

# ── pipeline ──────────────────────────────────────────────────────────────────
recipe_run() {
    PM="${PM:-$(default_pm_js)}"
    BASE="${BASE:-astro}"; CSS="${CSS:-tailwind}"; LANG="${LANG:-ts}"
    LINTER="${LINTER:-none}"   # TESTING is a (possibly empty) space-separated list
    STACK="$(_web_stack_label)"

    # 1 ── scaffold ────────────────────────────────────────────────────────────
    head "1 · scaffold ($BASE via $PM)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    _web_scaffold

    # 2 ── overlay + css ───────────────────────────────────────────────────────
    head "2 · overlay + css"
    apply_overlay "$PROJECT_DIR" web
    _web_css

    # 3 ── linter + testing ────────────────────────────────────────────────────
    head "3 · linter + testing"
    _web_linter
    _web_testing

    # 4 ── agent context ───────────────────────────────────────────────────────
    head "4 · AGENTS.md"
    render_agents_md "$PROJECT_DIR" "$PROJECT_NAME" "$TYPE" "$STACK"

    # 5 ── resolve + vendor skills ─────────────────────────────────────────────
    head "5 · skills (download & vendor)"
    # shellcheck disable=SC2086
    DRY_RUN="$DRY_RUN" "$SPROUT_DIR/skills/resolve.sh" "$PROJECT_DIR" $SKILLS_SEL

    # 5b ─ SDD plane (kit + flow skills) ────────────────────────────────────────
    head "5b · SDD kit"
    render_sdd_kit "$PROJECT_DIR"

    # 6 ── link agents ─────────────────────────────────────────────────────────
    head "6 · link agents"
    "$SPROUT_DIR/skills/setup.sh" "$PROJECT_DIR" "$AGENTS_SEL"

    # 7 ── sync auto-invoke table ──────────────────────────────────────────────
    head "7 · skill-sync (AGENTS.md table)"
    "$SPROUT_DIR/skills/sync-agents.sh" "$PROJECT_DIR"

    # 8 ── validate global CLIs ────────────────────────────────────────────────
    validate_clis "$TYPE"

    # 9 ── git (optional) ──────────────────────────────────────────────────────
    _web_git

    # done ─────────────────────────────────────────────────────────────────────
    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: $STACK"
    dim "  next:  cd $PROJECT_NAME  &&  divvy"
}
