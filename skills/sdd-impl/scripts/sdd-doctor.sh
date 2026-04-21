#!/usr/bin/env bash
# sdd-doctor.sh — environment readiness check for SDD skills.
#
# Exit codes:  0 = all green, 1 = blockers, 2 = warnings only.
# Last line of stdout: SDD_DOCTOR: ok | SDD_DOCTOR: blockers=N | SDD_DOCTOR: warnings=N
# (skills parse this; keep the format exact.)

set -u

PLUGINS_JSON="${SDD_PLUGINS_JSON:-${HOME}/.claude/plugins/installed_plugins.json}"
PORT="${SDD_PORT:-5000}"

blockers=0
warnings=0
fixes=()
warnfixes=()

ok()    { printf "✓ %s\n" "$1"; }
block() { printf "✗ %s\n" "$1"; blockers=$((blockers+1)); [ $# -ge 2 ] && fixes+=("$2"); }
warn()  { printf "⚠ %s\n" "$1"; warnings=$((warnings+1)); [ $# -ge 2 ] && warnfixes+=("$2"); }

printf "SDD — проверка окружения\n\n"

# ---- OS ---------------------------------------------------------------------
os="$(uname -s 2>/dev/null || echo unknown)"
case "$os" in
  Darwin) ok "OS: macOS" ;;
  Linux)  ok "OS: Linux" ;;
  *)      block "OS: $os (поддерживаются только macOS и Linux)" \
                "SDD работает только на macOS и Linux. Windows/WSL не поддерживаются." ;;
esac

# ---- Docker binary ---------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  ok "Docker установлен ($(docker --version 2>/dev/null | head -1))"
else
  block "Docker не установлен" \
        "Поставь Docker Desktop: https://www.docker.com/products/docker-desktop/
   После установки запусти его и снова прогони /sdd-impl."
fi

# ---- Docker daemon ---------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon запущен"
  else
    if [ "$os" = "Darwin" ]; then
      block "Docker установлен, но не запущен" \
            "Запусти Docker Desktop:    open -a Docker
   Подожди, пока иконка кита перестанет анимироваться, и попробуй снова."
    else
      block "Docker установлен, но не запущен" \
            "Запусти docker daemon:    sudo systemctl start docker
   Или запусти Docker Desktop вручную, если пользуешься им."
    fi
  fi
fi

# ---- docker compose v2 -----------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose v2 доступен"
  else
    block "docker compose v2 недоступен" \
          "Обнови Docker Desktop до свежей версии (v2+).
   На Linux поставь docker-compose-plugin:    sudo apt install docker-compose-plugin"
  fi
fi

# ---- git -------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  ok "Git установлен ($(git --version 2>/dev/null))"
else
  if [ "$os" = "Darwin" ]; then
    block "Git не установлен" \
          "Поставь Git:    xcode-select --install"
  else
    block "Git не установлен" \
          "Поставь Git:    sudo apt install git    # или:    sudo dnf install git"
  fi
fi

# ---- frontend-design plugin ------------------------------------------------
# Built-in skills (`simplify`, `security-review`) идут в составе Claude Code —
# проверять их на диске не нужно, они всегда доступны.
# frontend-design — плагин, его может не быть.
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

# ---- cwd writable ----------------------------------------------------------
probe=".sdd_doctor_write_$$"
if touch "./$probe" 2>/dev/null; then
  rm -f "./$probe"
  ok "В текущую папку можно писать"
else
  block "В текущую папку нельзя писать" \
        "Проверь права (chmod) или перейди в другую папку."
fi

# ---- disk space ≥1 GB ------------------------------------------------------
# df -k выводит размер в килобайтах; колонка "Available" — 4-я.
avail_kb="$(df -k . 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "${avail_kb:-}" ] && [ "$avail_kb" -ge 1048576 ] 2>/dev/null; then
  avail_gb=$((avail_kb / 1048576))
  ok "Свободно на диске: ${avail_gb} GB"
else
  block "На диске меньше 1 GB свободного места" \
        "Освободи место — Docker-образы и зависимости займут ~500 MB–1 GB."
fi

# ---- git repo (warning — auto-fix by caller) -------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "Находимся в git-репозитории"
else
  warn "git-репозиторий не инициализирован" \
       "Выполни:    git init
   /sdd-impl при первом запуске сделает это сам."
fi

# ---- .gitignore (warning — auto-fix by caller) -----------------------------
if [ -f ".gitignore" ]; then
  ok ".gitignore на месте"
else
  warn ".gitignore отсутствует" \
       "/sdd-impl создаст разумный .gitignore во время Фазы 1."
fi

# ---- port 5000 (warning — auto-fallback by caller) -------------------------
# lsof есть почти везде; если нет — тихо пропустим.
if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    warn "Порт $PORT занят" \
         "Это не блокер — /sdd-impl возьмёт следующий свободный (5001, 5002 ...).
   Если хочешь освободить $PORT, глянь что там:    lsof -nP -iTCP:$PORT -sTCP:LISTEN"
  else
    ok "Порт $PORT свободен"
  fi
fi

# ---- summary ---------------------------------------------------------------
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
