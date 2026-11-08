#!/usr/bin/env bash

screen_menu() {
  local c
  while true; do
    header

    if ! command_exists screen; then
      ui_top "SCREEN" "не установлен"
      ui_blank
      ui_line "[01] Установить Screen"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "screen › "; c=$REPLY
      case $c in
        1|01) confirm "Установить Screen?" && apt-get update && apt-get install -y screen; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    ui_top "SCREEN" "sessions"
    ui_blank
    ui_line "[01] Создать фоновую сессию"
    ui_line "[02] Создать и сразу подключиться"
    ui_line "[03] Подключиться к сессии"
    ui_line "[04] Переподключиться к занятой сессии"
    ui_line "[05] Завершить сессию"
    ui_line "[00] Назад"
    ui_bottom
    printf '\n'
    screen -ls || true
    printf '\n'
    ask_num "screen › "; c=$REPLY
    case $c in
      1|01) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -dmS "$n" && ok "Сессия $n создана" || err "Не удалось создать сессию"; pause ;;
      2|02) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -S "$n" ;;
      3|03) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -r "$n" ;;
      4|04) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -d -r "$n" ;;
      5|05) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && confirm "Завершить сессию $n?" && screen -S "$n" -X quit; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
