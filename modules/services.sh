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
    ui_top "СЛУЖБЫ" "systemd"
    ui_blank
    ui_line "[01] Активные службы"
    ui_line "[02] Все службы"
    ui_line "[03] Неудавшиеся службы"
    ui_blank
    ui_line "[04] Состояние службы"
    ui_line "[05] Запустить службу"
    ui_line "[06] Остановить службу"
    ui_line "[07] Перезапустить службу"
    ui_line "[08] Включить автозапуск"
    ui_line "[09] Отключить автозапуск"
    ui_line "[10] Логи службы"
    ui_line "[00] Назад"
    ui_bottom
    printf '\n'
    ask_num "Выберите пункт: "; c=$REPLY
    case $c in
      1|01) systemctl --type=service --state=running --no-pager; pause ;;
      2|02) systemctl list-units --type=service --all --no-pager; pause ;;
      3|03) systemctl --failed --no-pager; pause ;;
      4|04) n=$(ask_service) && systemctl status "$n" --no-pager; pause ;;
      5|05) n=$(ask_service) && if systemctl is-active --quiet "$n"; then warn "$n уже запущена"; else confirm "Запустить $n?" && systemctl start "$n"; fi; pause ;;
      6|06) n=$(ask_service) && if systemctl is-active --quiet "$n"; then confirm "Остановить $n?" && systemctl stop "$n"; else warn "$n уже остановлена"; fi; pause ;;
      7|07) n=$(ask_service) && confirm "Перезапустить $n?" && systemctl restart "$n"; pause ;;
      8|08) n=$(ask_service) && if systemctl is-enabled --quiet "$n"; then warn "Автозапуск $n уже включён"; else systemctl enable "$n"; fi; pause ;;
      9|09) n=$(ask_service) && if systemctl is-enabled --quiet "$n"; then confirm "Отключить автозапуск $n?" && systemctl disable "$n"; else warn "Автозапуск $n уже выключен"; fi; pause ;;
      10) n=$(ask_service) && journalctl -u "$n" -n 150 --no-pager; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
