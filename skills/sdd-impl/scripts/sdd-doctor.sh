#!/usr/bin/env bash
# sdd-doctor.sh — environment readiness check (and optional auto-fix) for SDD skills.
#
# Modes:
#   sdd-doctor.sh             — check only (unchanged behavior).
#   sdd-doctor.sh --install   — check, try to fix blockers on macOS, re-check.
#                               On Linux the install pass is a no-op and re-check
#                               equals first check, so the marker/exit-code
#                               contract still holds.
#   sdd-doctor.sh --help      — usage.
#
# Exit codes:  0 = all green, 1 = blockers, 2 = warnings only.
# Last line of stdout: SDD_DOCTOR: ok | SDD_DOCTOR: blockers=N | SDD_DOCTOR: warnings=N
# (callers parse this; keep the format exact.)

set -u

PLUGINS_JSON="${SDD_PLUGINS_JSON:-${HOME}/.claude/plugins/installed_plugins.json}"
PORT="${SDD_PORT:-5000}"

blockers=0
warnings=0
fixes=()
warnfixes=()

# --- status helpers ---------------------------------------------------------
ok()    { printf "✓ %s\n" "$1"; }
block() { printf "✗ %s\n" "$1"; blockers=$((blockers+1)); [ $# -ge 2 ] && fixes+=("$2"); }
warn()  { printf "⚠ %s\n" "$1"; warnings=$((warnings+1)); [ $# -ge 2 ] && warnfixes+=("$2"); }

# --- install-pass helpers (macOS) -------------------------------------------
have_brew() { command -v brew >/dev/null 2>&1; }
say_step()  { printf "→ %s\n" "$1"; }

reset_state() {
  blockers=0
  warnings=0
  fixes=()
  warnfixes=()
}

# --- individual checks ------------------------------------------------------

check_os() {
  local os
  os="$(uname -s 2>/dev/null || echo unknown)"
  case "$os" in
    Darwin) ok "OS: macOS" ;;
    Linux)  ok "OS: Linux" ;;
    *)      block "OS: $os (поддерживаются только macOS и Linux)" \
                  "SDD работает только на macOS и Linux. Windows/WSL не поддерживаются." ;;
  esac
}

check_docker_bin() {
  if command -v docker >/dev/null 2>&1; then
    ok "Docker установлен ($(docker --version 2>/dev/null | head -1))"
  else
    block "Docker не установлен" \
          "Поставь Docker Desktop: https://www.docker.com/products/docker-desktop/
   После установки запусти его и снова прогони /sdd-impl."
  fi
}

check_docker_daemon() {
  command -v docker >/dev/null 2>&1 || return 0
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon запущен"
  else
    if [ "$(uname -s)" = "Darwin" ]; then
      block "Docker установлен, но не запущен" \
            "Запусти Docker Desktop:    open -a Docker
   Подожди, пока иконка кита перестанет анимироваться, и попробуй снова."
    else
      block "Docker установлен, но не запущен" \
            "Запусти docker daemon:    sudo systemctl start docker
   Или запусти Docker Desktop вручную, если пользуешься им."
    fi
  fi
}

check_compose_v2() {
  command -v docker >/dev/null 2>&1 || return 0
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose v2 доступен"
  else
    block "docker compose v2 недоступен" \
          "Обнови Docker Desktop до свежей версии (v2+).
   На Linux поставь docker-compose-plugin:    sudo apt install docker-compose-plugin"
  fi
}

check_git() {
  if command -v git >/dev/null 2>&1; then
    ok "Git установлен ($(git --version 2>/dev/null))"
  else
    if [ "$(uname -s)" = "Darwin" ]; then
      block "Git не установлен" \
            "Поставь Git:    xcode-select --install"
    else
      block "Git не установлен" \
            "Поставь Git:    sudo apt install git    # или:    sudo dnf install git"
    fi
  fi
}

# Built-in skills (`simplify`, `security-review`) идут в составе Claude Code —
# проверять их на диске не нужно, они всегда доступны.
# frontend-design — плагин, его может не быть.
check_plugin() {
  if [ -f "$PLUGINS_JSON" ] && grep -q '"frontend-design@' "$PLUGINS_JSON" 2>/dev/null; then
    ok "Плагин frontend-design установлен"
  else
    block "Плагин frontend-design не установлен" \
          "Он нужен, чтобы UI выглядел живо, а не дефолтно-AI-шным.
   В Claude Code запусти:
       /plugin marketplace add anthropics/claude-code
       /plugin install frontend-design@claude-plugins-official
   Потом перезапусти Claude Code и вернись к SDD."
  fi
}

# warning — /sdd-impl gracefully degrades to extended curl checks if missing.
check_agent_browser() {
  if command -v agent-browser >/dev/null 2>&1; then
    ok "agent-browser установлен"
  else
    warn "agent-browser не установлен" \
         "Без него /sdd-impl не сможет визуально проверить фазу — ограничится curl-чеком.
   Поставь одной из команд:
       npm install -g agent-browser
       brew install agent-browser
   Затем один раз:    agent-browser install
   Подробности:       https://agent-browser.dev/"
  fi
}

check_cwd() {
  local probe=".sdd_doctor_write_$$"
  if touch "./$probe" 2>/dev/null; then
    rm -f "./$probe"
    ok "В текущую папку можно писать"
  else
    block "В текущую папку нельзя писать" \
          "Проверь права (chmod) или перейди в другую папку."
  fi
}

# df -k выводит размер в килобайтах; колонка "Available" — 4-я.
check_disk() {
  local avail_kb avail_gb
  avail_kb="$(df -k . 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -n "${avail_kb:-}" ] && [ "$avail_kb" -ge 1048576 ] 2>/dev/null; then
    avail_gb=$((avail_kb / 1048576))
    ok "Свободно на диске: ${avail_gb} GB"
  else
    block "На диске меньше 1 GB свободного места" \
          "Освободи место — Docker-образы и зависимости займут ~500 MB–1 GB."
  fi
}

# warning — auto-fix by caller (/sdd-impl при первом запуске сделает git init)
check_git_repo() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "Находимся в git-репозитории"
  else
    warn "git-репозиторий не инициализирован" \
         "Выполни:    git init
   /sdd-impl при первом запуске сделает это сам."
  fi
}

