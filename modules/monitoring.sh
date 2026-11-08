#!/usr/bin/env bash

show_overview() {
  printf 'Нагрузка:  '; uptime
  printf '\nПамять:\n'; free -h
  printf '\nДиски:\n'; df -hT -x tmpfs -x devtmpfs
  printf '\nСеть:\n'; ip -br addr 2>/dev/null || true
}

monitoring_menu() {
  local c
  while true; do
    header
    box "Мониторинг"       "1. Общая информация"       "2. Диски"       "3. Память и Swap"       "4. Процессы по памяти"       "5. Процессы по CPU"       ""       "6. Открытые порты"       "7. Активные TCP-соединения"       "8. Сетевые интерфейсы"       ""       "9. btop"       "10. htop"       "0. Назад"
    printf '\n'
    ask_num "Выбор [0-10]: "; c=$REPLY
    case $c in
      1) show_overview; pause ;; 2) df -hT -x tmpfs -x devtmpfs; pause ;; 3) free -h; pause ;;
      4) ps aux --sort=-%mem | head -25; pause ;; 5) ps aux --sort=-%cpu | head -25; pause ;;
      6) ss -lntup; pause ;; 7) ss -tnp; pause ;; 8) ip -br addr; echo; ip route; pause ;;
      9) if command_exists btop; then btop; else confirm "Установить btop?" && apt-get update && apt-get install -y btop; fi ;;
      10) if command_exists htop; then htop; else confirm "Установить htop?" && apt-get update && apt-get install -y htop; fi ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
