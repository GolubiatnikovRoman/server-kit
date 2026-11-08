#!/usr/bin/env bash

ask_service() {
  local n
  read -r -p 'Название службы (например nginx): ' n
  safe_name "$n" || { err "Некорректное имя службы"; return 1; }
  printf '%s' "${n%.service}"
}

services_menu() {
  local c
  while true; do
    header
    box "Службы systemd"       "1. Активные службы"       "2. Все службы"       "3. Неудавшиеся службы"       ""       "4. Состояние службы"       "5. Запустить службу"       "6. Остановить службу"       "7. Перезапустить службу"       "8. Включить автозапуск"       "9. Отключить автозапуск"       "10. Логи службы"       "0. Назад"
    printf '\n'
    ask_num "Выбор [0-10]: "; c=$REPLY
    case $c in
      1) systemctl --type=service --state=running --no-pager; pause ;;
      2) systemctl list-units --type=service --all --no-pager; pause ;;
      3) systemctl --failed --no-pager; pause ;;
      4) n=$(ask_service) && systemctl status "$n" --no-pager; pause ;;
      5) n=$(ask_service) && confirm "Запустить $n?" && systemctl start "$n"; pause ;;
      6) n=$(ask_service) && confirm "Остановить $n?" && systemctl stop "$n"; pause ;;
      7) n=$(ask_service) && confirm "Перезапустить $n?" && systemctl restart "$n"; pause ;;
      8) n=$(ask_service) && systemctl enable "$n"; pause ;;
      9) n=$(ask_service) && confirm "Отключить автозапуск $n?" && systemctl disable "$n"; pause ;;
      10) n=$(ask_service) && journalctl -u "$n" -n 150 --no-pager; pause ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
