#!/usr/bin/env bash

show_overview() {
  printf 'Нагрузка:  '; uptime
  printf '\nПамять:\n'; free -h
  printf '\nДиски:\n'; df -hT -x tmpfs -x devtmpfs
  printf '\nСеть:\n'; ip -br addr 2>/dev/null || true
}

monitoring_menu() {
  local c btop_label htop_label
  while true; do
    header
    command_exists btop && btop_label="btop" || btop_label="Установить btop"
    command_exists htop && htop_label="htop" || htop_label="Установить htop"

    ui_top "МОНИТОРИНГ" "Система"
    ui_blank
    ui_line "[01] Общая информация"
    ui_line "[02] Диски"
    ui_line "[03] Память и Swap"
    ui_line "[04] Процессы по памяти"
    ui_line "[05] Процессы по CPU"
    ui_blank
    ui_line "[06] Открытые порты"
    ui_line "[07] Активные TCP-соединения"
    ui_line "[08] Сетевые интерфейсы"
    ui_blank
    ui_line "[09] $btop_label"
    ui_line "[10] $htop_label"
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "Выберите пункт: "; c=$REPLY
    case $c in
      1|01) show_overview; pause ;;
      2|02) df -hT -x tmpfs -x devtmpfs; pause ;;
      3|03) free -h; pause ;;
      4|04) ps aux --sort=-%mem | head -25; pause ;;
      5|05) ps aux --sort=-%cpu | head -25; pause ;;
      6|06) ss -lntup; pause ;;
      7|07) ss -tnp; pause ;;
      8|08) ip -br addr; echo; ip route; pause ;;
      9|09) if command_exists btop; then btop; else confirm "Установить btop?" && apt-get update && apt-get install -y btop; fi ;;
      10) if command_exists htop; then htop; else confirm "Установить htop?" && apt-get update && apt-get install -y htop; fi ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
