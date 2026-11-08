#!/usr/bin/env bash

count_updates() {
  apt list --upgradable 2>/dev/null | sed '1d' | grep -c . || true
}

updates_menu() {
  while true; do
    header; printf 'ОБНОВЛЕНИЯ СИСТЕМЫ\n\n'
    printf 'Доступно обновлений: %s\n' "$(count_updates)"
    [[ -f /var/run/reboot-required ]] && warn "Требуется перезагрузка" || ok "Перезагрузка не требуется"
    cat <<'MENU'

1. Обновить список пакетов
2. Показать доступные обновления
3. Установить обычные обновления
4. Полное обновление (full-upgrade)
5. Автоматические security-обновления
6. Проверить необходимость перезагрузки
7. Перезагрузить сервер
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) apt-get update; pause ;;
      2) apt list --upgradable 2>/dev/null; pause ;;
      3) confirm "Установить доступные обновления?" && apt-get update && apt-get upgrade -y; pause ;;
      4) warn "full-upgrade может устанавливать и удалять зависимости."; confirm "Выполнить apt full-upgrade?" && apt-get update && apt-get full-upgrade -y; pause ;;
      5) enable_unattended_upgrades; pause ;;
      6) [[ -f /var/run/reboot-required ]] && warn "Требуется перезагрузка" || ok "Перезагрузка не требуется"; pause ;;
      7) confirm "Перезагрузить сервер СЕЙЧАС? SSH-соединение будет разорвано." && systemctl reboot; return ;;
      0) return ;;
    esac
  done
}