# warning — auto-fix by caller
check_gitignore() {
  if [ -f ".gitignore" ]; then
    ok ".gitignore на месте"
  else
    warn ".gitignore отсутствует" \
         "/sdd-impl создаст разумный .gitignore во время Фазы 1."
  fi
}

# warning — auto-fallback by caller; lsof есть почти везде, если нет — тихо пропустим.
check_port() {
  command -v lsof >/dev/null 2>&1 || return 0
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    warn "Порт $PORT занят" \
         "Это не блокер — /sdd-impl возьмёт следующий свободный (5001, 5002 ...).
   Если хочешь освободить $PORT, глянь что там:    lsof -nP -iTCP:$PORT -sTCP:LISTEN"
  else
    ok "Порт $PORT свободен"
  fi
}

run_checks() {
  check_os
  check_docker_bin
  check_docker_daemon
  check_compose_v2
  check_git
  check_plugin
  check_agent_browser
  check_cwd
  check_disk
  check_git_repo
  check_gitignore
  check_port
}

# --- install helpers (macOS) ------------------------------------------------
# Each install function is idempotent: checks the current state first and
# returns early if the tool is already present / running. Failures are
# swallowed so one install attempt never aborts the rest — the post-install
# re-check is what surfaces whatever is still broken.

install_git_macos() {
  command -v git >/dev/null 2>&1 && return 0
  if have_brew; then
    say_step "ставлю git через Homebrew"
    brew install git || true
  else
    say_step "запускаю xcode-select --install — прими диалог в macOS, потом запусти /sdd-impl снова"
    xcode-select --install >/dev/null 2>&1 || true
  fi
}

install_docker_macos() {
  command -v docker >/dev/null 2>&1 && return 0
  if have_brew; then
    say_step "ставлю Docker Desktop через Homebrew (brew install --cask docker)"
    brew install --cask docker || true
    echo "   После установки запусти Docker Desktop вручную — macOS попросит подтвердить привилегированного помощника."
  else
    echo "→ Docker Desktop нужно поставить вручную: https://www.docker.com/products/docker-desktop/"
  fi
}

