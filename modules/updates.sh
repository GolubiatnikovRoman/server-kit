#!/usr/bin/env bash

count_updates() {
  local cache="$SERVERKIT_STATE_DIR/update-count.cache" now ts value
  now=$(date +%s)
  if [[ -r $cache ]]; then
    read -r ts value < "$cache" || true
    if [[ $ts =~ ^[0-9]+$ && $value =~ ^[0-9]+$ ]] && (( now - ts < 60 )); then
      printf '%s' "$value"
      return 0
    fi
  fi
  value=$(apt list --upgradable 2>/dev/null | sed '1d' | grep -c . || true)
  [[ $value =~ ^[0-9]+$ ]] || value=0
  printf '%s %s\n' "$now" "$value" > "$cache"
  printf '%s' "$value"
}

refresh_update_count() {
  rm -f "$SERVERKIT_STATE_DIR/update-count.cache"
  count_updates
}

updates_menu() {
  local c reboot auto updates
  while true; do
    header
    updates=$(count_updates)
    [[ -f /var/run/reboot-required ]] && reboot="требуется" || reboot="не требуется"
    if security_updates_enabled 2>/dev/null; then auto="включены"; else auto="выключены"; fi

    ui_top "ОБНОВЛЕНИЯ" "APT"
    ui_blank
    ui_two "Доступно: $updates" "Перезагрузка: $reboot"
    ui_line "Обновления безопасности: $auto"
    ui_blank
    ui_section "ДЕЙСТВИЯ"
    ui_blank
    ui_line "[01] Обновить список пакетов"
    ui_line "[02] Показать доступные обновления"
    if [[ $updates =~ ^[0-9]+$ ]] && (( updates > 0 )); then
      ui_line "[03] Установить обычные обновления"
      ui_line "[04] Полное обновление (full-upgrade)"
    fi
    if ! security_updates_enabled 2>/dev/null; then
      ui_line "[05] Включить автоматические security-обновления"
    fi
    ui_line "[06] Проверить необходимость перезагрузки"
    if [[ -f /var/run/reboot-required ]]; then ui_line "[07] Перезагрузить сервер"; fi
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "Выберите пункт: ; c=$REPLY
    case $c in
      1|01) apt-get update; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause ;;
      2|02) apt list --upgradable 2>/dev/null; pause ;;
      3|03)
        if (( updates > 0 )); then confirm "Установить доступные обновления?" && apt-get update && apt-get upgrade -y; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause
        else echo "Нет такого пункта."
        fi ;;
      4|04)
        if (( updates > 0 )); then warn "full-upgrade может устанавливать и удалять зависимости."; confirm "Выполнить apt full-upgrade?" && apt-get update && apt-get full-upgrade -y; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause
        else echo "Нет такого пункта."
        fi ;;
      5|05) if security_updates_enabled 2>/dev/null; then echo "Нет такого пункта."; else enable_unattended_upgrades; pause; fi ;;
      6|06) [[ -f /var/run/reboot-required ]] && warn "Требуется перезагрузка" || ok "Перезагрузка не требуется"; pause ;;
      7|07) if [[ -f /var/run/reboot-required ]]; then confirm "Перезагрузить сервер СЕЙЧАС? SSH-соединение будет разорвано." && systemctl reboot; return; else echo "Нет такого пункта."; fi ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
