#!/usr/bin/env bash

install_docker() {
  confirm "Установить Docker Engine, CLI, containerd, Buildx и Docker Compose Plugin?" || return 0
  warn "Docker может публиковать контейнерные порты в обход обычных правил UFW. После установки проверяйте опубликованные порты отдельно."
  confirm "Продолжить установку Docker из официального репозитория Docker?" || return 0

  # shellcheck disable=SC1091
  . /etc/os-release
  local distro=$ID codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
  [[ $distro == ubuntu || $distro == debian ]] || { err "Официальная установка поддерживается здесь только для Ubuntu/Debian"; return 1; }
  [[ -n $codename ]] || { err "Не удалось определить кодовое имя релиза"; return 1; }

  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker.sources <<SRC
Types: deb
URIs: https://download.docker.com/linux/$distro
Suites: $codename
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
SRC
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  docker version --format 'Docker Engine {{.Server.Version}}' 2>/dev/null || docker --version
  docker compose version
  ok "Docker установлен и запущен"
}

docker_choose_container() {
  local n
  docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
  printf '\n'; read -r -p 'Имя контейнера: ' n
  safe_name "$n" || { err "Некорректное имя"; return 1; }
  docker inspect "$n" >/dev/null 2>&1 || { err "Контейнер не найден"; return 1; }
  printf '%s' "$n"
}

docker_cleanup() {
  docker system df
  printf '\nБезопасная очистка удалит только неиспользуемые контейнеры, сети, dangling-образы и build cache.\n'
  warn "Тома автоматически удаляться НЕ будут."
  confirm "Выполнить docker system prune?" && docker system prune
}

docker_menu() {
  local c
  while true; do
    header

    if ! command_exists docker; then
      box "Docker · не установлен"         "SERVER-KIT может установить Docker Engine,"         "Docker CLI, containerd, Buildx и Compose."         ""         "1. Установить Docker"         "0. Назад"
      printf '\n'
      ask_num "Выбор [0-1]: "; c=$REPLY
      case $c in
        1) install_docker; pause ;;
        0|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    local state version
    systemctl is-active --quiet docker && state="работает" || state="остановлен"
    version=$(docker --version 2>/dev/null | sed 's/,.*//' || echo "Docker")

    box "Docker · $state"       "$version"       ""       "1. Все контейнеры"       "2. Запущенные контейнеры"       "3. Запустить контейнер"       "4. Остановить контейнер"       "5. Перезапустить контейнер"       "6. Логи контейнера"       "7. Статистика контейнеров"       ""       "8. Образы"       "9. Docker Compose: версия"       "10. Использование диска"       "11. Безопасная очистка"       "12. Перезапустить службу Docker"       "0. Назад"

    printf '\n'
    ask_num "Выбор [0-12]: "; c=$REPLY
    case $c in
      1) docker ps -a; pause ;; 2) docker ps; pause ;;
      3) n=$(docker_choose_container) && docker start "$n"; pause ;;
      4) n=$(docker_choose_container) && confirm "Остановить $n?" && docker stop "$n"; pause ;;
      5) n=$(docker_choose_container) && confirm "Перезапустить $n?" && docker restart "$n"; pause ;;
      6) n=$(docker_choose_container) && docker logs --tail 200 "$n"; pause ;;
      7) docker stats --no-stream; pause ;; 8) docker images; pause ;; 9) docker compose version; pause ;;
      10) docker system df -v; pause ;; 11) docker_cleanup; pause ;;
      12) confirm "Перезапустить службу Docker? Работа контейнеров может кратковременно прерваться." && systemctl restart docker; pause ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
