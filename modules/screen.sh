#!/usr/bin/env bash

screen_menu() {
  local c
  while true; do
    header
    if command_exists screen; then
      box "Screen-сессии"         "1. Установить Screen"         "2. Создать фоновую сессию"         "3. Создать и сразу подключиться"         "4. Подключиться к сессии"         "5. Переподключиться к занятой сессии"         "6. Завершить сессию"         "0. Назад"
      printf '\n'; screen -ls || true
    else
      box "Screen-сессии · Screen не установлен"         "1. Установить Screen"         "0. Назад"
    fi
    printf '\n'
    ask_num "Выбор [0-6]: "; c=$REPLY
    case $c in
      1) if command_exists screen; then warn "Screen уже установлен"; else confirm "Установить Screen?" && apt-get update && apt-get install -y screen; fi; pause ;;
      2) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -dmS "$n" && ok "Сессия $n создана" || err "Не удалось создать сессию"; pause ;;
      3) read -r -p 'Имя сессии: ' n; safe_name "$n" && screen -S "$n" ;;
      4) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -r "$n" ;;
      5) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && screen -d -r "$n" ;;
      6) read -r -p 'Имя/ID сессии: ' n; safe_name "$n" && confirm "Завершить сессию $n?" && screen -S "$n" -X quit; pause ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
