# fullstack.sh — recipe for backend / fullstack projects.
#   stack     laravel (PHP) | django (Python) | fastapi (Python)
#             workers (Hono API on Cloudflare Workers) | react-workers (React + Worker monorepo)
#   database  sqlite | postgres | mysql   (relational stacks only; workers use D1/KV/R2 bindings)
#   frontend  none (default) | react | vue | astro | vanilla  — fastapi only for now.
#             Choosing one makes a monorepo: FastAPI in api/, the frontend in web/
#             (reuses the web plane). No frontend ⇒ flat backend, as before.
#   docker    --docker (opt-in). fastapi ⇒ dev docker-compose (db + api [+ web]).
#             laravel ⇒ Laravel Sail (php artisan sail:install). No PHP toolchain ⇒
#             laravel.build (Docker-only installer); no Python toolchain ⇒ the api
#             image (uv) provides the runtime.
#   testing   Pest (laravel) / pytest (python) / vitest (workers), optional
#   git       init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK DB LANG BASE CSS TESTING GIT_INIT
#          DOCKER PM AGENTS_SEL SKILLS_SEL DRY_RUN

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

    case "$STACK" in
        fastapi)
            _dsvc="db + api"; { [ -n "$BASE" ] && [ "$BASE" != none ]; } && _dsvc="$_dsvc + web"
            if ask_yn "5 · docker (dev compose: $_dsvc)?" n; then DOCKER=1; else DOCKER=0; fi ;;
        laravel)
            if ask_yn '5 · docker (Laravel Sail — php artisan sail:install)?' n; then DOCKER=1; else DOCKER=0; fi ;;
    esac
    if ask_yn '6 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
}

# ── Laravel (PHP) ─────────────────────────────────────────────────────────────
# Docker for Laravel = Sail (its native docker-compose). Opt-in via --docker, which
# runs `php artisan sail:install`. With no PHP/composer we fall back to laravel.build,
# the official Docker-only installer (creates a Laravel+Sail app with zero local PHP).
_fs_laravel() {
    _ldb=sqlite; case "$DB" in postgres) _ldb=pgsql ;; mysql) _ldb=mysql ;; esac
    _sail=pgsql;  case "$DB" in mysql) _sail=mysql ;; sqlite|"") _sail=mailpit ;; esac  # sail service(s)

    if ! have laravel && ! have composer; then
        if have docker; then
            say "no PHP/composer — scaffolding via Docker (laravel.build, includes Sail)"
            # shellcheck disable=SC2086
            run sh -c "curl -s 'https://laravel.build/$PROJECT_NAME?with=$_sail' | bash" \
                || warn "laravel.build failed (needs network + Docker running)"
            dim "  start:  cd $PROJECT_NAME && ./vendor/bin/sail up"
            return 0
        fi
        warn "no laravel/composer and no docker — creating an empty project dir"
        dim "  install PHP+composer, or Docker (then re-run for the laravel.build path)"
        run mkdir -p "$PROJECT_DIR"; return 0
    fi

    if have laravel; then
        _flags="--database=$_ldb --no-interaction"
        [ "$TESTING" = pest ] && _flags="$_flags --pest"
        # shellcheck disable=SC2086
        run laravel new "$PROJECT_NAME" $_flags
    else
        run composer create-project laravel/laravel "$PROJECT_NAME"
        dim "  set DB_CONNECTION=$_ldb in .env"
    fi

    # Sail (dev docker) — opt-in. Sail ships with fresh Laravel; sail:install writes
    # docker-compose.yml with the chosen services. Guarded so a failure doesn't abort.
    if [ "$DOCKER" = 1 ]; then
        head "laravel sail (dev docker)"
        in_project composer require laravel/sail --dev --no-interaction || warn "could not add laravel/sail (network?)"
        in_project php artisan sail:install --with="$_sail" || warn "sail:install failed"
        dim "  start:  ./vendor/bin/sail up"
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
        # --vcs none: never let uv init its own git repo. In the monorepo layout a
        # nested api/.git makes the root `git add -A` fail ("does not have a commit
        # checked out") and, under set -e, aborts the whole run. _fs_git owns git.
        in_dir "$_dir" uv init . --vcs none
        in_dir "$_dir" uv add fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_dir "$_dir" uv add --dev pytest httpx
    elif have python3; then
        run python3 -m venv "$_dir/.venv"
        in_dir "$_dir" .venv/bin/pip install --quiet --upgrade pip fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_dir "$_dir" .venv/bin/pip install --quiet pytest httpx
    else
        if [ "${DOCKER:-0}" = 1 ]; then
            warn "no uv/python3 locally — the api Docker image (uv) will provide the runtime"
            dim "  app/main.py + a minimal pyproject.toml get scaffolded for the container"
        else
            warn "no uv or python3 — leaving $_dir empty"
            dim "  install uv (curl -LsSf https://astral.sh/uv/install.sh | sh) or re-run with --docker"
        fi
        return 0
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

