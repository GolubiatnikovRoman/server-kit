#!/usr/bin/env bash

# Стабильная UTF-8 ширина для рамок и русского текста.
if locale -a 2>/dev/null | grep -qi '^C\.UTF-8$'; then
  export LC_ALL=C.UTF-8
elif locale -a 2>/dev/null | grep -qi '^C\.utf8$'; then
  export LC_ALL=C.utf8
fi

if [[ -t 1 ]]; then
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'
  C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_RESET=$'\e[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_BOLD=''; C_DIM=''; C_RESET=''
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

ui_wide() { (( TERM_COLS >= 92 )); }

ui_repeat() {
  local ch=$1 n=$2 i
  for ((i=0; i<n; i++)); do printf '%s' "$ch"; done
}

visible_len() {
  local clean
  clean=$(printf '%s' "$1" | sed -E 

ui_top() {
  printf '╭─ %s%s%s ' "$C_BOLD" "$1" "$C_RESET"
  local used=$(( ${#1} + 4 ))
  ui_repeat '─' $((BOX_W - used - ${#2} - 3))
  printf ' %s%s%s ─╮\n' "$C_DIM" "$2" "$C_RESET"
}

ui_bottom() {
  printf '╰'
  ui_repeat '─' $((BOX_W - 2))
  printf '╯\n'
}

ui_sep() {
  printf '├'
  ui_repeat '─' $((BOX_W - 2))
  printf '┤\n'
}

ui_section() {
  local title=$1
  printf '├─ %s%s%s ' "$C_CYAN" "$title" "$C_RESET"
  ui_repeat '─' $((BOX_W - ${#title} - 5))
  printf '┤\n'
}

ui_line() {
  printf '│  %s│\n' "$(pad_right "$1" $((BOX_W - 3)))"
}

ui_blank() { ui_line ""; }

ui_two() {
  local left=$1 right=$2
  if ui_wide; then
    local half=$(( (BOX_W - 7) / 2 ))
    printf '│  %s  %s│\n' "$(pad_right "$left" "$half")" "$(pad_right "$right" "$half")"
  else
    ui_line "$left"
    [[ -n $right ]] && ui_line "$right"
  fi
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

box_rule() { ui_repeat '─' "$BOX_W"; }
box_top() { printf '╔'; box_rule; printf '╗\n'; }
box_bottom() { printf '╚'; box_rule; printf '╝\n'; }
box_sep() { printf '│'; box_rule; printf '│\n'; }
box_line() { printf '│  %s│\n' "$(pad_right "$1" $((BOX_W - 2)))"; }

box() {
  local title=$1 line
  shift
  box_top
  box_line "$title"
  box_sep
  for line in "$@"; do
    if [[ -z $line ]]; then box_sep; else box_line "$line"; fi
  done
  box_bottom
}

header() { clear 2>/dev/null || true; }

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
    case $REPLY in 1) return 0 ;; 2|0|"") return 1 ;; *) warn "Нет такого пункта." ;; esac
  done
}
s/\033\\[[0-9;]*[[:alpha:]]//g')
  printf '%s' "${#clean}"
}

pad_right() {
  local text=$1 width=$2 n len
  len=$(visible_len "$text")
  n=$((width - len))
  ((n < 0)) && n=0
  printf '%s%*s' "$text" "$n" ''
}

ui_top() {
  printf '╭─ %s%s%s ' "$C_BOLD" "$1" "$C_RESET"
  local used=$(( ${#1} + 4 ))
  ui_repeat '─' $((BOX_W - used - ${#2} - 3))
  printf ' %s%s%s ─╮\n' "$C_DIM" "$2" "$C_RESET"
}

ui_bottom() {
  printf '╰'
  ui_repeat '─' $((BOX_W - 2))
  printf '╯\n'
}

ui_sep() {
  printf '├'
  ui_repeat '─' $((BOX_W - 2))
  printf '┤\n'
}

ui_section() {
  local title=$1
  printf '├─ %s%s%s ' "$C_CYAN" "$title" "$C_RESET"
  ui_repeat '─' $((BOX_W - ${#title} - 5))
  printf '┤\n'
}

ui_line() {
  printf '│  %s│\n' "$(pad_right "$1" $((BOX_W - 3)))"
}

ui_blank() { ui_line ""; }

ui_two() {
  local left=$1 right=$2
  if ui_wide; then
    local half=$(( (BOX_W - 7) / 2 ))
    printf '│  %s  %s│\n' "$(pad_right "$left" "$half")" "$(pad_right "$right" "$half")"
  else
    ui_line "$left"
    [[ -n $right ]] && ui_line "$right"
  fi
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

box_rule() { ui_repeat '─' "$BOX_W"; }
box_top() { printf '╔'; box_rule; printf '╗\n'; }
box_bottom() { printf '╚'; box_rule; printf '╝\n'; }
box_sep() { printf '│'; box_rule; printf '│\n'; }
box_line() { printf '│  %s│\n' "$(pad_right "$1" $((BOX_W - 2)))"; }

box() {
  local title=$1 line
  shift
  box_top
  box_line "$title"
  box_sep
  for line in "$@"; do
    if [[ -z $line ]]; then box_sep; else box_line "$line"; fi
  done
  box_bottom
}

header() { clear 2>/dev/null || true; }

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
    case $REPLY in 1) return 0 ;; 2|0|"") return 1 ;; *) warn "Нет такого пункта." ;; esac
  done
}
