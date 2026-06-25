# prompt.sh — interactive wizard helpers for sprout. POSIX sh.
# Line prompts (ask_yn/ask_value) plus a real TTY picker (pick_one/pick_many):
# ↑/↓ or j/k move · space toggles · a all · enter confirm · q/ESC cancel.
# All UI is drawn on /dev/tty and input read from /dev/tty, so the selection can
# be captured with $(...) while the menu still renders. Degrades to defaults when
# there is no terminal or NONINTERACTIVE=1 (CI uses the flag-based code path).

_TTY=/dev/tty

# ── line prompts ─────────────────────────────────────────────────────────────

# ask_yn "question" default(y|n) -> 0=yes 1=no
ask_yn() {
    _def="$2"
    if [ "${NONINTERACTIVE:-0}" = 1 ] || [ ! -t 0 ]; then
        [ "$_def" = y ] && return 0 || return 1
    fi
    _hint="[y/N]"; [ "$_def" = y ] && _hint="[Y/n]"
    printf '%s %s: ' "$1" "$_hint"
    read _a 2>/dev/null || _a=""
    [ -z "$_a" ] && _a="$_def"
    case "$_a" in y|Y|yes|YES|si|SI) return 0 ;; *) return 1 ;; esac
}

# ask_value "question" "default" -> echoes chosen value
ask_value() {
    if [ "${NONINTERACTIVE:-0}" = 1 ] || [ ! -t 0 ]; then
        printf '%s' "$2"; return 0
    fi
    printf '%s [%s]: ' "$1" "$2" >&2
    read _a 2>/dev/null || _a=""
    [ -z "$_a" ] && _a="$2"
    printf '%s' "$_a"
}

# ── interactive picker engine ────────────────────────────────────────────────

# True when we can drive an interactive menu on this terminal.
_pm_interactive() {
    [ "${NONINTERACTIVE:-0}" != 1 ] && [ -t 2 ] && [ -r "$_TTY" ] && \
        command -v stty >/dev/null 2>&1 && command -v od >/dev/null 2>&1
}

# read one byte from the tty, echo its decimal code (empty on timeout)
_pm_readbyte() { dd bs=1 count=1 2>/dev/null <"$_TTY" | od -An -tu1 | tr -dc '0-9'; }

# read one keypress, echo a token: up|down|space|enter|all|cancel|other
_pm_key() {
    _b=""
    while [ -z "$_b" ]; do _b="$(_pm_readbyte)"; done
    case "$_b" in
        27)  # ESC: maybe an arrow sequence (ESC [ A/B)
            _b2="$(_pm_readbyte)"
            case "$_b2" in
                91|79)
                    case "$(_pm_readbyte)" in
                        65) echo up ;; 66) echo down ;; *) echo other ;;
                    esac ;;
                '') echo cancel ;;   # bare ESC
                *)  echo other ;;
            esac ;;
        32)      echo space ;;
        10|13)   echo enter ;;
        107|112) echo up ;;     # k / p
        106|110) echo down ;;   # j / n
        97)      echo all ;;    # a
        113|3)   echo cancel ;; # q / Ctrl-C
        *)       echo other ;;
    esac
}

_pm_restore() {
    [ -n "${_pm_saved_stty:-}" ] && stty "$_pm_saved_stty" <"$_TTY" 2>/dev/null
    printf '\033[?25h' >"$_TTY" 2>/dev/null   # show cursor
}

# render the N item lines (cursor at _pm_cur). _pm_radio=1 hides the checkboxes.
_pm_render() {
    _j=1
    while [ "$_j" -le "$_pm_n" ]; do
        eval "_lab=\$_pm_lab_$_j; _on=\$_pm_on_$_j"
        if [ "${_pm_radio:-0}" = 1 ]; then
            _box=""
        else
            _box='[ ] '; [ "$_on" = 1 ] && _box='[x] '
        fi
        if [ "$_j" = "$_pm_cur" ]; then
            printf '\033[36m \342\235\257 %s%s\033[0m\033[K\n' "$_box" "$_lab" >"$_TTY"
        else
            printf '   %s%s\033[K\n' "$_box" "$_lab" >"$_TTY"
        fi
        _j=$((_j+1))
    done
}

# load newline-separated "value|label" specs into _pm_* state; preselect by $1
_pm_load() {
    _pre="$1"; _items="$2"
    _pm_n=0
    _oldifs="$IFS"; IFS='
'
    for _spec in $_items; do
        [ -n "$_spec" ] || continue
        _pm_n=$((_pm_n+1))
        case "$_spec" in
            *'|'*) _val="${_spec%%|*}"; _lab="${_spec#*|}" ;;
            *)     _val="$_spec"; _lab="$_spec" ;;
        esac
        eval "_pm_val_$_pm_n=\$_val"
        eval "_pm_lab_$_pm_n=\$_lab"
        case " $_pre " in *" $_val "*) eval "_pm_on_$_pm_n=1" ;; *) eval "_pm_on_$_pm_n=0" ;; esac
    done
    IFS="$_oldifs"
}

