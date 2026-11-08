#!/usr/bin/env bash

screen_menu() {
  while true; do
    header; printf 'SCREEN-СЕССИИ\n\n'
    if command_exists screen; then screen -ls || true; else warn "Screen не установлен"; fi
    cat <<'MENU'

1. Установить Screen
2. Создать фоновую сессию
3. Создать и сразу подключиться
4. Подключиться к сессии
5. Переподключиться к занятой сессии (screen -d -r)
6. Завершить сессию
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) if command_exists screen; then warn "Screen уже установлен"; else confirm "Установить Screen?" && apt-get update && apt-get install -y screen; fi; pause ;;
      2) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -dmS "$n" && ok "Сессия $n создана" || err "Не удалось создать сессию"; pause ;;
      3) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -S "$n" ;;
      4) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -r "$n" ;;
      5) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -d -r "$n" ;;
      6) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && confirm "Завершить сессию $n?" && screen -S "$n" -X quit; pause ;;
      0) return ;;
    esac
  done
}
