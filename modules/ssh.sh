#!/usr/bin/env bash

SSH_CONFIG=/etc/ssh/sshd_config
SSH_DROPIN_DIR=/etc/ssh/sshd_config.d
SSH_DROPIN=$SSH_DROPIN_DIR/99-serverkit.conf
SSH_PENDING=$SERVERKIT_STATE_DIR/ssh-port.pending

ssh_port() {
  local p
  p=$(sshd -T 2>/dev/null | awk '$1=="port"{print $2; exit}')
  printf '%s' "${p:-22}"
}

ssh_ports_effective() {
  sshd -T 2>/dev/null | awk '$1=="port"{print $2}' | sort -nu
}

ssh_password_state() {
  local v
  v=$(sshd -T 2>/dev/null | awk '$1=="passwordauthentication"{print $2; exit}')
  [[ $v == no ]] && echo "отключён" || echo "включён"
}

ssh_root_state() {
  local v
  v=$(sshd -T 2>/dev/null | awk '$1=="permitrootlogin"{print $2; exit}')
  printf '%s' "${v:-неизвестно}"
}

ssh_service_reload() {
  local svc
  svc=$(ssh_service_name)
  systemctl reload "$svc" 2>/dev/null || systemctl restart "$svc"
}

ssh_validate() {
  if sshd -t; then ok "Конфигурация SSH корректна"; else err "Конфигурация SSH содержит ошибку"; return 1; fi
}

ssh_include_ready() {
  mkdir -p "$SSH_DROPIN_DIR"
  if grep -Eiq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$SSH_CONFIG"; then return 0; fi
  backup_file "$SSH_CONFIG" ssh >/dev/null || true
  sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' "$SSH_CONFIG"
}

ssh_show_status() {
  printf 'Порт:                %s\n' "$(ssh_port)"
  printf 'Вход по паролю:      %s\n' "$(ssh_password_state)"
  printf 'PermitRootLogin:     %s\n' "$(ssh_root_state)"
  printf 'Пользователь входа:  %s\n' "$(active_login_user)"
  if has_authorized_key_for_login_user; then printf 'SSH-ключ:            найден\n'; else printf 'SSH-ключ:            не найден\n'; fi
  if [[ -f $SSH_PENDING ]]; then
    # shellcheck disable=SC1090
    . "$SSH_PENDING"
    printf 'Смена порта:         ожидает подтверждения (%s → %s)\n' "${OLD_PORT:-?}" "${NEW_PORT:-?}"
  fi
}

ssh_write_port_dropin() {
  local old=$1 new=$2 mode=${3:-dual}
  ssh_include_ready
  mkdir -p "$SSH_DROPIN_DIR"
  if [[ $mode == dual ]]; then
    cat > "$SSH_DROPIN" <<CFG
# Управляется SERVER-KIT. Не редактируйте во время незавершённой смены порта.
Port $old
Port $new
CFG
  else
    cat > "$SSH_DROPIN" <<CFG
# Управляется SERVER-KIT.
Port $new
CFG
  fi
  chmod 600 "$SSH_DROPIN"
}

