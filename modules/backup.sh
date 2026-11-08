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
  while true; do
    header
    cat <<'MENU'
РЕЗЕРВНЫЕ КОПИИ

1. Создать полную копию настроек SERVER-KIT
2. Создать копию SSH
3. Создать копию UFW
4. Создать копию Fail2ban
5. Показать резервные копии
6. Восстановить последнюю копию SSH
7. Восстановить последнюю копию UFW
8. Восстановить последнюю копию Fail2ban
9. Удалить выбранную копию
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) create_system_backup; pause ;; 2) backup_file /etc/ssh ssh; pause ;; 3) backup_file /etc/ufw firewall; pause ;;
      4) backup_file /etc/fail2ban fail2ban; pause ;; 5) list_backups; pause ;;
      6) restore_category_latest ssh; pause ;; 7) restore_category_latest firewall; pause ;; 8) restore_category_latest fail2ban; pause ;;
      9) delete_backup; pause ;; 0) return ;;
    esac
  done
}
