#!/usr/bin/env bash
# install.sh — installs SDD skills into ~/.claude/.
#
# Copies:
#   skills/sdd-idea      → ~/.claude/skills/sdd-idea
#   skills/sdd-impl      → ~/.claude/skills/sdd-impl    (bundles scripts/sdd-doctor.sh)
#   skills/sdd-undo      → ~/.claude/skills/sdd-undo
#   skills/sdd-feature   → ~/.claude/skills/sdd-feature
#   skills/sdd-change    → ~/.claude/skills/sdd-change
#
# Overwrites any existing SDD skill directory in place — re-run any time
# to pick up the latest version.

set -euo pipefail

# --- paths --------------------------------------------------------
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_skills="$here/skills"
dst_skills="$HOME/.claude/skills"

# --- preflight ----------------------------------------------------
if [ ! -d "$src_skills" ] || [ ! -f "$src_skills/sdd-impl/scripts/sdd-doctor.sh" ]; then
  echo "✗ Структура репозитория неожиданная."
  echo "  Ожидал: $src_skills и $src_skills/sdd-impl/scripts/sdd-doctor.sh"
  echo "  Запускай install.sh из корня репозитория SDD-mini."
  exit 1
fi

os="$(uname -s)"
if [ "$os" != "Darwin" ] && [ "$os" != "Linux" ]; then
  echo "✗ SDD работает только на macOS и Linux. У тебя: $os."
  exit 1
fi

mkdir -p "$dst_skills"

# --- install skills ------------------------------------------------
echo "Устанавливаю SDD-скиллы в $dst_skills"
for skill in sdd-idea sdd-impl sdd-undo sdd-feature sdd-change; do
  src="$src_skills/$skill"
  dst="$dst_skills/$skill"
  if [ ! -d "$src" ]; then
    echo "  ✗ не найден $src — пропускаю"
    continue
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  echo "  ✓ $skill"
done

# Make sure the doctor script is executable after copy.
dst_doctor="$dst_skills/sdd-impl/scripts/sdd-doctor.sh"
if [ -f "$dst_doctor" ]; then
  chmod +x "$dst_doctor"
fi

# --- old-location cleanup ------------------------------------------
# Earlier versions installed the doctor to ~/.claude/scripts/sdd-doctor.sh.
# Delete it so stale copies don't get called by accident.
legacy_doctor="$HOME/.claude/scripts/sdd-doctor.sh"
if [ -f "$legacy_doctor" ]; then
  echo
  echo "Нашёл старую копию sdd-doctor.sh в ~/.claude/scripts/ — удаляю."
  rm -f "$legacy_doctor"
fi

# --- final check --------------------------------------------------
echo
echo "Проверяю, что доктор запускается…"
if "$dst_doctor" >/dev/null 2>&1; then
  rc=$?
else
  rc=$?
fi
case "$rc" in
  0) echo "  ✓ окружение полностью готово" ;;
  1) echo "  ⚠ доктор нашёл блокеры — запусти '$dst_doctor', почини и попробуй снова." ;;
  2) echo "  ✓ доктор работает (есть мелкие предупреждения — это ок)" ;;
  *) echo "  ✗ доктор завершился с кодом $rc — что-то сломано, посмотри вывод '$dst_doctor'" ;;
esac

cat <<EOF

Установка завершена.

Команды теперь доступны в Claude Code:
  /sdd-idea      — спроектировать новый веб-проект (Django + htmx)
  /sdd-impl      — построить следующую фазу (Django + htmx в Docker, коммит и тесты в конце)
  /sdd-undo      — откатить последнюю фазу
  /sdd-feature   — добавить новую фичу в существующий проект
  /sdd-change    — изменить спеку или план (если код уже есть — появится фаза миграции)

Если Claude Code запущен — перезапусти его, чтобы подхватить новые скиллы.
Начни с /sdd-idea в пустой папке и расскажи про свою идею.
EOF