# ── docker (dev compose) ──────────────────────────────────────────────────────
# Opt-in (--docker / wizard) hot-reload dev stack for the fastapi stack:
#   db (postgres/mysql, only if a DB is set) + api (uvicorn --reload) [+ web].
# Source is bind-mounted; deps live in the image and are shielded from the mount by
# anonymous volumes (/app/.venv, /app/node_modules), so edits reload without a rebuild.
_fs_db_url() { [ "$DB" = mysql ] && echo 'mysql://app:app@db:3306/app' || echo 'postgresql://app:app@db:5432/app'; }

_fs_web_dev_cmd() {
    case "$PM" in
        npm)  echo "npm run dev -- --host 0.0.0.0" ;;
        yarn) echo "yarn dev --host 0.0.0.0" ;;
        bun)  echo "bun run dev --host 0.0.0.0" ;;
        *)    echo "pnpm run dev --host 0.0.0.0" ;;
    esac
}

_fs_docker_api_dockerfile() {
    cat > "$1/Dockerfile" <<'EOF'
# Dev image for the FastAPI API. Dependencies come from pyproject.toml via `uv sync`.
# docker-compose bind-mounts the source and preserves this image's .venv with an
# anonymous volume, so `uvicorn --reload` picks up edits without a rebuild.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim
WORKDIR /app
COPY pyproject.toml ./
RUN uv sync
COPY . .
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF
}

_fs_docker_web_dockerfile() {
    if [ "$PM" = bun ]; then
        cat > "$1/Dockerfile" <<'EOF'
# Dev image for the frontend (bun). compose bind-mounts the source and keeps this
# image's node_modules via an anonymous volume for hot reload.
FROM oven/bun:1
WORKDIR /app
COPY package.json ./
RUN bun install
COPY . .
EOF
        return 0
    fi
    case "$PM" in
        npm)  _pmi="npm install" ;;
        yarn) _pmi="corepack enable && yarn install" ;;
        *)    _pmi="corepack enable && pnpm install" ;;
    esac
    cat > "$1/Dockerfile" <<EOF
# Dev image for the $BASE frontend. compose bind-mounts the source and keeps this
# image's node_modules via an anonymous volume for hot reload.
FROM node:22-slim
WORKDIR /app
COPY package.json ./
RUN $_pmi
COPY . .
EOF
}

# minimal pyproject so the api image builds even if the local Python toolchain was absent
_fs_docker_pyproject() {
    cat > "$1/pyproject.toml" <<'EOF'
[project]
name = "api"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi",
    "uvicorn[standard]",
]
EOF
}

_fs_docker_db_service() {
    if [ "$DB" = mysql ]; then
        cat <<'EOF'
  db:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${DB_NAME:-app}
      MYSQL_USER: ${DB_USER:-app}
      MYSQL_PASSWORD: ${DB_PASSWORD:-app}
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-app}
    ports:
      - "3306:3306"
    volumes:
      - dbdata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 10

EOF
    else
        cat <<'EOF'
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME:-app}
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-app}
    ports:
      - "5432:5432"
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app}"]
      interval: 5s
      timeout: 5s
      retries: 10

EOF
    fi
}

_fs_docker_api_service() {
    _mono="$1"; _hasdb="$2"; _amount="$3"
    printf '  api:\n'
    printf '    build: %s\n' "$_amount"
    printf '    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload\n'
    printf '    volumes:\n      - %s:/app\n      - /app/.venv\n' "$_amount"
    printf '    ports:\n      - "8000:8000"\n'
    if [ "$_hasdb" = 1 ]; then
        printf '    environment:\n      DATABASE_URL: ${DATABASE_URL:-%s}\n' "$(_fs_db_url)"
        printf '    depends_on:\n      db:\n        condition: service_healthy\n'
    fi
    printf '\n'
}

_fs_docker_web_service() {
    _port=5173; [ "$BASE" = astro ] && _port=4321
    printf '  web:\n'
    printf '    build: ./web\n'
    printf '    command: %s\n' "$(_fs_web_dev_cmd)"
    printf '    volumes:\n      - ./web:/app\n      - /app/node_modules\n'
    printf '    ports:\n      - "%s:%s"\n' "$_port" "$_port"
    printf '    environment:\n      VITE_API_URL: ${VITE_API_URL:-http://localhost:8000}\n'
    printf '    depends_on:\n      - api\n\n'
}