# pick_many "title" "preselected (space-sep values)" "items (newline-sep value|label)"
#   echoes the chosen values, space-separated. q/ESC keeps the preselection.
pick_many() {
    _title="$1"; _pre="$2"
    if ! _pm_interactive; then printf '%s' "$_pre"; return 0; fi
    _pm_radio=0; _pm_load "$_pre" "$3"
    [ "$_pm_n" -gt 0 ] || { printf '%s' "$_pre"; return 0; }

    _pm_saved_stty="$(stty -g <"$_TTY" 2>/dev/null)"
    stty -echo -icanon min 0 time 1 <"$_TTY" 2>/dev/null
    printf '\033[?25l' >"$_TTY"
    trap '_pm_restore' EXIT INT TERM

    _pm_cur=1
    printf '\033[1;36m%s\033[0m  \033[2m(\342\206\221/\342\206\223 move \302\267 space select \302\267 a all \302\267 enter ok \302\267 q cancel)\033[0m\n' "$_title" >"$_TTY"
    _pm_render
    while :; do
        case "$(_pm_key)" in
            up)    _pm_cur=$((_pm_cur-1)); [ "$_pm_cur" -lt 1 ] && _pm_cur=$_pm_n ;;
            down)  _pm_cur=$((_pm_cur+1)); [ "$_pm_cur" -gt "$_pm_n" ] && _pm_cur=1 ;;
            space) eval "_on=\$_pm_on_$_pm_cur"
                   if [ "$_on" = 1 ]; then eval "_pm_on_$_pm_cur=0"; else eval "_pm_on_$_pm_cur=1"; fi ;;
            all)   _pm_toggle_all ;;
            enter) break ;;
            cancel) _pm_restore; trap - EXIT INT TERM; printf '%s' "$_pre"; return 0 ;;
            *)     : ;;
        esac
        printf '\033[%dA' "$_pm_n" >"$_TTY"
        _pm_render
    done
    _pm_restore; trap - EXIT INT TERM

    _out=""; _j=1
    while [ "$_j" -le "$_pm_n" ]; do
        eval "_on=\$_pm_on_$_j; _val=\$_pm_val_$_j"
        [ "$_on" = 1 ] && _out="$_out $_val"
        _j=$((_j+1))
    done
    printf '%s' "$(printf '%s' "$_out" | sed 's/^ *//;s/ *$//')"
}

_pm_toggle_all() {
    _any_off=0; _j=1
    while [ "$_j" -le "$_pm_n" ]; do eval "_on=\$_pm_on_$_j"; [ "$_on" = 1 ] || _any_off=1; _j=$((_j+1)); done
    _target=0; [ "$_any_off" = 1 ] && _target=1
    _j=1
    while [ "$_j" -le "$_pm_n" ]; do eval "_pm_on_$_j=$_target"; _j=$((_j+1)); done
}

# pick_one "title" "default value" "items (newline-sep value|label)" -> echoes one value
pick_one() {
    _title="$1"; _def="$2"
    if ! _pm_interactive; then printf '%s' "$_def"; return 0; fi
    _pm_radio=1; _pm_load "" "$3"
    [ "$_pm_n" -gt 0 ] || { printf '%s' "$_def"; return 0; }

    _pm_cur=1; _j=1
    while [ "$_j" -le "$_pm_n" ]; do
        eval "_val=\$_pm_val_$_j"; [ "$_val" = "$_def" ] && _pm_cur=$_j
        _j=$((_j+1))
    done

    _pm_saved_stty="$(stty -g <"$_TTY" 2>/dev/null)"
    stty -echo -icanon min 0 time 1 <"$_TTY" 2>/dev/null
    printf '\033[?25l' >"$_TTY"
    trap '_pm_restore' EXIT INT TERM

    printf '\033[1;36m%s\033[0m  \033[2m(\342\206\221/\342\206\223 move \302\267 enter select)\033[0m\n' "$_title" >"$_TTY"
    _pm_render
    while :; do
        case "$(_pm_key)" in
            up)    _pm_cur=$((_pm_cur-1)); [ "$_pm_cur" -lt 1 ] && _pm_cur=$_pm_n ;;
            down)  _pm_cur=$((_pm_cur+1)); [ "$_pm_cur" -gt "$_pm_n" ] && _pm_cur=1 ;;
            enter|space) break ;;
            cancel) _pm_restore; trap - EXIT INT TERM; printf '%s' "$_def"; return 0 ;;
            *)     : ;;
        esac
        printf '\033[%dA' "$_pm_n" >"$_TTY"
        _pm_render
    done
    _pm_restore; trap - EXIT INT TERM

    eval "printf '%s' \"\$_pm_val_$_pm_cur\""
}

# ── legacy fallbacks (still used when piping / NONINTERACTIVE) ────────────────

# choose_one "question" item1 item2 ... -> echoes chosen item (default = first)
choose_one() {
    _q="$1"; shift
    if [ "${NONINTERACTIVE:-0}" = 1 ] || [ ! -t 0 ]; then printf '%s' "$1"; return 0; fi
    _i=1
    for _it in "$@"; do printf '  %d) %s\n' "$_i" "$_it" >&2; _i=$((_i+1)); done
    printf '%s [1]: ' "$_q" >&2
    read _n 2>/dev/null || _n=""
    [ -z "$_n" ] && _n=1
    eval "printf '%s' \"\${$_n:-$1}\""
}
