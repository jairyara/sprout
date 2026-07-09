# fullstack.sh — recipe for backend / fullstack projects.
#   stack     laravel (PHP) | django (Python) | fastapi (Python)
#             workers (Hono API on Cloudflare Workers) | react-workers (React + Worker monorepo)
#   database  sqlite | postgres | mysql   (relational stacks only; workers use D1/KV/R2 bindings)
#   frontend  none (default) | react | vue | astro | vanilla  — fastapi only for now.
#             Choosing one makes a monorepo: FastAPI in api/, the frontend in web/
#             (reuses the web plane). No frontend ⇒ flat backend, as before.
#   testing   Pest (laravel) / pytest (python) / vitest (workers), optional
#   git       init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK DB LANG BASE CSS TESTING GIT_INIT
#          PM AGENTS_SEL SKILLS_SEL DRY_RUN

# ── interactive stack questions (wizard only) ─────────────────────────────────
recipe_configure() {
    head "configure your fullstack project"
    STACK="$(pick_one '1 · stack' 'laravel' "$(printf '%s\n' \
        'laravel|laravel       — PHP, batteries-included (Eloquent ORM, routing, auth)' \
        'django|django        — Python, batteries-included (ORM, admin, migrations)' \
        'fastapi|fastapi       — Python, minimal async API framework' \
        'workers|workers       — Hono API on Cloudflare Workers (edge · wrangler)' \
        'react-workers|react-workers — React (Vite) + Hono Worker API in one repo')")"

    case "$STACK" in
        workers|react-workers)
            # edge / JS stacks: no relational DB step (use D1/KV/R2 bindings instead)
            DB=""
            LANG="$(pick_one '2 · language' 'ts' "$(printf '%s\n' \
                'ts|typescript' \
                'js|javascript')")"
            if ask_yn '3 · scaffold tests (vitest — @cloudflare/vitest-pool-workers)?' n; then
                TESTING=vitest; else TESTING=""; fi ;;
        *)
            DB="$(pick_one '2 · database' 'sqlite' "$(printf '%s\n' \
                'sqlite|sqlite    — zero-config file DB (great to start)' \
                'postgres|postgres  — production-grade relational DB' \
                'mysql|mysql     — popular relational DB')")"
            # frontend (adds a web/ package → monorepo). Only wired for fastapi so far.
            if [ "$STACK" = fastapi ]; then
                _fe="$(pick_one '3 · frontend (optional — adds web/)' 'none' "$(printf '%s\n' \
                    'none|none    — backend / API only' \
                    'react|react   — Vite SPA in web/' \
                    'vue|vue     — Vite SPA in web/' \
                    'astro|astro   — content-first in web/' \
                    'vanilla|vanilla — Vite, no framework, in web/')")"
                if [ "$_fe" != none ]; then
                    BASE="$_fe"
                    LANG="$(pick_one '    frontend language' 'ts' "$(printf '%s\n' \
                        'ts|typescript' \
                        'js|javascript')")"
                    if ask_yn '    tailwind css in the frontend?' y; then CSS=tailwind; else CSS=""; fi
                fi
            fi
            if ask_yn '4 · scaffold tests (Pest for Laravel / pytest for Python)?' n; then
                case "$STACK" in laravel) TESTING=pest ;; *) TESTING=pytest ;; esac
            else TESTING=""; fi ;;
    esac

    if ask_yn '5 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
}

# ── Laravel (PHP) ─────────────────────────────────────────────────────────────
_fs_laravel() {
    if ! have laravel && ! have composer; then
        warn "laravel/composer not found — creating an empty project dir"; run mkdir -p "$PROJECT_DIR"; return 0
    fi
    _ldb=sqlite; case "$DB" in postgres) _ldb=pgsql ;; mysql) _ldb=mysql ;; esac
    if have laravel; then
        _flags="--database=$_ldb --no-interaction"
        [ "$TESTING" = pest ] && _flags="$_flags --pest"
        # shellcheck disable=SC2086
        run laravel new "$PROJECT_NAME" $_flags
    else
        run composer create-project laravel/laravel "$PROJECT_NAME"
        dim "  set DB_CONNECTION=$_ldb in .env"
    fi
    return 0
}

