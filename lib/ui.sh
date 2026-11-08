#!/usr/bin/env bash

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

BOX_W=52

box_rule() {
  local i
  for ((i=0; i<BOX_W; i++)); do printf '─'; done
}

box_top() { printf '╔'; box_rule; printf '╗\n'; }
box_bottom() { printf '╚'; box_rule; printf '╝\n'; }
box_sep() { printf '│'; box_rule; printf '│\n'; }

pad_right() {
  local text=$1 width=$2 n
  n=$((width - ${#text}))
  ((n < 0)) && n=0
  printf '%s%*s' "$text" "$n" ''
}

box_line() {
  printf '│  %s│\n' "$(pad_right "$1" $((BOX_W - 2)))"
}

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
    case $REPLY in 1) return 0 ;; 2|0|"") return 1 ;; *) warn "Нет такого пункта." ;; esac
  done
}
