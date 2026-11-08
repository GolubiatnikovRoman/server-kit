#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=${SERVERKIT_ROOT:-/opt/serverkit}
SERVERKIT_VERSION=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "0.0.0")

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

main_dashboard() {
  local ssh_state ssh_kind ufw_state ufw_kind f2b_state f2b_kind docker_state docker_kind
  local updates update_kind reboot reboot_kind

  if systemctl is-active --quiet "$(ssh_service_name)" 2>/dev/null; then
    ssh_state="ONLINE"; ssh_kind=ok
  else
    ssh_state="OFFLINE"; ssh_kind=bad
  fi

  if ufw_active; then
    ufw_state="ACTIVE"; ufw_kind=ok
  elif ufw_installed; then
    ufw_state="OFF"; ufw_kind=warn
  else
    ufw_state="NOT INSTALLED"; ufw_kind=dim
  fi

  if command_exists fail2ban-client; then
    if systemctl is-active --quiet fail2ban 2>/dev/null; then f2b_state="ACTIVE"; f2b_kind=ok
    else f2b_state="STOPPED"; f2b_kind=warn; fi
  else
    f2b_state="NOT INSTALLED"; f2b_kind=dim
  fi

  if command_exists docker; then
    if systemctl is-active --quiet docker 2>/dev/null; then docker_state="RUNNING"; docker_kind=ok
    else docker_state="STOPPED"; docker_kind=warn; fi
  else
    docker_state="NOT INSTALLED"; docker_kind=dim
  fi

  updates=$(count_updates 2>/dev/null || echo "?")
  if [[ $updates =~ ^[0-9]+$ ]] && (( updates > 0 )); then update_kind=warn; else update_kind=ok; fi
  [[ -f /var/run/reboot-required ]] && { reboot="REQUIRED"; reboot_kind=warn; } || { reboot="NO"; reboot_kind=ok; }

  ui_top "SERVER-KIT" "v$SERVERKIT_VERSION"
  ui_blank
  ui_section "SYSTEM STATUS"
  ui_blank
  ui_two "$(ui_status SSH "$ssh_state" "$ssh_kind")" "$(ui_status UFW "$ufw_state" "$ufw_kind")"
  ui_two "$(ui_status Fail2ban "$f2b_state" "$f2b_kind")" "$(ui_status Docker "$docker_state" "$docker_kind")"
  ui_two "$(ui_status Updates "$updates available" "$update_kind")" "$(ui_status Reboot "$reboot" "$reboot_kind")"
  ui_blank
  ui_section "MANAGEMENT"
  ui_blank
  ui_two "[01] SSH" "[07] Docker"
  ui_two "[02] Межсетевой экран" "[08] Screen-сессии"
  ui_two "[03] Безопасность" "[09] Резервные копии"
  ui_two "[04] Обновления" "[10] Диагностика"
  ui_two "[05] Мониторинг" "[11] Оформление консоли"
  ui_two "[06] Службы" "[12] Информация о сервере"
  ui_blank
  ui_two "" "[13] Настройки SERVER-KIT"
  ui_blank
  ui_sep
  ui_line "[00] Выход"
  ui_bottom
}

server_info() {
  header
  local mem disk ipv4 docker_state ufw_state f2b_state
  mem=$(free -h | awk '/Mem:/{print $3 " / " $2}')
  disk=$(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}')
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}')
  command_exists docker && docker_state="установлен" || docker_state="не установлен"
  ufw_active && ufw_state="включён" || ufw_state="выключен/не установлен"
  systemctl is-active --quiet fail2ban 2>/dev/null && f2b_state="работает" || f2b_state="не работает"

  ui_top "SERVER-KIT" "Информация"
  ui_blank
  ui_line "ОС: $(os_name)"
  ui_line "Kernel: $(uname -r)"
  ui_line "Архитектура: $(uname -m)"
  ui_line "Hostname: $(hostname)"
  ui_line "Uptime: $(uptime -p 2>/dev/null || true)"
  ui_line "RAM: $mem"
  ui_line "Диск /: $disk"
  ui_line "IPv4: ${ipv4:-не найден}"
  ui_line "SSH-порт: $(ssh_port)"
  ui_line "UFW: $ufw_state"
  ui_line "Fail2ban: $f2b_state"
  ui_line "Docker: $docker_state"
  ui_line "Timezone: $(timedatectl show -p Timezone --value 2>/dev/null || true)"
  ui_bottom
  pause
}

settings_menu() {
  local c
  while true; do
    header
    ui_top "SERVER-KIT" "Настройки"
    ui_blank
    ui_line "[01] Проверить обновления"
    ui_line "[02] Обновить SERVER-KIT"
    ui_line "[03] Показать CHANGELOG"
    ui_line "[04] Показать версию"
    ui_blank
    ui_line "[05] Удалить SERVER-KIT"
    ui_blank
    ui_line "[00] Назад"
    ui_bottom
    printf '\n'
    ask_num "serverkit › "; c=$REPLY
    case $c in
      1|01) if serverkit_check_update; then warn "Доступно обновление"; fi; pause ;;
      2|02) serverkit_update; pause ;;
      3|03) less "$ROOT_DIR/CHANGELOG.md" ;;
      4|04) echo "SERVER-KIT v$SERVERKIT_VERSION"; pause ;;
      5|05) serverkit_uninstall; exit 0 ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}

main_menu() {
  local c
  while true; do
    header
    main_dashboard
    printf '\n'
    ask_num "serverkit › "; c=$REPLY
    case $c in
      1|01) ssh_menu ;;
      2|02) firewall_menu ;;
      3|03) security_menu ;;
      4|04) updates_menu ;;
      5|05) monitoring_menu ;;
      6|06) services_menu ;;
      7|07) docker_menu ;;
      8|08) screen_menu ;;
      9|09) backup_menu ;;
      10) diagnostics_menu ;;
      11) console_menu ;;
      12) server_info ;;
      13) settings_menu ;;
      0|00|"") exit 0 ;;
      *) echo "Нет такого пункта." ;;
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