# ── Django (Python) ───────────────────────────────────────────────────────────
_fs_django() {
    if have uv; then
        run uv init "$PROJECT_NAME"
        in_project uv add django
        [ "$DB" = postgres ] && in_project uv add "psycopg[binary]"
        [ "$DB" = mysql ]    && in_project uv add mysqlclient
        [ "$TESTING" = pytest ] && in_project uv add --dev pytest pytest-django
        in_project uv run django-admin startproject config .
    elif have python3; then
        run mkdir -p "$PROJECT_DIR"
        run python3 -m venv "$PROJECT_DIR/.venv"
        in_project .venv/bin/pip install --quiet --upgrade pip django
        [ "$DB" = postgres ] && in_project .venv/bin/pip install --quiet "psycopg[binary]"
        [ "$DB" = mysql ]    && in_project .venv/bin/pip install --quiet mysqlclient
        [ "$TESTING" = pytest ] && in_project .venv/bin/pip install --quiet pytest pytest-django
        in_project .venv/bin/django-admin startproject config .
    else
        warn "no uv or python3 — creating an empty project dir"; run mkdir -p "$PROJECT_DIR"
    fi
    case "$DB" in sqlite|"") : ;; *) dim "  edit DATABASES in config/settings.py for $DB" ;; esac
    return 0
}

# ── FastAPI (Python) ──────────────────────────────────────────────────────────
# _fs_fastapi [dir] — scaffold a FastAPI app into <dir> (default $PROJECT_DIR).
# In a monorepo the caller passes $PROJECT_DIR/api; flat backends use $PROJECT_DIR.
_fs_fastapi() {
    _dir="${1:-$PROJECT_DIR}"
    run mkdir -p "$_dir"
    if have uv; then
        in_dir "$_dir" uv init .
        in_dir "$_dir" uv add fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_dir "$_dir" uv add --dev pytest httpx
    elif have python3; then
        run python3 -m venv "$_dir/.venv"
        in_dir "$_dir" .venv/bin/pip install --quiet --upgrade pip fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_dir "$_dir" .venv/bin/pip install --quiet pytest httpx
    else
        warn "no uv or python3 — leaving $_dir empty"; return 0
    fi
    _fs_fastapi_app "$_dir"
    return 0
}

# _fs_fastapi_app [dir] — write the hello-world app package into <dir>.
_fs_fastapi_app() {
    _dir="${1:-$PROJECT_DIR}"
    if [ "$DRY_RUN" = 1 ]; then dim "  would write app/main.py (FastAPI hello-world) in ${_dir##*/}/"; return 0; fi
    mkdir -p "$_dir/app"
    : > "$_dir/app/__init__.py"
    cat > "$_dir/app/main.py" <<'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root() -> dict[str, str]:
    return {"hello": "world"}
EOF
    dim "  run it:  uv run uvicorn app.main:app --reload   (or .venv/bin/uvicorn …)"
    return 0
}

# ── frontend (web/) via the web plane ─────────────────────────────────────────
# Scaffolds the chosen frontend ($BASE) into web/, then reuses the web recipe's
# css + linter steps (sourced) by repointing PROJECT_DIR at web/. Frontend testing
# is intentionally left to the web plane's own flow (TESTING here is the backend's).
_fs_frontend() {
    if ! have "$PM" && ! have npm; then
        warn "no JS package manager (pnpm/npm/yarn/bun) — skipping frontend (web/)"; return 0
    fi
    . "$SPROUT_DIR/recipes/web.sh"          # _web_css / _web_linter + tailwind wiring helpers
    _sep=""; [ "$PM" = npm ] && _sep="--"   # npm needs `--` before the create script's flags
    _needs_install=0
    case "$BASE" in
        astro)
            _flags="--template minimal --install --no-git --skip-houston --yes"
            [ "$CSS" = tailwind ] && _flags="$_flags --add tailwind"
            # shellcheck disable=SC2086
            in_project $PM create astro@latest web $_sep $_flags ;;
        react|vue|vanilla)
            _tpl="$BASE"; [ "$LANG" = ts ] && _tpl="$BASE-ts"
            # shellcheck disable=SC2086
            in_project $PM create vite@latest web $_sep --template "$_tpl"
            _needs_install=1 ;;
        *) warn "unknown frontend base '$BASE' — skipping frontend"; return 0 ;;
    esac
    # operate inside web/ for install + css/linter (reuse the web plane)
    _save_dir="$PROJECT_DIR"; _save_name="$PROJECT_NAME"
    PROJECT_DIR="$_save_dir/web"; PROJECT_NAME="web"
    # shellcheck disable=SC2086
    [ "$_needs_install" = 1 ] && in_project $(pm_install "$PM")   # vite doesn't auto-install
    _web_css
    _web_linter
    PROJECT_DIR="$_save_dir"; PROJECT_NAME="$_save_name"
    return 0
}

