#!/usr/bin/env bash

fail2ban_ssh_protected() {
  command_exists fail2ban-client &&
    systemctl is-active --quiet fail2ban 2>/dev/null &&
    fail2ban-client status sshd >/dev/null 2>&1
}

security_updates_enabled() {
  dpkg -s unattended-upgrades >/dev/null 2>&1 &&
    systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null
}

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
  fail2ban_ssh_protected && ok "Fail2ban: SSH jail работает" || warn "Fail2ban: SSH jail не подтверждён"
  systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null && ok "Автоматические обновления включены" || warn "Автоматические обновления не подтверждены"
  [[ -f /var/run/reboot-required ]] && warn "Сервер требует перезагрузки" || ok "Перезагрузка не требуется"
}

security_menu() {
  local c f2b
  while true; do
    header

    if ! command_exists fail2ban-client; then
      ui_top "БЕЗОПАСНОСТЬ" "Fail2ban"
      ui_blank
      ui_line "Fail2ban не установлен"
      ui_blank
      ui_line "[01] Установить и включить Fail2ban"
      if ! security_updates_enabled; then
        ui_line "[02] Включить обновления безопасности"
      else
        ui_line "Обновления безопасности: включены"
      fi
      ui_line "[03] Базовая проверка безопасности"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "Выберите пункт: ; c=$REPLY
      case $c in
        1|01) install_fail2ban; pause ;;
        2|02) if security_updates_enabled; then echo "Нет такого пункта."; else enable_unattended_upgrades; pause; fi ;;
        3|03) security_basic_audit; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    if fail2ban_ssh_protected; then f2b="Активен · SSH защищён"
    elif systemctl is-active --quiet fail2ban 2>/dev/null; then f2b="Активен · нет SSH jail"
    else f2b="Остановлен"
    fi

    ui_top "БЕЗОПАСНОСТЬ" "Fail2ban"
    ui_blank
    ui_line "Fail2ban: $f2b"
    if security_updates_enabled; then ui_line "Обновления безопасности: включены"
    else ui_line "Обновления безопасности: выключены"
    fi
    ui_blank

    if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
      ui_line "[01] Запустить Fail2ban"
    else
      ui_line "[01] Статус Fail2ban"
    fi
    ui_line "[02] Статус защиты SSH"
    ui_line "[03] Разблокировать IP"
    ui_line "[04] Последние неудачные SSH-входы"
    ui_blank
    if ! security_updates_enabled; then
      ui_line "[05] Включить обновления безопасности"
    fi
    ui_line "[06] Базовая проверка безопасности"
    ui_line "[00] Назад"
    ui_bottom
    printf '\n'
    ask_num "Выберите пункт: ; c=$REPLY
    case $c in
      1|01)
        if systemctl is-active --quiet fail2ban 2>/dev/null; then fail2ban-client status 2>/dev/null || err "Fail2ban недоступен"
        else systemctl enable --now fail2ban && ok "Fail2ban запущен"
        fi
        pause ;;
      2|02) fail2ban-client status sshd 2>/dev/null || err "Jail sshd недоступен"; pause ;;
      3|03) read -r -p 'IP-адрес: ' ip; safe_name "$ip" && fail2ban-client set sshd unbanip "$ip" 2>/dev/null || err "Не удалось разблокировать IP"; pause ;;
      4|04) journalctl -u ssh -u sshd --since '-24 hours' --no-pager 2>/dev/null | grep -Ei 'failed|invalid user|authentication failure' | tail -100 || true; pause ;;
      5|05) if security_updates_enabled; then echo "Нет такого пункта."; else enable_unattended_upgrades; pause; fi ;;
      6|06) security_basic_audit; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
