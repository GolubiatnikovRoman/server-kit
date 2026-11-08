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
  local c
  while true; do
    header

    if [[ -x $MOTD_FILE ]]; then
      ui_top "CONSOLE" "MOTD active"
      ui_blank
      ui_line "[01] Обновить MOTD SERVER-KIT"
      ui_line "[02] Предпросмотр MOTD"
      ui_line "[03] Отключить MOTD SERVER-KIT"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "console › "; c=$REPLY
      case $c in
        1|01) install_serverkit_motd; pause ;;
        2|02) preview_motd; pause ;;
        3|03) confirm "Удалить только MOTD SERVER-KIT?" && rm -f "$MOTD_FILE" && ok "MOTD SERVER-KIT удалён"; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
    else
      ui_top "CONSOLE" "MOTD disabled"
      ui_blank
      ui_line "[01] Установить MOTD SERVER-KIT"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "console › "; c=$REPLY
      case $c in
        1|01) install_serverkit_motd; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
    fi
  done
}
