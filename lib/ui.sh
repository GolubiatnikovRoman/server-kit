#!/usr/bin/env bash

if locale -a 2>/dev/null | grep -qi '^C\.UTF-8$'; then
  export LC_ALL=C.UTF-8
elif locale -a 2>/dev/null | grep -qi '^C\.utf8$'; then
  export LC_ALL=C.utf8
fi

if [[ -t 1 ]]; then
  C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'
  C_RED=$'\e[31m'
  C_CYAN=$'\e[36m'
  C_BOLD=$'\e[1m'
  C_DIM=$'\e[2m'
  C_RESET=$'\e[0m'
else
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
  C_CYAN=''
  C_BOLD=''
  C_DIM=''
  C_RESET=''
fi

ok()   { printf '%s==>%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s!%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s✗%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
info() { printf '%s==>%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }

TERM_COLS=$(tput cols 2>/dev/null || echo 80)
if (( TERM_COLS >= 92 )); then
  BOX_W=72
else
  BOX_W=58
fi

# BOX_W = полная видимая ширина строки, включая левую и правую границу.
INNER_W=$((BOX_W - 2))

ui_wide() { (( TERM_COLS >= 92 )); }

ui_repeat() {
  local ch=$1 n=$2 i
  ((n < 0)) && n=0
  for ((i=0; i<n; i++)); do
    printf '%s' "$ch"
  done
}

visible_len() {
  local clean
  clean=$(printf '%s' "$1" | sed -E $'s/\033\\[[0-9;]*[[:alpha:]]//g')
  printf '%s' "${#clean}"
}

pad_right() {
  local text=$1 width=$2 len pad
  len=$(visible_len "$text")
  pad=$((width - len))
  ((pad < 0)) && pad=0
  printf '%s%*s' "$text" "$pad" ''
}

ui_top() {
  local title=$1 right=${2:-}
  local prefix="─ $title "
  local suffix
  if [[ -n $right ]]; then
    suffix=" $right ─"
  else
    suffix="─"
  fi

  local prefix_len suffix_len fill
  prefix_len=${#prefix}
  suffix_len=${#suffix}
  fill=$((INNER_W - prefix_len - suffix_len))

  printf '╭%s%s%s' "$C_BOLD" "$prefix" "$C_RESET"
  ui_repeat '─' "$fill"
  if [[ -n $right ]]; then
    printf ' %s%s%s ─' "$C_DIM" "$right" "$C_RESET"
  else
    printf '─'
  fi
  printf '╮\n'
}

ui_bottom() {
  printf '╰'
  ui_repeat '─' "$INNER_W"
  printf '╯\n'
}

ui_sep() {
  printf '├'
  ui_repeat '─' "$INNER_W"
  printf '┤\n'
}

ui_section() {
  local title=$1
  local left="─ $title "
  local fill=$((INNER_W - ${#left}))
  printf '├%s%s%s' "$C_CYAN" "$left" "$C_RESET"
  ui_repeat '─' "$fill"
  printf '┤\n'
}

ui_line() {
  local text=$1
  printf '│%s│\n' "$(pad_right "  $text" "$INNER_W")"
}

ui_blank() {
  printf '│%*s│\n' "$INNER_W" ''
}

ui_two() {
  local left=$1 right=$2
  if ! ui_wide; then
    ui_line "$left"
    [[ -n $right ]] && ui_line "$right"
    return
  fi

  local gap=3
  local left_w=$(( (INNER_W - 4 - gap) / 2 ))
  local right_w=$(( INNER_W - 4 - gap - left_w ))

  printf '│  %s%*s%s  │\n'     "$(pad_right "$left" "$left_w")" "$gap" '' "$(pad_right "$right" "$right_w")"
}

ui_status() {
  local label=$1 state=$2 kind=${3:-ok} color
  case $kind in
    ok) color=$C_GREEN ;;
    warn) color=$C_YELLOW ;;
    bad) color=$C_RED ;;
    *) color=$C_DIM ;;
  esac
  printf '%s  ● %s%s%s' "$label" "$color" "$state" "$C_RESET"
}

# Совместимость со старыми меню.
box_rule() {
  ui_repeat '─' "$INNER_W"
}

box_top() {
  printf '╭'
  box_rule
  printf '╮\n'
}

box_bottom() {
  printf '╰'
  box_rule
  printf '╯\n'
}

box_sep() {
  printf '├'
  box_rule
  printf '┤\n'
}

box_line() {
  ui_line "$1"
}

box() {
  local title=$1 line
  shift
  ui_top "$title"
  for line in "$@"; do
    if [[ -z $line ]]; then
      ui_blank
    else
      ui_line "$line"
    fi
  done
  ui_bottom
}

header() {
  clear 2>/dev/null || true
}

pause() {
  printf '\n%sEnter – в меню%s ' "$C_DIM" "$C_RESET"
  read -r _ || true
}

ask_num() {
  local prompt=$1
  read -r -p "$prompt" REPLY || return 1
  REPLY=${REPLY//[[:space:]]/}
}

confirm() {
  local prompt=${1:-"Продолжить?"} answer
  printf '%s [д/Н]: ' "$prompt"
  read -r answer || return 1
  [[ ${answer,,} == "д" || ${answer,,} == "да" || ${answer,,} == "y" || ${answer,,} == "yes" ]]
}

choose_yes_no() {
  local prompt=$1
  while true; do
    box "$prompt" "1. Да" "2. Нет"
    ask_num "Выбор [1-2]: "
    case $REPLY in
      1) return 0 ;;
      2|0|"") return 1 ;;
      *) warn "Нет такого пункта." ;;
    esac
  done
}
