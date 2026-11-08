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
  local c reboot
  while true; do
    header
    [[ -f /var/run/reboot-required ]] && reboot="да" || reboot="нет"
    box "Обновления системы"       "Доступно обновлений: $(count_updates)"       "Перезагрузка требуется: $reboot"       ""       "1. Обновить список пакетов"       "2. Показать доступные обновления"       "3. Установить обычные обновления"       "4. Полное обновление (full-upgrade)"       "5. Автоматические security-обновления"       "6. Проверить необходимость перезагрузки"       "7. Перезагрузить сервер"       "0. Назад"
    printf '\n'
    ask_num "Выбор [0-7]: "; c=$REPLY
    case $c in
      1) apt-get update; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause ;;
      2) apt list --upgradable 2>/dev/null; pause ;;
      3) confirm "Установить доступные обновления?" && apt-get update && apt-get upgrade -y; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause ;;
      4) warn "full-upgrade может устанавливать и удалять зависимости."; confirm "Выполнить apt full-upgrade?" && apt-get update && apt-get full-upgrade -y; rm -f "$SERVERKIT_STATE_DIR/update-count.cache"; pause ;;
      5) enable_unattended_upgrades; pause ;;
      6) [[ -f /var/run/reboot-required ]] && warn "Требуется перезагрузка" || ok "Перезагрузка не требуется"; pause ;;
      7) confirm "Перезагрузить сервер СЕЙЧАС? SSH-соединение будет разорвано." && systemctl reboot; return ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
