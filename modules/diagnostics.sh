#!/usr/bin/env bash

quick_check() {
  printf 'БЫСТРАЯ ПРОВЕРКА\n\n'
  local svc use
  svc=$(ssh_service_name)
  systemctl is-active --quiet "$svc" 2>/dev/null && ok "SSH работает" || err "SSH не работает"
  sshd -t 2>/dev/null && ok "Конфигурация SSH корректна" || err "Ошибка конфигурации SSH"
  [[ $(ssh_port) != 22 ]] && ok "SSH-порт: $(ssh_port)" || warn "Используется стандартный SSH-порт 22"
  [[ $(ssh_password_state) == отключён ]] && ok "Вход по SSH-паролю отключён" || warn "Вход по SSH-паролю разрешён"
  has_authorized_key_for_login_user && ok "SSH-ключ для $(active_login_user) найден" || warn "SSH-ключ для $(active_login_user) не найден"
  if ufw_active; then
    ufw_ssh_allowed && ok "UFW включён, SSH-порт разрешён" || warn "UFW включён, но правило текущего SSH-порта не найдено"
  else
    warn "UFW не включён"
  fi
  fail2ban_ssh_protected && ok "Fail2ban защищает SSH" || warn "Fail2ban SSH jail не активен"
  case "$(docker_runtime_state)" in
    RUNNING) ok "Docker работает" ;;
    STOPPED) warn "Docker установлен, но остановлен" ;;
    ERROR) err "Docker service активен, daemon не отвечает" ;;
    *) info "Docker не установлен" ;;
  esac
  getent ahosts github.com >/dev/null 2>&1 && ok "DNS работает" || err "DNS не отвечает"
  curl -fsS --max-time 5 -o /dev/null https://github.com 2>/dev/null && ok "HTTPS-доступ в интернет работает" || warn "HTTPS-проверка github.com не прошла"
  use=$(df -P / | awk 'NR==2{gsub("%","");print $5}')
  (( use < 85 )) && ok "Корневой диск занят на ${use}%" || warn "Корневой диск занят на ${use}%"
  [[ -f /var/run/reboot-required ]] && warn "Требуется перезагрузка" || ok "Перезагрузка не требуется"
  local updates
  updates=$(count_updates)
  (( updates == 0 )) && ok "Нет ожидающих обновлений пакетов" || warn "Доступно обновлений: $updates"
}

full_check() {
  quick_check
  printf '\nСЛУЖБЫ С ОШИБКАМИ\n'
  systemctl --failed --no-pager || true
  printf '\nОТКРЫТЫЕ ПОРТЫ\n'
  ss -lntup || true
  printf '\nДИСКИ\n'
  df -hT -x tmpfs -x devtmpfs || true
  printf '\nПАМЯТЬ\n'
  free -h || true
  printf '\nПОСЛЕДНИЕ ОШИБКИ ЯДРА/СИСТЕМЫ\n'
  journalctl -p 0..3 -n 40 --no-pager 2>/dev/null || true
}

safe_fix() {
  printf 'БЕЗОПАСНЫЕ ИСПРАВЛЕНИЯ\n\n'
  if command_exists ufw && ! ufw_active; then warn "UFW установлен, но выключен — автоматически включать его SERVER-KIT не будет."; fi
  if command_exists fail2ban-client && ! systemctl is-active --quiet fail2ban; then
    confirm "Fail2ban установлен, но не запущен. Запустить?" && systemctl enable --now fail2ban
  fi
  if [[ -f /var/run/reboot-required ]]; then warn "Требуется перезагрузка — автоматически она не выполняется."; fi
  apt-get check >/dev/null 2>&1 && ok "APT: зависимости в порядке" || warn "APT сообщает о проблемах зависимостей"
}

diagnostics_menu() {
  local c
  while true; do
    header
    ui_top "DIAGNOSTICS" "server health"
    ui_blank
    ui_line "[01] Быстрая проверка"
    ui_line "[02] Полная проверка"
    ui_line "[03] Исправить безопасные проблемы"
    ui_blank
    ui_line "[04] Проверить SSH"
    ui_line "[05] Проверить DNS и HTTPS"
    ui_line "[06] Показать открытые порты"
    ui_line "[07] Показать службы с ошибками"
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "diagnostics › "; c=$REPLY
    case $c in
      1|01) quick_check; pause ;;
      2|02) full_check; pause ;;
      3|03) safe_fix; pause ;;
      4|04) ssh_validate; systemctl status "$(ssh_service_name)" --no-pager; pause ;;
      5|05) getent ahosts github.com | head; curl -I --max-time 8 https://github.com 2>/dev/null | head; pause ;;
      6|06) ss -lntup; pause ;;
      7|07) systemctl --failed --no-pager; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
