#!/usr/bin/env bash

docker_runtime_state() {
  if ! command_exists docker; then echo "NOT INSTALLED"; return; fi
  if ! systemctl is-active --quiet docker 2>/dev/null; then echo "STOPPED"; return; fi
  if docker info >/dev/null 2>&1; then echo "RUNNING"; else echo "ERROR"; fi
}

docker_counts() {
  local running total images
  running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
  total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
  images=$(docker images -q 2>/dev/null | sort -u | wc -l | tr -d ' ')
  printf '%s %s %s' "${running:-0}" "${total:-0}" "${images:-0}"
}

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
  local c state version running total images
  while true; do
    header
    state=$(docker_runtime_state)

    if [[ $state == "NOT INSTALLED" ]]; then
      ui_top "DOCKER" "не установлен"
      ui_blank
      ui_line "Docker Engine, CLI, containerd, Buildx и Compose"
      ui_blank
      ui_line "[01] Установить Docker"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "docker › "; c=$REPLY
      case $c in
        1|01) install_docker; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    version=$(docker --version 2>/dev/null | sed 's/,.*//' || echo "Docker")

    if [[ $state == "STOPPED" ]]; then
      ui_top "DOCKER" "STOPPED"
      ui_blank
      ui_line "$version"
      ui_blank
      ui_line "[01] Запустить Docker"
      ui_line "[02] Показать журнал службы"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "docker › "; c=$REPLY
      case $c in
        1|01) systemctl enable --now docker && ok "Docker запущен"; pause ;;
        2|02) journalctl -u docker -n 120 --no-pager; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    if [[ $state == "ERROR" ]]; then
      ui_top "DOCKER" "ERROR"
      ui_blank
      ui_line "$version"
      ui_line "Служба активна, но Docker daemon не отвечает"
      ui_blank
      ui_line "[01] Перезапустить Docker"
      ui_line "[02] Показать журнал службы"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "docker › "; c=$REPLY
      case $c in
        1|01) confirm "Перезапустить Docker?" && systemctl restart docker; pause ;;
        2|02) journalctl -u docker -n 120 --no-pager; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    read -r running total images <<<"$(docker_counts)"
    ui_top "DOCKER" "RUNNING"
    ui_blank
    ui_line "$version"
    ui_two "Containers: $running running / $total total" "Images: $images"
    ui_blank
    ui_section "ACTIONS"
    ui_blank
    ui_two "[01] Все контейнеры" "[07] Stats"
    ui_two "[02] Запущенные" "[08] Images"
    ui_two "[03] Запустить контейнер" "[09] Compose version"
    ui_two "[04] Остановить контейнер" "[10] Использование диска"
    ui_two "[05] Перезапустить контейнер" "[11] Безопасная очистка"
    ui_two "[06] Логи контейнера" "[12] Restart Docker"
    ui_blank
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "docker › "; c=$REPLY
    case $c in
      1|01) docker ps -a; pause ;;
      2|02) docker ps; pause ;;
      3|03) n=$(docker_choose_container) && docker start "$n"; pause ;;
      4|04) n=$(docker_choose_container) && confirm "Остановить $n?" && docker stop "$n"; pause ;;
      5|05) n=$(docker_choose_container) && confirm "Перезапустить $n?" && docker restart "$n"; pause ;;
      6|06) n=$(docker_choose_container) && docker logs --tail 200 "$n"; pause ;;
      7|07) docker stats --no-stream; pause ;;
      8|08) docker images; pause ;;
      9|09) docker compose version; pause ;;
      10) docker system df -v; pause ;;
      11) docker_cleanup; pause ;;
      12) confirm "Перезапустить службу Docker? Работа контейнеров может кратковременно прерваться." && systemctl restart docker; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
