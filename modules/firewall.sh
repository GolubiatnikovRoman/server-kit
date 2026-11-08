#!/usr/bin/env bash

ufw_installed() { command_exists ufw; }
ufw_active() { ufw_installed && ufw status 2>/dev/null | grep -q '^Status: active'; }

ufw_ssh_allowed() {
  ufw_active || return 1
  local p
  p=$(ssh_port)
  ufw status 2>/dev/null | grep -Eq "^[[:space:]]*${p}/tcp([[:space:]]|$).*ALLOW"
}

firewall_install() {
  ufw_installed && { warn "UFW уже установлен"; return; }
  confirm "Установить UFW?" || return
  apt-get update && apt-get install -y ufw
  ok "UFW установлен"
}

firewall_enable() {
  ufw_installed || { err "Сначала установите UFW"; return 1; }
  local p
  p=$(ssh_port)
  backup_file /etc/ufw firewall >/dev/null || true
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "$p/tcp"
  ok "Перед включением разрешён текущий SSH-порт $p/tcp"
  warn "Если у VPS есть внешний firewall/security group, его правила SERVER-KIT изменить не может."
  confirm "Включить UFW?" && ufw --force enable
}

firewall_open_port() {
  local p proto
  read -r -p 'Порт: ' p; validate_port "$p" || { err "Некорректный порт"; return; }
  read -r -p 'Протокол [tcp/udp, по умолчанию tcp]: ' proto; proto=${proto:-tcp}
  [[ $proto == tcp || $proto == udp ]] || { err "Допустимы tcp или udp"; return; }
  ufw allow "$p/$proto"
}

firewall_close_port() {
  local p proto current
  read -r -p 'Порт: ' p; validate_port "$p" || { err "Некорректный порт"; return; }
  current=$(ssh_port)
  [[ $p != "$current" ]] || { err "SERVER-KIT не закроет текущий SSH-порт $current через это меню"; return; }
  read -r -p 'Протокол [tcp/udp, по умолчанию tcp]: ' proto; proto=${proto:-tcp}
  [[ $proto == tcp || $proto == udp ]] || return
  confirm "Удалить разрешающее правило $p/$proto?" && ufw delete allow "$p/$proto"
}

firewall_allow_ip() {
  local ip
  read -r -p 'IPv4/IPv6 адрес или подсеть CIDR: ' ip
  [[ $ip =~ ^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$ ]] || { err "Некорректный адрес"; return; }
  ufw allow from "$ip"
}

firewall_menu() {
  local c state
  while true; do
    header

    if ! ufw_installed; then
      ui_top "FIREWALL" "UFW"
      ui_blank
      ui_line "UFW не установлен"
      ui_blank
      ui_line "[01] Установить UFW"
      ui_line "[00] Назад"
      ui_bottom
      printf '\n'
      ask_num "firewall › "; c=$REPLY
      case $c in
        1|01) firewall_install; pause ;;
        0|00|"") return ;;
        *) echo "Нет такого пункта." ;;
      esac
      continue
    fi

    ufw_active && state="ACTIVE" || state="OFF"
    ui_top "FIREWALL" "$state"
    ui_blank
    ui_line "Текущий SSH-порт: $(ssh_port)/tcp"
    if ufw_active; then
      if ufw_ssh_allowed; then ui_line "SSH в UFW: разрешён"
      else ui_line "SSH в UFW: ВНИМАНИЕ — правило не найдено"
      fi
    fi
    ui_blank
    if ufw_active; then
      ui_line "[01] Отключить UFW"
    else
      ui_line "[01] Включить UFW безопасно"
    fi
    ui_line "[02] Открыть порт"
    ui_line "[03] Закрыть порт"
    ui_line "[04] Разрешить IP/подсеть"
    ui_blank
    ui_line "[05] Показать правила"
    ui_line "[06] Удалить правило по номеру"
    ui_line "[00] Назад"
    ui_bottom

    printf '\n'
    ask_num "firewall › "; c=$REPLY
    case $c in
      1|01)
        if ufw_active; then confirm "Отключить UFW?" && ufw disable
        else firewall_enable
        fi
        pause ;;
      2|02) firewall_open_port; pause ;;
      3|03) firewall_close_port; pause ;;
      4|04) firewall_allow_ip; pause ;;
      5|05) ufw status numbered; pause ;;
      6|06) read -r -p 'Номер правила: ' n; [[ $n =~ ^[0-9]+$ ]] && confirm "Удалить правило №$n?" && ufw --force delete "$n"; pause ;;
      0|00|"") return ;;
      *) echo "Нет такого пункта." ;;
    esac
  done
}
