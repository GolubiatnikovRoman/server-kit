#!/usr/bin/env bash

MOTD_FILE=/etc/update-motd.d/99-serverkit

install_serverkit_motd() {
  [[ -e $MOTD_FILE ]] && backup_file "$MOTD_FILE" console >/dev/null || true
  cat > "$MOTD_FILE" <<'MOTD'
#!/usr/bin/env bash
set +e
printf '\n╭─────────────────────────────────────────────╮\n'
printf '│                 SERVER-KIT                  │\n'
printf '╰─────────────────────────────────────────────╯\n'
printf 'Система:      %s\n' "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Неизвестно}")"
printf 'Hostname:     %s\n' "$(hostname)"
printf 'Uptime:       %s\n' "$(uptime -p 2>/dev/null | sed 's/^up //')"
printf 'Нагрузка:     %s\n' "$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)"
printf 'RAM:          %s\n' "$(free -h 2>/dev/null | awk '/Mem:/{print $3 " / " $2}')"
printf 'Диск /:       %s\n' "$(df -h / 2>/dev/null | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')"
printf 'IPv4:         %s\n' "$(hostname -I 2>/dev/null | awk '{print $1}')"
printf 'Управление:   serverkit\n\n'
MOTD
  chmod 755 "$MOTD_FILE"
  ok "MOTD SERVER-KIT установлен"
}

preview_motd() {
  [[ -x $MOTD_FILE ]] && "$MOTD_FILE" || warn "MOTD SERVER-KIT не установлен"
}

console_menu() {
  while true; do
    header
    cat <<'MENU'
ОФОРМЛЕНИЕ КОНСОЛИ

1. Установить/обновить MOTD SERVER-KIT
2. Предпросмотр MOTD
3. Отключить MOTD SERVER-KIT
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) install_serverkit_motd; pause ;; 2) preview_motd; pause ;;
      3) confirm "Удалить только MOTD SERVER-KIT?" && rm -f "$MOTD_FILE" && ok "MOTD SERVER-KIT удалён"; pause ;;
      0) return ;;
    esac
  done
}
