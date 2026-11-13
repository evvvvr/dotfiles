#!/usr/bin/env bash
# Terminal effects for the dotfiles scripts: banner, numbered steps, spinner,
# progress bar and a summary table. Source this file.
#
# Pure bash and bash 3.2 safe (macOS /bin/bash), no extra tools, so it also works
# before Homebrew has installed anything. It degrades to plain text when stdout is
# not a terminal (logs, pipes), when NO_COLOR is set, when TERM=dumb, or when
# UI_PLAIN=1 is exported.

UI_FANCY=false
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${UI_PLAIN:-}" ]; then
  UI_FANCY=true
fi

if $UI_FANCY; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'
  CURSOR_HIDE=$'\033[?25l'; CURSOR_SHOW=$'\033[?25h'; CLEAR_LINE=$'\r\033[K'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_MAGENTA=""; C_CYAN=""; CURSOR_HIDE=""; CURSOR_SHOW=""; CLEAR_LINE=""
fi

UI_TOTAL=0
UI_N=0
UI_RES_LABEL=(); UI_RES_STATUS=(); UI_RES_TIME=(); UI_RES_NOTE=()
UI_START=$SECONDS

_ui_rep() {  # _ui_rep <char> <count>
  local i s=""
  for ((i = 0; i < $2; i++)); do s="$s$1"; done
  printf '%s' "$s"
}

# Display length in characters, independent of the caller's locale (${#var} counts
# bytes in the C locale, which would misalign boxes around "·" or "—").
_ui_len() { printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }

# ui_banner "title" ["subtitle"]
ui_banner() {
  local title="$1" sub="${2:-}"
  local tl sl w
  tl=$(_ui_len "$title"); sl=$(_ui_len "$sub")
  w=$tl
  [ "$sl" -gt "$w" ] && w=$sl
  if $UI_FANCY; then
    echo
    echo "${C_MAGENTA}╭$(_ui_rep ─ $((w + 4)))╮${C_RESET}"
    printf '%s│%s  %s%s%s%*s  %s│%s\n' "$C_MAGENTA" "$C_RESET" "$C_BOLD" "$title" "$C_RESET" $((w - tl)) "" "$C_MAGENTA" "$C_RESET"
    if [ -n "$sub" ]; then
      printf '%s│%s  %s%s%s%*s  %s│%s\n' "$C_MAGENTA" "$C_RESET" "$C_DIM" "$sub" "$C_RESET" $((w - sl)) "" "$C_MAGENTA" "$C_RESET"
    fi
    echo "${C_MAGENTA}╰$(_ui_rep ─ $((w + 4)))╯${C_RESET}"
  else
    echo "== ${title}${sub:+ - $sub} =="
  fi
}

ui_total() { UI_TOTAL=$1; UI_N=0; }

# Pure (no side effects): safe to call inside $(...). The counter is advanced by
# the callers, because an increment inside a subshell would be lost.
_ui_step_prefix() {
  if [ "$UI_TOTAL" -gt 0 ]; then
    printf '%s[%d/%d]%s' "$C_CYAN" "$UI_N" "$UI_TOTAL" "$C_RESET"
  else
    printf '%s[%d]%s' "$C_CYAN" "$UI_N" "$C_RESET"
  fi
}

_ui_record() {  # label status seconds note
  UI_RES_LABEL+=("$1"); UI_RES_STATUS+=("$2"); UI_RES_TIME+=("$3"); UI_RES_NOTE+=("${4:-}")
}

# ui_run "label" command...   run a command with a spinner; output is captured and
# only shown if the command fails. Returns the command's exit status.
ui_run() {
  local label="$1"; shift
  local prefix out start rc=0 pid
  UI_N=$((UI_N + 1))
  prefix="$(_ui_step_prefix)"
  out="$(mktemp)"
  start=$SECONDS

  if $UI_FANCY; then
    local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0
    "$@" >"$out" 2>&1 &
    pid=$!
    trap 'printf "%s" "$CURSOR_SHOW"; kill "$pid" 2>/dev/null; rm -f "$out"; exit 130' INT
    printf '%s' "$CURSOR_HIDE"
    while kill -0 "$pid" 2>/dev/null; do
      printf '%s%s %s%s%s %s %s%ds%s' "$CLEAR_LINE" "$prefix" "$C_CYAN" "${frames[i % 10]}" "$C_RESET" "$label" "$C_DIM" $((SECONDS - start)) "$C_RESET"
      i=$((i + 1)); sleep 0.1
    done
    wait "$pid"; rc=$?
    printf '%s%s' "$CLEAR_LINE" "$CURSOR_SHOW"
    trap - INT
  else
    echo "$prefix $label ..."
    "$@"; rc=$?
  fi

  _ui_finish "$prefix" "$label" "$rc" $((SECONDS - start)) "$out"
  rm -f "$out"
  return $rc
}

