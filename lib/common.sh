#!/usr/bin/env bash

SERVERKIT_ETC=${SERVERKIT_ETC:-/etc/serverkit}
SERVERKIT_BACKUP_DIR=${SERVERKIT_BACKUP_DIR:-$SERVERKIT_ETC/backups}
SERVERKIT_STATE_DIR=${SERVERKIT_STATE_DIR:-/var/lib/serverkit}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Запустите SERVER-KIT от root: sudo -i"; exit 1; }
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

supported_os() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in ubuntu|debian) return 0 ;; *) return 1 ;; esac
}

os_name() {
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || true
  printf '%s' "${PRETTY_NAME:-Неизвестно}"
}

os_id() {
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || true
  printf '%s' "${ID:-unknown}"
}

ensure_dirs() {
  mkdir -p "$SERVERKIT_ETC" "$SERVERKIT_BACKUP_DIR" "$SERVERKIT_STATE_DIR"
  chmod 700 "$SERVERKIT_ETC" "$SERVERKIT_BACKUP_DIR" 2>/dev/null || true
}

validate_port() {
  [[ ${1:-} =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

validate_high_port() {
  validate_port "${1:-}" && (( 10#$1 >= 1024 ))
}

port_in_use() {
  local port=$1
  ss -H -lntup 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)$port$"
}

service_exists() {
  systemctl list-unit-files "$1.service" --no-legend 2>/dev/null | grep -q "^$1\.service"
}

ssh_service_name() {
  if service_exists ssh; then echo ssh; elif service_exists sshd; then echo sshd; else echo ssh; fi
}

backup_path() {
  local src=$1 category=$2 stamp base target
  [[ -e $src ]] || return 1
  stamp=$(date '+%Y-%m-%d_%H-%M-%S')
  base="$SERVERKIT_BACKUP_DIR/$category/$stamp"
  mkdir -p "$base"
  target="$base$(dirname "$src")"
  mkdir -p "$target"
  cp -a "$src" "$target/"
  printf '%s' "$base"
}

backup_file() {
  local out
  out=$(backup_path "$1" "$2") || { warn "Файл $1 не найден — резервная копия не создана"; return 1; }
  ok "Создана резервная копия: $out"
}

restore_backup_tree() {
  local dir=$1
  [[ -d $dir ]] || { err "Резервная копия не найдена: $dir"; return 1; }
  confirm "Восстановить файлы из $dir?" || return 0
  cp -a "$dir"/. /
  ok "Файлы восстановлены"
}

latest_backup_dir() {
  local category=$1
  find "$SERVERKIT_BACKUP_DIR/$category" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -1
}

active_login_user() {
  if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then printf '%s' "$SUDO_USER"; return; fi
  if [[ -n ${SSH_CONNECTION:-} ]]; then
    local u
    u=$(who am i 2>/dev/null | awk '{print $1}' | head -1)
    [[ -n $u ]] && { printf '%s' "$u"; return; }
  fi
  printf 'root'
}

user_authorized_keys() {
  local user=$1 home
  home=$(getent passwd "$user" | cut -d: -f6)
  [[ -n $home ]] || return 1
  printf '%s/.ssh/authorized_keys' "$home"
}

has_authorized_key_for_login_user() {
  local user keys
  user=$(active_login_user)
  keys=$(user_authorized_keys "$user") || return 1
  [[ -s $keys ]] && grep -Eq '^[[:space:]]*(ssh-(rsa|ed25519)|ecdsa-|sk-ssh-|sk-ecdsa-)' "$keys"
}

human_bytes() {
  numfmt --to=iec-i --suffix=B "${1:-0}" 2>/dev/null || printf '%s B' "${1:-0}"
}

safe_name() { [[ ${1:-} =~ ^[A-Za-z0-9._@:-]{1,128}$ ]]; }
