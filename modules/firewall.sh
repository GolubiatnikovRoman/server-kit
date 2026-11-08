#!/usr/bin/env bash

ufw_installed() { command_exists ufw; }
ufw_active() { ufw_installed && ufw status 2>/dev/null | grep -q '^Status: active'; }

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
    if ufw_active; then state="включён"; elif ufw_installed; then state="выключен"; else state="не установлен"; fi
    box "Межсетевой экран · UFW: $state"       "1. Установить UFW"       "2. Включить UFW безопасно"       "3. Отключить UFW"       ""       "4. Открыть порт"       "5. Закрыть порт"       "6. Разрешить IP/подсеть"       ""       "7. Показать правила с номерами"       "8. Удалить правило по номеру"       "0. Назад"
    printf '\n'
    ask_num "Выбор [0-8]: "; c=$REPLY
    case $c in
      1) firewall_install; pause ;; 2) firewall_enable; pause ;;
      3) ufw_installed && confirm "Отключить UFW?" && ufw disable; pause ;;
      4) ufw_installed && firewall_open_port || err "UFW не установлен"; pause ;;
      5) ufw_installed && firewall_close_port || err "UFW не установлен"; pause ;;
      6) ufw_installed && firewall_allow_ip || err "UFW не установлен"; pause ;;
      7) ufw_installed && ufw status numbered; pause ;;
      8) if ufw_installed; then read -r -p 'Номер правила: ' n; [[ $n =~ ^[0-9]+$ ]] && confirm "Удалить правило №$n?" && ufw --force delete "$n"; fi; pause ;;
      0|"") return ;; *) echo "Нет такого пункта." ;;
    esac
  done
}
