#!/usr/bin/env bash
set -Eeuo pipefail

REPO_OWNER="GolubiatnikovRoman"
REPO_NAME="server-kit"
REPO="$REPO_OWNER/$REPO_NAME"
BRANCH="main"
INSTALL_DIR="/opt/serverkit"
BIN="/usr/local/bin/serverkit"
REF=""
MODE="install"

while (($#)); do
  case $1 in
    --ref) REF=${2:-}; shift 2 ;;
    --update) MODE=update; shift ;;
    *) echo "[✗] Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "[✗] Запустите установщик от root: sudo -i" >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo "[✗] Не удалось определить ОС" >&2; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) echo "[✗] Поддерживаются Ubuntu и Debian" >&2; exit 1 ;; esac

if ! command -v curl >/dev/null 2>&1; then apt-get update && apt-get install -y curl ca-certificates; fi
command -v sha256sum >/dev/null 2>&1 || { apt-get update && apt-get install -y coreutils; }

if [[ -z $REF ]]; then
  latest=$(curl -fsSL --max-time 10 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
  REF=${latest:-$BRANCH}
fi

RAW="https://raw.githubusercontent.com/$REPO/$REF"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

files=(VERSION CHANGELOG.md serverkit.sh lib/ui.sh lib/common.sh lib/updater.sh \
  modules/ssh.sh modules/firewall.sh modules/security.sh modules/updates.sh \
  modules/monitoring.sh modules/services.sh modules/docker.sh modules/screen.sh \
  modules/backup.sh modules/diagnostics.sh modules/console.sh)

printf 'SERVER-KIT — %s\n' "$( [[ $MODE == update ]] && echo обновление || echo установка )"
printf 'Источник: %s @ %s\n\n' "$REPO" "$REF"

for file in "${files[@]}"; do
  mkdir -p "$TMP/$(dirname "$file")"
  printf '==> Загрузка %s\n' "$file"
  curl -fsSL --retry 3 "$RAW/$file" -o "$TMP/$file"
done

if curl -fsSL --retry 2 "$RAW/SHA256SUMS" -o "$TMP/SHA256SUMS" 2>/dev/null; then
  printf '==> Проверка SHA-256\n'
  for file in "${files[@]}"; do
    expected=$(awk -v f="$file" '$2==f{print $1}' "$TMP/SHA256SUMS")
    [[ -n $expected ]] || { echo "[✗] В SHA256SUMS нет $file" >&2; exit 1; }
    actual=$(sha256sum "$TMP/$file" | awk '{print $1}')
    [[ $actual == "$expected" ]] || { echo "[✗] Ошибка SHA-256: $file" >&2; exit 1; }
  done
  printf '[✓] Контрольные суммы совпадают\n'
else
  echo "[!] SHA256SUMS не найден. Для production-релиза это недопустимо." >&2
  [[ $REF == main ]] || exit 1
fi

if [[ -d $INSTALL_DIR && -f $INSTALL_DIR/VERSION ]]; then
  stamp=$(date '+%Y-%m-%d_%H-%M-%S')
  mkdir -p /var/lib/serverkit/install-backups
  cp -a "$INSTALL_DIR" "/var/lib/serverkit/install-backups/serverkit-$stamp"
  printf '[✓] Предыдущая версия сохранена: /var/lib/serverkit/install-backups/serverkit-%s\n' "$stamp"
fi

mkdir -p "$INSTALL_DIR" /etc/serverkit/backups /var/lib/serverkit
chmod 700 /etc/serverkit /etc/serverkit/backups
for file in "${files[@]}"; do
  install -D -m 0644 "$TMP/$file" "$INSTALL_DIR/$file"
done
chmod 755 "$INSTALL_DIR/serverkit.sh"
ln -sfn "$INSTALL_DIR/serverkit.sh" "$BIN"

printf '\n[✓] SERVER-KIT v%s установлен\n' "$(cat "$INSTALL_DIR/VERSION")"
printf '[✓] Команда запуска: serverkit\n'
printf '[✓] Быстрая проверка: serverkit check\n'