ssh_comment_existing_ports() {
  # Убираем активные Port из основного файла и drop-in файлов, чтобы портами управлял один 99-serverkit.conf.
  local f
  for f in "$SSH_CONFIG" "$SSH_DROPIN_DIR"/*.conf; do
    [[ -f $f && $f != "$SSH_DROPIN" ]] || continue
    sed -ri 's/^([[:space:]]*)Port([[:space:]]+[0-9]+)/\1# SERVER-KIT: прежний Port\2/' "$f"
  done
}

ssh_set_dropin_option() {
  local key=$1 value=$2 tmp
  ssh_include_ready
  touch "$SSH_DROPIN"; chmod 600 "$SSH_DROPIN"
  tmp=$(mktemp)
  awk -v k="$key" 'BEGIN{IGNORECASE=1} $1!=k {print}' "$SSH_DROPIN" > "$tmp"
  printf '%s %s\n' "$key" "$value" >> "$tmp"
  install -m 600 "$tmp" "$SSH_DROPIN"
  rm -f "$tmp"
}

ssh_restore_latest() {
  local dir
  dir=$(latest_backup_dir ssh)
  [[ -n $dir ]] || { err "Резервных копий SSH нет"; return 1; }
  restore_backup_tree "$dir" || return 1
  sshd -t || { err "Восстановленная конфигурация некорректна"; return 1; }
  ssh_service_reload
  rm -f "$SSH_PENDING"
  ok "SSH восстановлен из резервной копии"
}

ssh_change_port_begin() {
  local new old backup
  [[ -f $SSH_PENDING ]] && { warn "Уже есть незавершённая смена SSH-порта. Завершите или отмените её."; return 1; }
  old=$(ssh_port)
  read -r -p "Новый SSH-порт (1024-65535): " new
  validate_high_port "$new" || { err "Некорректный порт"; return 1; }
  [[ $new != "$old" ]] || { warn "SSH уже использует этот порт"; return 1; }
  if port_in_use "$new"; then err "Порт $new уже занят"; return 1; fi

  backup=$(backup_path /etc/ssh ssh) || { err "Не удалось создать резервную копию SSH"; return 1; }
  info "Резервная копия: $backup"

  if command_exists ufw && ufw status | grep -q '^Status: active'; then
    ufw allow "$new/tcp" >/dev/null
    ok "Порт $new/tcp разрешён в UFW"
  else
    warn "UFW не активен. Если используется внешний firewall провайдера, откройте TCP-порт $new вручную."
  fi

  ssh_comment_existing_ports
  ssh_write_port_dropin "$old" "$new" dual
  if ! sshd -t; then
    err "Новая конфигурация SSH не прошла проверку. Выполняется откат."
    cp -a "$backup"/. /
    command_exists ufw && ufw status | grep -q '^Status: active' && ufw delete allow "$new/tcp" >/dev/null 2>&1 || true
    return 1
  fi
  if ! ssh_service_reload; then
    err "Не удалось применить конфигурацию. Выполняется откат."
    cp -a "$backup"/. /
    ssh_service_reload || true
    return 1
  fi
  sleep 1
  ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$new$" || {
    err "SSH не начал слушать порт $new. Выполняется откат."
    cp -a "$backup"/. /
    ssh_service_reload || true
    return 1
  }

  cat > "$SSH_PENDING" <<STATE
OLD_PORT=$old
NEW_PORT=$new
BACKUP_DIR='$backup'
STATE
  chmod 600 "$SSH_PENDING"

  ok "SSH временно слушает старый порт $old и новый порт $new"
  printf '\nОткройте ВТОРОЕ окно терминала и проверьте подключение:\n\n'
  printf '  ssh %s@SERVER_IP -p %s\n\n' "$(active_login_user)" "$new"
  warn "Не закрывайте текущую SSH-сессию до успешной проверки."
  printf '\nПосле проверки снова откройте SERVER-KIT → SSH → Завершить смену порта.\n'
}

ssh_change_port_finish() {
  [[ -f $SSH_PENDING ]] || { warn "Незавершённой смены порта нет"; return 1; }
  # shellcheck disable=SC1090
  . "$SSH_PENDING"
  printf 'Старый порт: %s\nНовый порт:  %s\n\n' "$OLD_PORT" "$NEW_PORT"
  choose_yes_no "Вы УСПЕШНО подключились к серверу во втором окне через порт $NEW_PORT?" || {
    warn "Старый порт оставлен. Изменения не завершены."; return 0;
  }
  ssh_write_port_dropin "$OLD_PORT" "$NEW_PORT" single
  if ! sshd -t || ! ssh_service_reload; then
    err "Не удалось зафиксировать новый порт. Восстанавливается резервная копия."
    cp -a "$BACKUP_DIR"/. /
    ssh_service_reload || true
    return 1
  fi
  if command_exists ufw && ufw status | grep -q '^Status: active'; then
    ufw delete allow "$OLD_PORT/tcp" >/dev/null 2>&1 || true
    ok "Старый порт $OLD_PORT удалён из UFW"
  fi
  rm -f "$SSH_PENDING"
  ok "Смена SSH-порта завершена. Текущий порт: $NEW_PORT"
}

ssh_change_port_cancel() {
  [[ -f $SSH_PENDING ]] || { warn "Незавершённой смены порта нет"; return 1; }
  # shellcheck disable=SC1090
  . "$SSH_PENDING"
  confirm "Отменить смену порта и вернуть предыдущую конфигурацию SSH?" || return 0
  cp -a "$BACKUP_DIR"/. /
  sshd -t || { err "Резервная конфигурация не прошла проверку"; return 1; }
  ssh_service_reload
  if command_exists ufw && ufw status | grep -q '^Status: active'; then ufw delete allow "$NEW_PORT/tcp" >/dev/null 2>&1 || true; fi
  rm -f "$SSH_PENDING"
  ok "Предыдущая конфигурация SSH восстановлена"
}

ssh_disable_password() {
  local backup user
  user=$(active_login_user)
  has_authorized_key_for_login_user || {
    err "У пользователя $user не найден непустой authorized_keys. Отключение пароля отменено."
    return 1
  }
  backup=$(backup_path /etc/ssh ssh) || return 1
  ssh_include_ready
  ssh_set_dropin_option PasswordAuthentication no
  ssh_set_dropin_option KbdInteractiveAuthentication no
  if ! sshd -t; then cp -a "$backup"/. /; err "Ошибка конфигурации. Изменения отменены."; return 1; fi
  ssh_service_reload || { cp -a "$backup"/. /; ssh_service_reload || true; err "Не удалось применить настройки"; return 1; }
  ok "Вход по паролю отключён"
  warn "Текущую сессию не закрывайте, пока не проверите новый вход по SSH-ключу во втором окне."
}

ssh_set_root_login() {
  local mode backup
  printf '1. prohibit-password — root только по ключу\n2. no — полностью запретить root-вход\n0. Назад\n\n'
  read -r -p 'Выберите режим: ' mode
  case $mode in 1) mode=prohibit-password ;; 2) mode=no ;; 0) return ;; *) return ;; esac
  backup=$(backup_path /etc/ssh ssh) || return 1
  ssh_include_ready
  ssh_set_dropin_option PermitRootLogin "$mode"
  if sshd -t && ssh_service_reload; then ok "PermitRootLogin: $mode"; else cp -a "$backup"/. /; ssh_service_reload || true; err "Изменение отменено"; fi
}

ssh_menu() {
  while true; do
    header; printf 'SSH\n\n'; ssh_show_status
    cat <<'MENU'

1. Начать безопасную смену SSH-порта
2. Завершить смену SSH-порта
3. Отменить незавершённую смену порта
4. Отключить вход по паролю
5. Настроить вход root
6. Проверить конфигурацию
7. Показать эффективную конфигурацию
8. Восстановить последнюю резервную копию
0. Назад
MENU
    printf '\n'; read -r -p 'Выберите действие: ' c
    case $c in
      1) ssh_change_port_begin; pause ;; 2) ssh_change_port_finish; pause ;; 3) ssh_change_port_cancel; pause ;;
      4) confirm "Отключить вход по SSH-паролю?" && ssh_disable_password; pause ;;
      5) ssh_set_root_login; pause ;; 6) ssh_validate; pause ;; 7) sshd -T 2>/dev/null | less ;;
      8) ssh_restore_latest; pause ;; 0) return ;;
    esac
  done
}
