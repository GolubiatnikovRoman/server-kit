#!/usr/bin/env bash

if [[ -t 1 ]]; then
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_BLUE=$'\e[36m'
  C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_RESET=$'\e[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''; C_BOLD=''; C_DIM=''; C_RESET=''
fi

ok()   { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[✗]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }

pause() { printf '\nНажмите Enter, чтобы продолжить...'; read -r _ || true; }

confirm() {
  local prompt=${1:-"Продолжить?"} answer
  printf '%s [д/Н]: ' "$prompt"
  read -r answer || return 1
  [[ ${answer,,} == "д" || ${answer,,} == "да" || ${answer,,} == "y" || ${answer,,} == "yes" ]]
}

choose_yes_no() {
  local prompt=$1
  while true; do
    printf '%s\n\n1. Да\n2. Нет\n\n' "$prompt"
    read -r -p 'Выберите действие: ' ans
    case $ans in 1) return 0 ;; 2|0) return 1 ;; *) warn "Выберите 1 или 2" ;; esac
  done
}

header() {
  clear 2>/dev/null || true
  printf '╭─────────────────────────────────────────────╮\n'
  printf '│                 SERVER-KIT                  │\n'
  printf '│                   v%-7s                  │\n' "$SERVERKIT_VERSION"
  printf '│          Управление Linux-сервером          │\n'
  printf '╰─────────────────────────────────────────────╯\n\n'
}