_fs_docker_compose() {
    _mono="$1"; _hasdb="$2"; _amount="$3"
    _f="$PROJECT_DIR/docker-compose.yml"
    printf 'services:\n' > "$_f"
    [ "$_hasdb" = 1 ] && _fs_docker_db_service >> "$_f"
    _fs_docker_api_service "$_mono" "$_hasdb" "$_amount" >> "$_f"
    [ "$_mono" = 1 ] && _fs_docker_web_service >> "$_f"
    [ "$_hasdb" = 1 ] && printf 'volumes:\n  dbdata:\n' >> "$_f"
    return 0   # never let a false trailing test bubble up under `set -e`
}

_fs_docker_env() {
    _mono="$1"; _hasdb="$2"
    _f="$PROJECT_DIR/.env.example"
    : > "$_f"
    if [ "$_hasdb" = 1 ]; then
        {
            printf '# Database\nDB_NAME=app\nDB_USER=app\nDB_PASSWORD=app\n\n'
            printf '# API\nDATABASE_URL=%s\n' "$(_fs_db_url)"
        } >> "$_f"
    fi
    [ "$_mono" = 1 ] && printf '\n# Web\nVITE_API_URL=http://localhost:8000\n' >> "$_f"
    return 0   # never let a false trailing test bubble up under `set -e`
}

_fs_docker_makefile() {
    {
        printf '.PHONY: up down build logs ps\n\n'
        printf 'up:\n\tdocker compose up\n\n'
        printf 'down:\n\tdocker compose down\n\n'
        printf 'build:\n\tdocker compose build\n\n'
        printf 'logs:\n\tdocker compose logs -f\n\n'
        printf 'ps:\n\tdocker compose ps\n'
    } > "$PROJECT_DIR/Makefile"
}

_fs_docker_ignore() {
    if [ "$1" = 1 ]; then
        printf '%s\n' '.venv' '__pycache__' '.git' > "$PROJECT_DIR/api/.dockerignore"
        printf '%s\n' 'node_modules' 'dist' '.git' > "$PROJECT_DIR/web/.dockerignore"
    else
        printf '%s\n' '.venv' '__pycache__' '.git' > "$PROJECT_DIR/.dockerignore"
    fi
}

# _fs_docker <mono>  — 1 = monorepo (api/ + web/), 0 = flat backend.
_fs_docker() {
    [ "${DOCKER:-0}" = 1 ] || return 0
    _mono="$1"
    head "docker (dev compose)"
    _hasdb=0; case "$DB" in postgres|mysql) _hasdb=1 ;; esac
    if [ "$DRY_RUN" = 1 ]; then
        _svc="api"; [ "$_hasdb" = 1 ] && _svc="db + $_svc"; [ "$_mono" = 1 ] && _svc="$_svc + web"
        dim "  would write docker-compose.yml ($_svc), Dockerfile(s), .env.example, Makefile"
        return 0
    fi
    if [ "$_mono" = 1 ]; then _actx=api; _amount=./api; else _actx=.; _amount=.; fi
    # make the api image runnable even if the local Python toolchain was missing
    [ -f "$PROJECT_DIR/$_actx/app/main.py" ]    || _fs_fastapi_app "$PROJECT_DIR/$_actx"
    [ -f "$PROJECT_DIR/$_actx/pyproject.toml" ] || _fs_docker_pyproject "$PROJECT_DIR/$_actx"
    _fs_docker_api_dockerfile "$PROJECT_DIR/$_actx"
    [ "$_mono" = 1 ] && _fs_docker_web_dockerfile "$PROJECT_DIR/web"
    _fs_docker_compose "$_mono" "$_hasdb" "$_amount"
    _fs_docker_env "$_mono" "$_hasdb"
    _fs_docker_makefile
    _fs_docker_ignore "$_mono"
    ok "wrote docker-compose.yml + Dockerfile(s) + .env.example + Makefile"
    dim "  start:  cp .env.example .env  &&  docker compose up   (or: make up)"
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
    # Guard each step: a failure here (e.g. a nested repo left by a scaffolder)
    # must not abort the run under set -e — the project is already built.
    in_project git init -q || { warn "git init failed — skipping"; return 0; }
    in_project git add -A  || { warn "git add failed — skipping commit"; return 0; }
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
    [ "$STACK" = laravel ] && [ "$DOCKER" = 1 ] && STACK_LABEL="$STACK_LABEL · sail"
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
    [ "$STACK" = fastapi ] && _fs_docker "$_MONO"

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
