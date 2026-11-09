#!/usr/bin/env bash

MOTD_FILE=/etc/update-motd.d/99-serverkit

UBUNTU_MOTD_STATE=/var/lib/serverkit/ubuntu-motd-modes

ubuntu_motd_scripts() {
  local f name
  for f in /etc/update-motd.d/*; do
    [[ -f $f ]] || continue
    name=$(basename "$f")
    case "$name" in
      00-header|10-help-text|50-motd-news|80-esm|80-esm-updates|80-livepatch|90-updates-available|91-contract-ua-esm-status|91-release-upgrade|92-unattended-upgrades|95-hwe-eol|98-fsck-at-reboot|98-reboot-required) printf '%s\n' "$f" ;;
    esac
  done
}

disable_ubuntu_motd() {
  [[ ! -f $UBUNTU_MOTD_STATE ]] || { warn "Настройки Ubuntu MOTD уже сохранены"; return 0; }
  confirm "Скрыть стандартную сводку Ubuntu при SSH-входе?" || return 0
  local f mode
  mkdir -p /var/lib/serverkit
  : > "$UBUNTU_MOTD_STATE"
  chmod 600 "$UBUNTU_MOTD_STATE"
  while IFS= read -r f; do
    [[ -x $f ]] || continue
    mode=$(stat -c %a "$f") || continue
    printf '%s %s\n' "$mode" "$f" >> "$UBUNTU_MOTD_STATE"
    chmod a-x "$f"
  done < <(ubuntu_motd_scripts)
  ok "Стандартные скрипты Ubuntu MOTD скрыты; SERVER-KIT сохранён"
}

restore_ubuntu_motd() {
  [[ -f $UBUNTU_MOTD_STATE ]] || { warn "Сохранённые права MOTD не найдены"; return 0; }
  confirm "Восстановить стандартную сводку Ubuntu?" || return 0
  local mode f
  while read -r mode f; do
    [[ $mode =~ ^[0-7]{3,4}$ && -f $f && $f == /etc/update-motd.d/* ]] || continue
    chmod "$mode" "$f"
  done < "$UBUNTU_MOTD_STATE"
  rm -f "$UBUNTU_MOTD_STATE"
  ok "Права стандартных скриптов Ubuntu MOTD восстановлены"
}

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
      ui_top "ОФОРМЛЕНИЕ КОНСОЛИ" "MOTD включён"
      ui_blank
      ui_line "[01] Обновить MOTD SERVER-KIT"
      ui_line "[02] Предпросмотр MOTD"
      ui_line "[03] Отключить MOTD SERVER-KIT"
      ui_line "[04] Скрыть сводку Ubuntu"
      ui_line "[05] Восстановить сводку Ubuntu"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "Выберите пункт: ; c=$REPLY
      case $c in
        1|01) install_serverkit_motd; pause ;;
        2|02) preview_motd; pause ;;
        3|03) confirm "Удалить только MOTD SERVER-KIT?" && rm -f "$MOTD_FILE" && ok "MOTD SERVER-KIT удалён"; pause ;;
        4|04) disable_ubuntu_motd; pause ;;
        5|05) restore_ubuntu_motd; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
    else
      ui_top "ОФОРМЛЕНИЕ КОНСОЛИ" "MOTD выключен"
      ui_blank
      ui_line "[01] Установить MOTD SERVER-KIT"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "Выберите пункт: ; c=$REPLY
      case $c in
        1|01) install_serverkit_motd; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
    fi
  done
}
