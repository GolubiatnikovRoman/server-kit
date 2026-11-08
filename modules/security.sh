#!/usr/bin/env bash

install_fail2ban() {
  command_exists fail2ban-client && { warn "Fail2ban уже установлен"; return; }
  confirm "Установить Fail2ban?" || return
  apt-get update && apt-get install -y fail2ban
  mkdir -p /etc/fail2ban/jail.d
  cat > /etc/fail2ban/jail.d/serverkit-sshd.local <<'CFG'
[sshd]
enabled = true
backend = systemd
bantime = 1h
findtime = 10m
maxretry = 5
CFG
  systemctl enable --now fail2ban
  fail2ban-client reload >/dev/null 2>&1 || true
  ok "Fail2ban установлен и защита SSH включена"
}

enable_unattended_upgrades() {
  if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
    confirm "Установить unattended-upgrades?" || return
    apt-get update && apt-get install -y unattended-upgrades
  fi
  dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
  systemctl enable --now apt-daily-upgrade.timer >/dev/null 2>&1 || true
  ok "Автоматические обновления безопасности включены"
}

security_basic_audit() {
  printf 'БАЗОВАЯ ПРОВЕРКА БЕЗОПАСНОСТИ\n\n'
  [[ $(ssh_password_state) == отключён ]] && ok "SSH: вход по паролю отключён" || warn "SSH: вход по паролю разрешён"
  [[ $(ssh_port) != 22 ]] && ok "SSH: используется порт $(ssh_port)" || warn "SSH: используется стандартный порт 22"
  ufw_active && ok "UFW активен" || warn "UFW не активен"
  systemctl is-active --quiet fail2ban 2>/dev/null && ok "Fail2ban работает" || warn "Fail2ban не работает"
  systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null && ok "Автоматические обновления включены" || warn "Автоматические обновления не подтверждены"
  [[ -f /var/run/reboot-required ]] && warn "Сервер требует перезагрузки" || ok "Перезагрузка не требуется"
}

security_menu() {
  local c f2b
  while true; do
    header
    systemctl is-active --quiet fail2ban 2>/dev/null && f2b="работает" || f2b="не работает"
    box "Безопасность · Fail2ban: $f2b"       "1. Установить и включить Fail2ban"       "2. Статус Fail2ban"       "3. Статус защиты SSH"       "4. Разблокировать IP"       "5. Последние неудачные SSH-входы"       ""       "6. Автоматические security-обновления"       "7. Базовая проверка безопасности"       "0. Назад"
    printf '\n'
    ask_num "Выбор [0-7]: "; c=$REPLY
    case $c in
      1) install_fail2ban; pause ;;
      2) fail2ban-client status 2>/dev/null || err "Fail2ban недоступен"; pause ;;
      3) fail2ban-client status sshd 2>/dev/null || err "Jail sshd недоступен"; pause ;;
      4) read -r -p 'IP-адрес: ' ip; safe_name "$ip" && fail2ban-client set sshd unbanip "$ip" 2>/dev/null || err "Не удалось разблокировать IP"; pause ;;
      5) journalctl -u ssh -u sshd --since '-24 hours' --no-pager 2>/dev/null | grep -Ei 'failed|invalid user|authentication failure' | tail -100 || true; pause ;;
      6) enable_unattended_upgrades; pause ;; 7) security_basic_audit; pause ;; 0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