# Root README for the FastAPI + frontend monorepo (api/ + web/).
_fs_mono_readme() {
    if [ "$DRY_RUN" = 1 ]; then dim "  would write root README.md (api/ + web/ layout)"; return 0; fi
    _bundler="Vite"; [ "$BASE" = astro ] && _bundler="Astro"
    cat > "$PROJECT_DIR/README.md" <<EOF
# $PROJECT_NAME

Monorepo: FastAPI backend + $BASE frontend.

- \`api/\` — FastAPI app.  dev: \`cd api && uv run uvicorn app.main:app --reload\`
- \`web/\` — $BASE frontend ($_bundler).  dev: \`cd web && $PM run dev\`

Point the frontend at the API via an env var (e.g. \`VITE_API_URL=http://localhost:8000\`).
EOF
    ok "wrote root README.md"
    return 0
}

# ── Cloudflare Workers · Hono API (JS/edge) ───────────────────────────────────
# create-cloudflare (C3) scaffolds a Hono Worker with a wrangler config. Runs through
# the global $PM (pm_create handles npm's `--` separator). Backend-only / API on the edge.
_fs_workers() {
    if ! have "$PM" && ! have npm; then
        warn "no JS package manager (pnpm/npm/yarn/bun) — creating an empty project dir"; run mkdir -p "$PROJECT_DIR"; return 0
    fi
    _lang=ts; [ "$LANG" = js ] && _lang=js
    # shellcheck disable=SC2086
    pm_create cloudflare@latest "$PROJECT_NAME" --framework=hono --lang="$_lang" --no-git --no-deploy
    if [ "$TESTING" = vitest ]; then
        # shellcheck disable=SC2086
        in_project $(pm_add "$PM") vitest @cloudflare/vitest-pool-workers
        dim "  wire vitest to @cloudflare/vitest-pool-workers (see the workers-best-practices skill)"
    fi
    dim "  dev:    $(pm_exec "$PM") wrangler dev"
    dim "  deploy: $(pm_exec "$PM") wrangler deploy"
    dim "  add D1/KV/R2 bindings in wrangler.jsonc"
    return 0
}

# ── React (Vite) + Hono Worker in one repo (monorepo) ─────────────────────────
# Frontend in web/, edge API in api/. A root manifest ties them into a workspace.
_fs_react_workers() {
    if ! have "$PM" && ! have npm; then
        warn "no JS package manager (pnpm/npm/yarn/bun) — creating an empty project dir"; run mkdir -p "$PROJECT_DIR"; return 0
    fi
    run mkdir -p "$PROJECT_DIR"
    _tpl=react; [ "$LANG" = ts ] && _tpl=react-ts
    _lang=ts;   [ "$LANG" = js ] && _lang=js
    _sep=""; [ "$PM" = npm ] && _sep="--"      # npm needs `--` before the create script's flags
    say "frontend: Vite React → web/"
    # shellcheck disable=SC2086
    in_project $PM create vite@latest web $_sep --template "$_tpl"
    say "backend: Hono Worker → api/"
    # shellcheck disable=SC2086
    in_project $PM create cloudflare@latest api $_sep --framework=hono --lang="$_lang" --no-git --no-deploy
    _fs_react_workers_root
    return 0
}

# Root workspace manifest + README for the react-workers monorepo.
_fs_react_workers_root() {
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would write a root workspace manifest (web + api) and README.md"; return 0
    fi
    if [ "$PM" = pnpm ]; then
        cat > "$PROJECT_DIR/pnpm-workspace.yaml" <<'EOF'
packages:
  - web
  - api
EOF
        cat > "$PROJECT_DIR/package.json" <<EOF
{
  "name": "$PROJECT_NAME",
  "private": true,
  "scripts": {
    "dev:web": "pnpm --filter ./web dev",
    "dev:api": "pnpm --filter ./api dev",
    "deploy:api": "pnpm --filter ./api deploy"
  }
}
EOF
    else
        cat > "$PROJECT_DIR/package.json" <<EOF
{
  "name": "$PROJECT_NAME",
  "private": true,
  "workspaces": ["web", "api"]
}
EOF
    fi
    cat > "$PROJECT_DIR/README.md" <<EOF
# $PROJECT_NAME

Monorepo: React (Vite) frontend + Hono API on Cloudflare Workers.

- \`web/\` — React SPA (Vite).  dev: \`cd web && $PM run dev\`
- \`api/\` — Hono Worker.        dev: \`cd api && $(pm_exec "$PM") wrangler dev\` · deploy: \`$(pm_exec "$PM") wrangler deploy\`

Point the frontend at the Worker's URL via an env var (e.g. \`VITE_API_URL\`).
Add D1 / KV / R2 bindings in \`api/wrangler.jsonc\`.
EOF
    ok "wrote root workspace manifest + README.md"
    return 0
}

# ── git (optional) ────────────────────────────────────────────────────────────
_fs_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" \
        || warn "nothing committed (empty or git user not configured)"
    return 0
}

# ── pipeline ──────────────────────────────────────────────────────────────────
recipe_run() {
    STACK="${STACK:-laravel}"; LANG="${LANG:-ts}"   # LANG only used by the JS/edge + frontend stacks
    PM="${PM:-$(default_pm_js)}"                     # frontend (web/) package manager

    # frontend selection: empty/none = backend only. A monorepo (api/ + web/) is
    # triggered by choosing a frontend on a Python API stack — currently fastapi.
    FRONTEND="$BASE"; case "$FRONTEND" in ""|none) FRONTEND="" ;; esac
    _MONO=0; [ "$STACK" = fastapi ] && [ -n "$FRONTEND" ] && _MONO=1

    case "$STACK" in
        workers)       STACK_LABEL="workers · hono" ;;
        react-workers) STACK_LABEL="react (vite) + hono worker" ;;
        *) DB="${DB:-sqlite}"; STACK_LABEL="$STACK · $DB" ;;
    esac
    [ "$_MONO" = 1 ] && STACK_LABEL="$STACK_LABEL + $FRONTEND (web/)"
    if [ -n "$TESTING" ]; then STACK_LABEL="$STACK_LABEL · $TESTING"; fi

    # 1 ── scaffold ────────────────────────────────────────────────────────────
    head "1 · scaffold ($STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        laravel)       _fs_laravel ;;
        django)        [ -n "$FRONTEND" ] && warn "frontend (--base) not yet wired for django — scaffolding backend only"
                       _fs_django ;;
        fastapi)
            if [ "$_MONO" = 1 ]; then
                run mkdir -p "$PROJECT_DIR"
                head "1a · backend (FastAPI → api/)"; _fs_fastapi "$PROJECT_DIR/api"
                head "1b · frontend ($FRONTEND → web/)"; _fs_frontend
                _fs_mono_readme
            else
                _fs_fastapi "$PROJECT_DIR"
            fi ;;
        workers)       _fs_workers ;;
        react-workers) _fs_react_workers ;;
        *) err "unknown fullstack stack '$STACK' (use laravel|django|fastapi|workers|react-workers)"; exit 1 ;;
    esac
    if [ "$DRY_RUN" = 1 ]; then run mkdir -p "$PROJECT_DIR"; fi

    # 2 ── overlay ─────────────────────────────────────────────────────────────
    head "2 · overlay"
    apply_overlay "$PROJECT_DIR" fullstack

    # 3 ── agent context ───────────────────────────────────────────────────────
    head "3 · AGENTS.md"
    render_agents_md "$PROJECT_DIR" "$PROJECT_NAME" "$TYPE" "$STACK_LABEL"

    # 4 ── resolve + vendor skills ─────────────────────────────────────────────
    head "4 · skills (download & vendor)"
    # shellcheck disable=SC2086
    DRY_RUN="$DRY_RUN" "$SPROUT_DIR/skills/resolve.sh" "$PROJECT_DIR" $SKILLS_SEL

    # 4b ── SDD plane (kit + flow skills) — opt-in via --sdd / wizard ───────────
    if [ "${SDD_INIT:-0}" = 1 ]; then
        head "4b · SDD kit"
        render_sdd_kit "$PROJECT_DIR"
    fi

    # 5 ── link agents ─────────────────────────────────────────────────────────
    head "5 · link agents"
    "$SPROUT_DIR/skills/setup.sh" "$PROJECT_DIR" "$AGENTS_SEL"

    # 6 ── sync auto-invoke table ──────────────────────────────────────────────
    head "6 · skill-sync (AGENTS.md table)"
    "$SPROUT_DIR/skills/sync-agents.sh" "$PROJECT_DIR"

    # 7 ── validate global CLIs ────────────────────────────────────────────────
    validate_clis "$TYPE"

    # 8 ── git (optional) ──────────────────────────────────────────────────────
    _fs_git

    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: $STACK_LABEL"
    dim "  next:  cd $PROJECT_NAME  &&  divvy"
}
