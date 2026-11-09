#!/usr/bin/env bash

create_system_backup() {
  local stamp dir
  stamp=$(date '+%Y-%m-%d_%H-%M-%S')
  dir="$SERVERKIT_BACKUP_DIR/system/$stamp"
  mkdir -p "$dir/etc"
  for p in /etc/ssh /etc/ufw /etc/fail2ban /etc/serverkit; do
    [[ -e $p ]] || continue
    mkdir -p "$dir$(dirname "$p")"
    cp -a "$p" "$dir$(dirname "$p")/"
  done
  ok "Системная резервная копия создана: $dir"
}

list_backups() {
  find "$SERVERKIT_BACKUP_DIR" -mindepth 2 -maxdepth 2 -type d -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null | sort -r || true
}

restore_category_latest() {
  local category=$1 dir
  dir=$(latest_backup_dir "$category")
  [[ -n $dir ]] || { err "Резервных копий категории $category нет"; return 1; }
  restore_backup_tree "$dir"
  case $category in
    ssh) sshd -t && ssh_service_reload ;;
    firewall) command_exists ufw && ufw reload || true ;;
    fail2ban) systemctl restart fail2ban 2>/dev/null || true ;;
  esac
}

delete_backup() {
  list_backups
  printf '\nУкажите ПОЛНЫЙ путь к каталогу копии внутри %s\n' "$SERVERKIT_BACKUP_DIR"
  read -r -p 'Путь: ' p
  [[ $p == "$SERVERKIT_BACKUP_DIR"/* && -d $p ]] || { err "Некорректный путь"; return 1; }
  confirm "Удалить $p?" && rm -rf --one-file-system "$p" && ok "Копия удалена"
}

backup_menu() {
  local c ssh_bak ufw_bak f2b_bak
  while true; do
    header
    ssh_bak=$(latest_backup_dir ssh || true)
    ufw_bak=$(latest_backup_dir firewall || true)
    f2b_bak=$(latest_backup_dir fail2ban || true)

    ui_top "РЕЗЕРВНЫЕ КОПИИ" "$SERVERKIT_BACKUP_DIR"
    ui_blank
    ui_line "[01] Создать полную копию настроек"
    ui_line "[02] Создать копию SSH"
    if [[ -d /etc/ufw ]]; then ui_line "[03] Создать копию UFW"; fi
    if [[ -d /etc/fail2ban ]]; then ui_line "[04] Создать копию Fail2ban"; fi
    ui_blank
    ui_line "[05] Показать резервные копии"
    ui_blank
    [[ -n $ssh_bak ]] && ui_line "[06] Восстановить последнюю копию SSH"
    [[ -n $ufw_bak ]] && ui_line "[07] Восстановить последнюю копию UFW"
    [[ -n $f2b_bak ]] && ui_line "[08] Восстановить последнюю копию Fail2ban"
    ui_line "[09] Удалить выбранную копию"
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "Выберите пункт: "; c=$REPLY
    case $c in
      1|01) create_system_backup; pause ;;
      2|02) backup_file /etc/ssh ssh; pause ;;
      3|03) if [[ -d /etc/ufw ]]; then backup_file /etc/ufw firewall; pause; else echo "Нет такого пункта."; fi ;;
      4|04) if [[ -d /etc/fail2ban ]]; then backup_file /etc/fail2ban fail2ban; pause; else echo "Нет такого пункта."; fi ;;
      5|05) list_backups; pause ;;
      6|06) if [[ -n $ssh_bak ]]; then restore_category_latest ssh; pause; else echo "Нет такого пункта."; fi ;;
      7|07) if [[ -n $ufw_bak ]]; then restore_category_latest firewall; pause; else echo "Нет такого пункта."; fi ;;
      8|08) if [[ -n $f2b_bak ]]; then restore_category_latest fail2ban; pause; else echo "Нет такого пункта."; fi ;;
      9|09) delete_backup; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
