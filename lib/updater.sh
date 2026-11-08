#!/usr/bin/env bash

SERVERKIT_REPO=${SERVERKIT_REPO:-GolubiatnikovRoman/server-kit}
SERVERKIT_API="https://api.github.com/repos/$SERVERKIT_REPO"
SERVERKIT_RAW="https://raw.githubusercontent.com/$SERVERKIT_REPO"

version_gt() {
  [[ $1 == "$2" ]] && return 1
  [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]
}

latest_release_version() {
  local tag
  tag=$(curl -fsSL --max-time 10 "$SERVERKIT_API/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\?\([^"]*\)".*/\1/p' | head -1)
  printf '%s' "$tag"
}

serverkit_check_update() {
  local latest
  latest=$(latest_release_version)
  [[ -n $latest ]] || { err "Не удалось получить последнюю версию GitHub Release"; return 1; }
  printf 'Текущая версия:  v%s\nПоследняя версия: v%s\n' "$SERVERKIT_VERSION" "$latest"
  if version_gt "$latest" "$SERVERKIT_VERSION"; then return 0; fi
  ok "Установлена актуальная версия"
  return 2
}

serverkit_update() {
  local rc
  if serverkit_check_update; then rc=0; else rc=$?; fi
  (( rc == 0 )) || return 0
  local latest
  latest=$(latest_release_version)
  confirm "Обновить SERVER-KIT до v$latest?" || return 0
  info "Запускается установщик, зафиксированный на теге v$latest"
  bash <(curl -fsSL "$SERVERKIT_RAW/v$latest/install.sh") --ref "v$latest" --update
}

serverkit_uninstall() {
  warn "Будет удалён только SERVER-KIT. Docker, UFW, Fail2ban и применённые системные настройки останутся."
  confirm "Удалить SERVER-KIT?" || return 0
  rm -f /usr/local/bin/serverkit
  rm -rf /opt/serverkit
  if confirm "Удалить MOTD SERVER-KIT?"; then rm -f /etc/update-motd.d/99-serverkit; fi
  ok "SERVER-KIT удалён. Резервные копии в /etc/serverkit сохранены."
}
