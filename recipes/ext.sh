# ext.sh — recipe for Chromium (MV3) browser extensions.
#   stack   vanilla (hand-rolled MV3, no build) | wxt (framework, needs node)
#   git     init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK GIT_INIT AGENTS_SEL SKILLS_SEL DRY_RUN

recipe_configure() {
    head "configure your extension"
    STACK="$(pick_one '1 · base' 'vanilla' "$(printf '%s\n' \
        'vanilla|vanilla — hand-rolled MV3 (manifest + popup + service worker, no build)' \
        'wxt|wxt     — modern extension framework (HMR, cross-browser, needs node)')")"
    if ask_yn '2 · git init + first commit?' n; then GIT_INIT=1; else GIT_INIT=0; fi
}

_ext_wxt() {
    if ! have npx; then warn "node/npx not found — falling back to vanilla MV3"; _ext_vanilla; return 0; fi
    run npx --yes wxt@latest init "$PROJECT_NAME" --template vanilla
    dim "  dev:  cd $PROJECT_NAME && npm install && npm run dev"
    return 0
}

_ext_vanilla() {
    run mkdir -p "$PROJECT_DIR"
    if [ "$DRY_RUN" = 1 ]; then
        dim "  would write manifest.json (MV3), popup.html/js, background.js"; return 0
    fi
    cat > "$PROJECT_DIR/manifest.json" <<EOF
{
  "manifest_version": 3,
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "description": "A Chromium MV3 extension scaffolded with sprout.",
  "action": {
    "default_popup": "popup.html",
    "default_title": "$PROJECT_NAME"
  },
  "background": {
    "service_worker": "background.js"
  },
  "permissions": []
}
EOF
    cat > "$PROJECT_DIR/popup.html" <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>body { width: 240px; font: 14px system-ui; padding: 12px; }</style>
  </head>
  <body>
    <h1>Hello 🌱</h1>
    <button id="ping">Ping background</button>
    <script src="popup.js"></script>
  </body>
</html>
EOF
    cat > "$PROJECT_DIR/popup.js" <<'EOF'
document.getElementById("ping").addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "ping" }, (res) => {
    console.log("background replied:", res);
  });
});
EOF
    cat > "$PROJECT_DIR/background.js" <<'EOF'
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === "ping") sendResponse({ ok: true, at: Date.now() });
  return true;
});
EOF
    dim "  load it:  chrome://extensions → Developer mode → Load unpacked → $PROJECT_NAME"
    return 0
}

_ext_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" || warn "nothing committed"
    return 0
}

recipe_run() {
    STACK="${STACK:-vanilla}"

    head "1 · scaffold (chromium MV3 · $STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        vanilla) _ext_vanilla ;;
        wxt)     _ext_wxt ;;
        *) err "unknown ext base '$STACK' (use vanilla|wxt)"; exit 1 ;;
    esac
    if [ "$DRY_RUN" = 1 ]; then run mkdir -p "$PROJECT_DIR"; fi

    head "2 · overlay"
    apply_overlay "$PROJECT_DIR" ext

    head "3 · AGENTS.md"
    render_agents_md "$PROJECT_DIR" "$PROJECT_NAME" "$TYPE" "chromium-mv3 · $STACK"

    head "4 · skills (download & vendor)"
    # shellcheck disable=SC2086
    DRY_RUN="$DRY_RUN" "$SPROUT_DIR/skills/resolve.sh" "$PROJECT_DIR" $SKILLS_SEL

    head "5 · link agents"
    "$SPROUT_DIR/skills/setup.sh" "$PROJECT_DIR" "$AGENTS_SEL"

    head "6 · skill-sync (AGENTS.md table)"
    "$SPROUT_DIR/skills/sync-agents.sh" "$PROJECT_DIR"

    validate_clis "$TYPE"
    _ext_git

    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: chromium-mv3 · $STACK"
    dim "  next:  cd $PROJECT_NAME  &&  divvy"
}