_ui_finish() {  # prefix label rc seconds [captured-output-file]
  if [ "$3" -eq 0 ]; then
    echo "$1 ${C_GREEN}✓${C_RESET} $2 ${C_DIM}($4s)${C_RESET}"
    _ui_record "$2" ok "$4"
  else
    echo "$1 ${C_RED}✗${C_RESET} $2 ${C_DIM}($4s, exit $3)${C_RESET}"
    [ -n "${5:-}" ] && [ -s "$5" ] && sed 's/^/      /' "$5" | tail -n 15
    _ui_record "$2" fail "$4" "exit $3"
  fi
}

# ui_stream "label" command...   like ui_run, but the command's output stays visible
# and it may read the terminal. Use it for steps that can prompt (sudo, 1Password)
# or whose output is worth reading (brew, upgrades).
ui_stream() {
  local label="$1"; shift
  local prefix start rc=0
  UI_N=$((UI_N + 1))
  prefix="$(_ui_step_prefix)"
  echo "$prefix ${C_BOLD}$label${C_RESET}"
  start=$SECONDS
  "$@"; rc=$?
  _ui_finish "$prefix" "$label" "$rc" $((SECONDS - start))
  return $rc
}

# ui_skip "label" "reason"
ui_skip() {
  UI_N=$((UI_N + 1))
  echo "$(_ui_step_prefix) ${C_YELLOW}↷${C_RESET} $1 ${C_DIM}(skipped: $2)${C_RESET}"
  _ui_record "$1" skip 0 "$2"
}

# ui_bar <current> <total> ["label"]   in-place progress bar (terminal only)
ui_bar() {
  local cur=$1 total=$2 label="${3:-}" width=30
  local filled=$((cur * width / total))
  if $UI_FANCY; then
    printf '%s%s%s%s%s%s %3d%% %s' "$CLEAR_LINE" "$C_GREEN" "$(_ui_rep █ "$filled")" "$C_DIM" "$(_ui_rep ░ $((width - filled)))" "$C_RESET" $((cur * 100 / total)) "$label"
    [ "$cur" -ge "$total" ] && echo
  else
    [ "$cur" -ge "$total" ] && echo "$label 100%"
  fi
  return 0
}

# ui_summary   table of every ui_run / ui_skip so far
ui_summary() {
  local n=${#UI_RES_LABEL[@]} i ok=0 fail=0 skip=0 icon col
  echo
  echo "${C_BOLD}Summary${C_RESET}"
  for ((i = 0; i < n; i++)); do
    case "${UI_RES_STATUS[i]}" in
      ok)   icon="✓"; col=$C_GREEN;  ok=$((ok + 1)) ;;
      fail) icon="✗"; col=$C_RED;    fail=$((fail + 1)) ;;
      *)    icon="↷"; col=$C_YELLOW; skip=$((skip + 1)) ;;
    esac
    printf '  %s%s%s %-44s %s%4ss  %s%s\n' "$col" "$icon" "$C_RESET" "${UI_RES_LABEL[i]}" "$C_DIM" "${UI_RES_TIME[i]}" "${UI_RES_NOTE[i]}" "$C_RESET"
  done
  echo "  ${C_DIM}────────────────────────────────────────────────────${C_RESET}"
  printf '  %s%d ok%s  %s%d skipped%s  %s%d failed%s  %s· %ds total%s\n' \
    "$C_GREEN" "$ok" "$C_RESET" "$C_YELLOW" "$skip" "$C_RESET" "$C_RED" "$fail" "$C_RESET" "$C_DIM" $((SECONDS - UI_START)) "$C_RESET"
  [ "$fail" -eq 0 ]
}
