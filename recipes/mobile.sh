# mobile.sh — recipe for mobile apps.
#   stack   react-native (Expo) | flutter | kotlin (Android) | swift (iOS)
#   git     init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK GIT_INIT AGENTS_SEL SKILLS_SEL DRY_RUN

recipe_configure() {
    head "configure your mobile project"
    STACK="$(pick_one '1 · stack' 'react-native' "$(printf '%s\n' \
        'react-native|react-native — JS/TS via Expo (iOS + Android from one codebase)' \
        'flutter|flutter      — Dart (iOS + Android + more)' \
        'kotlin|kotlin       — native Android' \
        'swift|swift        — native iOS')")"
    # language only applies to react-native (Expo); flutter/kotlin/swift have their own.
    _gitn=2
    case "$STACK" in
        react-native|rn|expo)
            LANG="$(pick_one '2 · language' 'ts' "$(printf '%s\n' \
                'ts|typescript' \
                'js|javascript')")"
            _gitn=3 ;;
    esac
    if ask_yn "$_gitn · git init + first commit?" n; then GIT_INIT=1; else GIT_INIT=0; fi
}

_mb_react_native() {
    if ! have "$PM"; then warn "$PM not found — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    _tpl=blank; [ "$LANG" = ts ] && _tpl=blank-typescript
    # Expo picks its install pm from the one used to invoke create-expo-app.
    pm_create expo-app@latest "$PROJECT_NAME" --template "$_tpl"
    dim "  start it:  cd $PROJECT_NAME && $(pm_exec "$PM") expo start"
    return 0
}

_mb_flutter() {
    if ! have flutter; then warn "flutter SDK not found (https://flutter.dev) — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    run flutter create "$PROJECT_NAME"
    return 0
}

_mb_kotlin() {
    run mkdir -p "$PROJECT_DIR"
    # Gradle *does* have a CLI scaffolder; use it when present, degrade otherwise.
    if have gradle; then
        _pkg="com.example.$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
        if in_project gradle init --type kotlin-application --dsl kotlin \
                --project-name "$PROJECT_NAME" --package "$_pkg" \
                --test-framework junit-jupiter </dev/null >/dev/null 2>&1; then
            dim "  Gradle Kotlin app scaffolded; open in Android Studio to add Android targets"
            return 0
        fi
        warn "gradle init failed (older Gradle may prompt) — falling back to instructions"
    else
        warn "Android (Kotlin) apps are scaffolded from Android Studio / Gradle, not a simple CLI"
    fi
    dim "  create the app in Android Studio (New Project → Empty Activity) inside $PROJECT_NAME,"
    dim "  or use a Gradle template; sprout will still wire AGENTS.md + skills here"
    return 0
}

_mb_swift() {
    run mkdir -p "$PROJECT_DIR"
    if have swift; then
        in_project swift package init --type executable --name "$PROJECT_NAME"
        dim "  this is an SPM starting point — a full iOS app is built in Xcode (New → App)"
    else
        warn "Swift toolchain not found — empty dir"
    fi
    return 0
}

_mb_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" || warn "nothing committed"
    return 0
}

recipe_run() {
    STACK="${STACK:-react-native}"; LANG="${LANG:-ts}"
    STACK_LABEL="$STACK"
    case "$STACK" in react-native|rn|expo) STACK_LABEL="$STACK · $LANG" ;; esac

    head "1 · scaffold ($STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        react-native|rn|expo) _mb_react_native ;;
        flutter)              _mb_flutter ;;
        kotlin|android)       _mb_kotlin ;;
        swift|ios)            _mb_swift ;;
        *) err "unknown mobile stack '$STACK' (use react-native|flutter|kotlin|swift)"; exit 1 ;;
    esac
    if [ "$DRY_RUN" = 1 ]; then run mkdir -p "$PROJECT_DIR"; fi

    head "2 · overlay"
    apply_overlay "$PROJECT_DIR" mobile

    head "3 · AGENTS.md"
    render_agents_md "$PROJECT_DIR" "$PROJECT_NAME" "$TYPE" "$STACK_LABEL"

    head "4 · skills (download & vendor)"
    # shellcheck disable=SC2086
    DRY_RUN="$DRY_RUN" "$SPROUT_DIR/skills/resolve.sh" "$PROJECT_DIR" $SKILLS_SEL

    # 4b ── SDD plane (kit + flow skills) — opt-in via --sdd / wizard ───────────
    if [ "${SDD_INIT:-0}" = 1 ]; then
        head "4b · SDD kit"
        render_sdd_kit "$PROJECT_DIR"
    fi

    head "5 · link agents"
    "$SPROUT_DIR/skills/setup.sh" "$PROJECT_DIR" "$AGENTS_SEL"

    head "6 · skill-sync (AGENTS.md table)"
    "$SPROUT_DIR/skills/sync-agents.sh" "$PROJECT_DIR"

    validate_clis "$TYPE"
    _mb_git

    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: $STACK_LABEL"
    dim "  next:  cd $PROJECT_NAME  &&  divvy"
}
