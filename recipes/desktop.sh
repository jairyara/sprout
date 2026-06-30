# desktop.sh — recipe for desktop apps.
#   stack   tauri (Rust+web) | wails (Go+web) | fyne (Go) | egui (Rust)
#   git     init + first commit, optional
#
# Env in:  PROJECT_NAME PROJECT_DIR TYPE STACK GIT_INIT AGENTS_SEL SKILLS_SEL DRY_RUN

recipe_configure() {
    head "configure your desktop project"
    STACK="$(pick_one '1 · framework' 'tauri' "$(printf '%s\n' \
        'tauri|tauri  — Rust core + web UI (small binaries, great DX)' \
        'wails|wails  — Go core + web UI' \
        'fyne|fyne   — pure Go GUI toolkit' \
        'egui|egui   — pure Rust immediate-mode GUI')")"
    # language only applies to tauri (its web frontend is JS/TS); the rest are Go/Rust.
    _gitn=2
    if [ "$STACK" = tauri ]; then
        LANG="$(pick_one '2 · language (web frontend)' 'ts' "$(printf '%s\n' \
            'ts|typescript' \
            'js|javascript')")"
        _gitn=3
    fi
    if ask_yn "$_gitn · git init + first commit?" n; then GIT_INIT=1; else GIT_INIT=0; fi
}

_dt_tauri() {
    if ! have "$PM"; then warn "$PM not found — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    _tpl=vanilla; [ "$LANG" = ts ] && _tpl=vanilla-ts
    # create-tauri-app honours --manager (pnpm|npm|yarn|bun) for the web frontend.
    pm_create tauri-app@latest "$PROJECT_NAME" --template "$_tpl" --manager "$PM" --yes
    have cargo || dim "  install Rust (https://rustup.rs) to build/run the Tauri app"
    return 0
}

_dt_wails() {
    if ! have wails; then warn "wails not found (https://wails.io) — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    run wails init -n "$PROJECT_NAME" -t vanilla
    return 0
}

_dt_fyne() {
    if ! have go; then warn "Go not found — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    run mkdir -p "$PROJECT_DIR"
    in_project go mod init "$PROJECT_NAME"
    _dt_fyne_main
    in_project go get "fyne.io/fyne/v2@latest"
    in_project go mod tidy
    return 0
}

_dt_fyne_main() {
    if [ "$DRY_RUN" = 1 ]; then dim "  would write main.go (minimal Fyne window)"; return 0; fi
    cat > "$PROJECT_DIR/main.go" <<'EOF'
package main

import (
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/widget"
)

func main() {
	a := app.New()
	w := a.NewWindow("app")
	w.SetContent(widget.NewLabel("Hello from sprout 🌱"))
	w.ShowAndRun()
}
EOF
    return 0
}

_dt_egui() {
    if ! have cargo; then warn "cargo/Rust not found (https://rustup.rs) — empty dir"; run mkdir -p "$PROJECT_DIR"; return 0; fi
    run cargo new "$PROJECT_NAME"
    in_project cargo add eframe egui
    _dt_egui_main
    return 0
}

_dt_egui_main() {
    if [ "$DRY_RUN" = 1 ]; then dim "  would write src/main.rs (minimal eframe app)"; return 0; fi
    cat > "$PROJECT_DIR/src/main.rs" <<'EOF'
use eframe::egui;

fn main() -> eframe::Result<()> {
    eframe::run_native(
        "app",
        eframe::NativeOptions::default(),
        Box::new(|_cc| Ok(Box::<App>::default())),
    )
}

#[derive(Default)]
struct App;

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Hello from sprout 🌱");
        });
    }
}
EOF
    dim "  egui API shifts between versions — adjust src/main.rs if it doesn't compile"
    return 0
}

_dt_git() {
    [ "$GIT_INIT" = 1 ] || return 0
    head "git init + first commit"
    if ! have git; then warn "git not found — skipping"; return 0; fi
    in_project git init -q
    in_project git add -A
    in_project git commit -q -m "chore: scaffold with sprout 🌱" || warn "nothing committed"
    return 0
}

recipe_run() {
    STACK="${STACK:-tauri}"; LANG="${LANG:-ts}"
    STACK_LABEL="$STACK"; [ "$STACK" = tauri ] && STACK_LABEL="$STACK · $LANG"

    head "1 · scaffold ($STACK)"
    [ -e "$PROJECT_DIR" ] && [ "$DRY_RUN" != 1 ] && { err "path already exists: $PROJECT_DIR"; exit 1; }
    case "$STACK" in
        tauri) _dt_tauri ;;
        wails) _dt_wails ;;
        fyne)  _dt_fyne ;;
        egui)  _dt_egui ;;
        *) err "unknown desktop stack '$STACK' (use tauri|wails|fyne|egui)"; exit 1 ;;
    esac
    if [ "$DRY_RUN" = 1 ]; then run mkdir -p "$PROJECT_DIR"; fi

    head "2 · overlay"
    apply_overlay "$PROJECT_DIR" desktop

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
    _dt_git

    head "done"
    ok "project '$PROJECT_NAME' ready at $PROJECT_DIR"
    dim "  stack: $STACK_LABEL"
    dim "  next:  cd $PROJECT_NAME  &&  divvy"
}
