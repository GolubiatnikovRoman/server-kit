#!/usr/bin/env bash

valid_server_hostname() {
  local LC_ALL=C
  [[ $1 =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ && $1 == *[a-z]* && $1 != localhost ]]
}

render_hostname_hosts() {
  local old_name=$1 new_name=$2 hosts_file=$3
  awk -v old_name="$old_name" -v old_short="${old_name%%.*}" -v new_name="$new_name" '
    tolower($1) != "127.0.1.1" { print; next }
    {
      body = $0
      comment = ""
      if (match(body, /[[:space:]]*#/)) {
        comment = substr(body, RSTART)
        body = substr(body, 1, RSTART - 1)
      }

      n = split(body, fields, /[[:space:]]+/)
      line = "127.0.1.1"
      changed = 0
      has_name = 0
      for (i = (fields[1] == "" ? 3 : 2); i <= n; i++) {
        alias = fields[i]
        if (alias == "") continue
        name = tolower(alias)
        if (name == old_name || name == old_short || name == new_name) {
          if (!has_name) line = line " " new_name
          if (has_name || alias != new_name) changed = 1
          has_name = found = 1
          continue
        }
        line = line " " alias
      }
      print (changed ? line comment : $0)
    }
    END { if (!found) print "127.0.1.1\t" new_name }
  ' "$hosts_file"
}

apply_server_hostname() (
  local old_name=$1 new_name=$2 hostname_file=$3 hosts_file=$4
  local backup staged hosts_lock rollback_failed=0
  exec {hosts_lock}>"$SERVERKIT_STATE_DIR/hostname.lock" || return 1
  flock -n "$hosts_lock" || { err "Имя сервера уже меняется в другой сессии"; return 1; }
  [[ $(hostname) == "$old_name" ]] || { err "Имя сервера изменилось. Повторите операцию."; return 1; }

  hosts_file=$(realpath -e -- "$hosts_file") || return 1
  mkdir -p "$SERVERKIT_BACKUP_DIR/hostname" || return 1
  backup=$(mktemp -d "$SERVERKIT_BACKUP_DIR/hostname/$(date '+%Y-%m-%d_%H-%M-%S')_XXXXXX") || return 1
  cp -a -- "$hosts_file" "$backup/hosts" || return 1
  if [[ -e $hostname_file || -L $hostname_file ]]; then
    cp -a -- "$hostname_file" "$backup/hostname" || return 1
  fi

  staged=$(mktemp -- "${hosts_file%/*}/.serverkit-hosts.XXXXXX") || return 1
  trap 'rm -f -- "$staged"' EXIT
  render_hostname_hosts "${old_name,,}" "$new_name" "$hosts_file" > "$staged" || return 1
  cp --attributes-only --preserve=mode,ownership -- "$hosts_file" "$staged" || return 1
  mv -fT -- "$staged" "$hosts_file" || return 1

  if hostnamectl --static --transient set-hostname "$new_name" &&
      [[ $(hostname) == "$new_name" && $(cat -- "$hostname_file") == "$new_name" ]]; then
    ok "Имя сервера изменено: $old_name → $new_name"
    info "Резервная копия: $backup"
    info "Откройте новую SSH-сессию, чтобы увидеть новое имя в приглашении."
    return 0
  fi

  cp -a -- "$backup/hosts" "$hosts_file" || rollback_failed=1
  if [[ -e $backup/hostname || -L $backup/hostname ]]; then
    cp -a --remove-destination -- "$backup/hostname" "$hostname_file" || rollback_failed=1
  else
    rm -f -- "$hostname_file" || rollback_failed=1
  fi
  if [[ $(hostname) != "$old_name" ]]; then
    hostname "$old_name" || rollback_failed=1
  fi
  if (( rollback_failed )); then
    err "Не удалось завершить откат. Резервная копия: $backup"
  else
    info "Исходные настройки восстановлены."
  fi
  return 1
)

change_server_hostname() {
  local old_name new_name
  command_exists hostnamectl || { err "Для смены имени сервера требуется hostnamectl"; return 1; }
  old_name=$(hostname) || return 1
  info "Текущее имя сервера: $old_name"
  read -r -p 'Новое короткое имя (Enter — отмена): ' new_name || return 0
  [[ -n $new_name ]] || return 0
  if ! valid_server_hostname "$new_name"; then
    err "Введите от 1 до 63 символов: строчные латинские буквы, цифры и дефис. Нужна хотя бы одна буква. Дефис в начале или конце и имя localhost запрещены."
    return 1
  fi
  [[ $new_name != "$old_name" ]] || { info "Это имя уже используется"; return 0; }
  confirm "Сменить имя сервера с $old_name на $new_name?" || return 0
  if ! apply_server_hostname "$old_name" "$new_name" /etc/hostname /etc/hosts; then
    err "Смена имени сервера завершилась ошибкой."
    return 1
  fi
}
