# fullstack.sh — recipe for backend / fullstack projects.
#   stack     laravel (PHP) | django (Python) | fastapi (Python)
#   database  sqlite | postgres | mysql
#   testing   Pest (laravel) / pytest (python), optional
#   git       init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK DB TESTING GIT_INIT AGENTS_SEL SKILLS_SEL DRY_RUN

# ── interactive stack questions (wizard only) ─────────────────────────────────
recipe_configure() {
    head "configure your fullstack project"
    STACK="$(pick_one '1 · stack' 'laravel' "$(printf '%s\n' \
        'laravel|laravel  — PHP, batteries-included (Eloquent ORM, routing, auth)' \
        'django|django   — Python, batteries-included (ORM, admin, migrations)' \
        'fastapi|fastapi  — Python, minimal async API framework')")"

    DB="$(pick_one '2 · database' 'sqlite' "$(printf '%s\n' \
        'sqlite|sqlite    — zero-config file DB (great to start)' \
        'postgres|postgres  — production-grade relational DB' \
        'mysql|mysql     — popular relational DB')")"

    if ask_yn '3 · scaffold tests (Pest for Laravel / pytest for Python)?' n; then
        case "$STACK" in laravel) TESTING=pest ;; *) TESTING=pytest ;; esac
    else TESTING=""; fi

    if ask_yn '4 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
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
_fs_fastapi() {
    if have uv; then
        run uv init "$PROJECT_NAME"
        in_project uv add fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_project uv add --dev pytest httpx
    elif have python3; then
        run mkdir -p "$PROJECT_DIR"
        run python3 -m venv "$PROJECT_DIR/.venv"
        in_project .venv/bin/pip install --quiet --upgrade pip fastapi "uvicorn[standard]"
        [ "$TESTING" = pytest ] && in_project .venv/bin/pip install --quiet pytest httpx
    else
        warn "no uv or python3 — creating an empty project dir"; run mkdir -p "$PROJECT_DIR"; return 0
    fi
    _fs_fastapi_app
    return 0
}

_fs_fastapi_app() {
    if [ "$DRY_RUN" = 1 ]; then dim "  would write app/main.py (FastAPI hello-world)"; return 0; fi
    mkdir -p "$PROJECT_DIR/app"
    : > "$PROJECT_DIR/app/__init__.py"
    cat > "$PROJECT_DIR/app/main.py" <<'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root() -> dict[str, str]:
    return {"hello": "world"}
EOF
    dim "  run it:  uv run uvicorn app.main:app --reload   (or .venv/bin/uvicorn …)"
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
    STACK="${STACK:-laravel}"; DB="${DB:-sqlite}"
    STACK_LABEL="$STACK · $DB"
    if [ -n "$TESTING" ]; then STACK_LABEL="$STACK_LABEL · $TESTING"; fi

    # 1 ── scaffold ────────────────────────────────────────────────────────────
    head "1 · scaffold ($STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        laravel) _fs_laravel ;;
        django)  _fs_django ;;
        fastapi) _fs_fastapi ;;
        *) err "unknown fullstack stack '$STACK' (use laravel|django|fastapi)"; exit 1 ;;
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