install_compose_macos() {
  command -v docker >/dev/null 2>&1 || return 0
  docker compose version >/dev/null 2>&1 && return 0
  if have_brew; then
    say_step "обновляю Docker Desktop (brew upgrade --cask docker) — compose v2 приедет вместе"
    brew upgrade --cask docker || true
  else
    echo "→ Обнови Docker Desktop вручную: https://www.docker.com/products/docker-desktop/"
  fi
}

install_agent_browser_macos() {
  command -v agent-browser >/dev/null 2>&1 && return 0
  if have_brew; then
    say_step "ставлю agent-browser через Homebrew"
    brew install agent-browser || true
  elif command -v npm >/dev/null 2>&1; then
    say_step "ставлю agent-browser через npm"
    npm install -g agent-browser || true
  else
    echo "→ agent-browser нужно поставить вручную (нет ни Homebrew, ни npm):"
    echo "     npm install -g agent-browser    # сначала Node.js: https://nodejs.org/"
    echo "     brew install agent-browser      # сначала Homebrew: https://brew.sh/"
    echo "   Подробности: https://agent-browser.dev/"
    return 0
  fi
  if command -v agent-browser >/dev/null 2>&1; then
    say_step "agent-browser install — скачиваю встроенный Chrome"
    agent-browser install >/dev/null 2>&1 || true
  fi
}

start_docker_daemon_macos() {
  command -v docker >/dev/null 2>&1 || return 0
  docker info >/dev/null 2>&1 && return 0
  say_step "запускаю Docker Desktop (open -a Docker), жду до 30 секунд"
  open -a Docker >/dev/null 2>&1 || true
  local i
  for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
      say_step "Docker поднялся"
      return 0
    fi
    sleep 1
  done
  echo "→ Docker не поднялся за 30 секунд. Дождись кита в меню и запусти снова."
}

run_installs() {
  local os
  os="$(uname -s 2>/dev/null || echo unknown)"
  if [ "$os" != "Darwin" ]; then
    printf "\n→ Авто-установка пока только на macOS. Выполни шаги из блока выше вручную.\n"
    return 0
  fi
  printf "\nПробую поставить недостающее:\n"
  install_git_macos
  install_docker_macos
  start_docker_daemon_macos
  install_compose_macos
  install_agent_browser_macos
}

usage() {
  cat <<EOF
Usage: sdd-doctor.sh [--install|--help]

  (no flag)    Check the environment. Report ✓ / ⚠ / ✗ and exit 0/1/2.
  --install    Check, try to install missing tools on macOS (git, Docker,
               docker compose), then re-check. No auto-install on Linux —
               the install pass prints an info line and re-check mirrors
               the first check.
  --help       Show this message.
EOF
}

# --- argument parsing -------------------------------------------------------
mode=check
case "${1:-}" in
  --install) mode=install ;;
  --help|-h) usage; exit 0 ;;
  "")        mode=check ;;
  *)         usage; exit 2 ;;
esac

# --- run --------------------------------------------------------------------
printf "SDD — проверка окружения\n\n"

run_checks

if [ "$mode" = "install" ] && [ "$blockers" -gt 0 ]; then
  run_installs
  printf "\nПовторная проверка:\n\n"
  reset_state
  run_checks
fi

# --- summary ----------------------------------------------------------------
printf "\n"
if [ "$blockers" -eq 0 ] && [ "$warnings" -eq 0 ]; then
  echo "Окружение готово. Погнали."
  echo "SDD_DOCTOR: ok"
  exit 0
fi

if [ "$blockers" -gt 0 ]; then
  echo "Сначала почини вот это:"
  for f in "${fixes[@]}"; do
    printf "\n  • %s\n" "$f"
  done
fi

if [ "$warnings" -gt 0 ]; then
  printf "\n"
  echo "Предупреждения (не блокеры, но обрати внимание):"
  for w in "${warnfixes[@]}"; do
    printf "\n  • %s\n" "$w"
  done
fi

printf "\n"
if [ "$blockers" -gt 0 ]; then
  echo "SDD_DOCTOR: blockers=$blockers"
  exit 1
else
  echo "SDD_DOCTOR: warnings=$warnings"
  exit 2
fi
