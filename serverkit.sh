#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=${SERVERKIT_ROOT:-/opt/serverkit}
SERVERKIT_VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "0.0.0")

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/ui.sh"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/updater.sh"
source "$ROOT_DIR/modules/ssh.sh"
source "$ROOT_DIR/modules/firewall.sh"
source "$ROOT_DIR/modules/security.sh"
source "$ROOT_DIR/modules/updates.sh"
source "$ROOT_DIR/modules/monitoring.sh"
source "$ROOT_DIR/modules/services.sh"
source "$ROOT_DIR/modules/docker.sh"
source "$ROOT_DIR/modules/screen.sh"
source "$ROOT_DIR/modules/backup.sh"
source "$ROOT_DIR/modules/diagnostics.sh"
source "$ROOT_DIR/modules/console.sh"

require_root
supported_os || { err "Поддерживаются Ubuntu и Debian."; exit 1; }
ensure_dirs

server_info() {
  header
  local mem disk ipv4 docker_state ufw_state f2b_state
  mem=$(free -h | awk '/Mem:/{print $3 " / " $2}')
  disk=$(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}')
  command_exists docker && docker_state="установлен" || docker_state="не установлен"
  ufw_active && ufw_state="включён" || ufw_state="выключен/не установлен"
  systemctl is-active --quiet fail2ban 2>/dev/null && f2b_state="работает" || f2b_state="не работает"
  printf 'ИНФОРМАЦИЯ О СЕРВЕРЕ\n\n'
  printf 'ОС:              %s\n' "$(os_name)"
  printf 'Kernel:          %s\n' "$(uname -r)"
  printf 'Архитектура:     %s\n' "$(uname -m)"
  printf 'Hostname:        %s\n' "$(hostname)"
  printf 'Uptime:          %s\n' "$(uptime -p 2>/dev/null || true)"
  printf 'Load average:    %s\n' "$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
  printf 'RAM:             %s\n' "$mem"
  printf 'Диск /:          %s\n' "$disk"
  printf 'IPv4:            %s\n' "${ipv4:-не найден}"
  printf 'SSH-порт:        %s\n' "$(ssh_port)"
  printf 'UFW:             %s\n' "$ufw_state"
  printf 'Fail2ban:        %s\n' "$f2b_state"
  printf 'Docker:          %s\n' "$docker_state"
  printf 'Timezone:        %s\n' "$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  pause
}

settings_menu() {
  while true; do
    header
    printf 'НАСТРОЙКИ SERVER-KIT\n\nТекущая версия: v%s\n\n' "$SERVERKIT_VERSION"
    cat <<'MENU'
1. Проверить обновления
2. Обновить SERVER-KIT
3. Показать CHANGELOG
4. Показать версию
5. Удалить SERVER-KIT
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) if serverkit_check_update; then warn "Доступно обновление"; fi; pause ;;
      2) serverkit_update; pause ;;
      3) less "$ROOT_DIR/CHANGELOG.md" ;;
      4) echo "SERVER-KIT v$SERVERKIT_VERSION"; pause ;;
      5) serverkit_uninstall; exit 0 ;;
      0) return ;;
    esac
  done
}

main_menu() {
  while true; do
    header
    cat <<'MENU'
  1. SSH
  2. Межсетевой экран
  3. Безопасность
  4. Обновления системы
  5. Мониторинг
  6. Службы
  7. Docker
  8. Screen-сессии
  9. Резервные копии
 10. Диагностика
 11. Оформление консоли
 12. Информация о сервере
 13. Настройки SERVER-KIT

  0. Выход
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) ssh_menu ;; 2) firewall_menu ;; 3) security_menu ;; 4) updates_menu ;;
      5) monitoring_menu ;; 6) services_menu ;; 7) docker_menu ;; 8) screen_menu ;;
      9) backup_menu ;; 10) diagnostics_menu ;; 11) console_menu ;; 12) server_info ;;
      13) settings_menu ;; 0) exit 0 ;; *) warn "Неизвестный пункт меню"; sleep 1 ;;
    esac
  done
}

case ${1:-} in
  version|--version|-v) echo "SERVER-KIT v$SERVERKIT_VERSION" ;;
  check) quick_check ;;
  update) serverkit_update ;;
  check-update) serverkit_check_update || true ;;
  backup) create_system_backup ;;
  uninstall) serverkit_uninstall ;;
  "") main_menu ;;
  *) err "Неизвестная команда: $1"; printf 'Доступно: version, check, update, check-update, backup, uninstall\n'; exit 2 ;;
esac
