#!/usr/bin/env bash
# install.sh — installs SDD skills into ~/.claude/.
#
# Copies:
#   skills/sdd-idea      → ~/.claude/skills/sdd-idea
#   skills/sdd-impl      → ~/.claude/skills/sdd-impl    (bundles sdd-doctor.sh)
#   skills/sdd-undo      → ~/.claude/skills/sdd-undo
#   skills/sdd-feature   → ~/.claude/skills/sdd-feature
#
# Safe: if a destination directory already exists, it's renamed into
# ~/.claude/sdd-backups/<timestamp>/ instead of being overwritten.

set -euo pipefail

# --- paths --------------------------------------------------------
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_skills="$here/skills"
dst_skills="$HOME/.claude/skills"
# Backups live OUTSIDE ~/.claude/skills so Claude Code doesn't register
# old copies as separate skills.
backup_root="$HOME/.claude/sdd-backups"

# --- preflight ----------------------------------------------------
if [ ! -d "$src_skills" ] || [ ! -f "$src_skills/sdd-impl/sdd-doctor.sh" ]; then
  echo "✗ Структура репозитория неожиданная."
  echo "  Ожидал: $src_skills и $src_skills/sdd-impl/sdd-doctor.sh"
  echo "  Запускай install.sh из корня репозитория SDD4beginners."
  exit 1
fi

os="$(uname -s)"
if [ "$os" != "Darwin" ] && [ "$os" != "Linux" ]; then
  echo "✗ SDD работает только на macOS и Linux. У тебя: $os."
  exit 1
fi

mkdir -p "$dst_skills"

# --- backup helper ------------------------------------------------
# Backups go into $backup_root/<timestamp>/ — outside ~/.claude/skills,
# so Claude Code doesn't register old copies as separate skills.
stamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$backup_root/$stamp"
backup_made=0

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    if [ "$backup_made" -eq 0 ]; then
      mkdir -p "$backup_dir"
      backup_made=1
    fi
    local bak="$backup_dir/$(basename "$target")"
    echo "  ↪ сохраняю старое в $bak"
    mv "$target" "$bak"
  fi
}

# --- install skills ------------------------------------------------
echo "Устанавливаю SDD-скиллы в $dst_skills"
for skill in sdd-idea sdd-impl sdd-undo sdd-feature; do
  src="$src_skills/$skill"
  dst="$dst_skills/$skill"
  if [ ! -d "$src" ]; then
    echo "  ✗ не найден $src — пропускаю"
    continue
  fi
  backup_if_exists "$dst"
  cp -R "$src" "$dst"
  echo "  ✓ $skill"
done

# Make sure the doctor script is executable after copy.
dst_doctor="$dst_skills/sdd-impl/sdd-doctor.sh"
if [ -f "$dst_doctor" ]; then
  chmod +x "$dst_doctor"
fi

# --- old-location cleanup ------------------------------------------
# Earlier versions installed the doctor to ~/.claude/scripts/sdd-doctor.sh.
# Move it aside so stale copies don't get called by accident.
legacy_doctor="$HOME/.claude/scripts/sdd-doctor.sh"
if [ -f "$legacy_doctor" ]; then
  echo
  echo "Нашёл старую копию sdd-doctor.sh в ~/.claude/scripts/ — переношу в бэкап."
  backup_if_exists "$legacy_doctor"
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
  /sdd-idea      — спроектировать новый проект (любого типа: веб, SPA, мобильный, CLI…)
  /sdd-impl      — построить следующую фазу (или выдать handoff для стеков вне scaffold)
  /sdd-undo      — откатить последнюю фазу
  /sdd-feature   — добавить новую фичу в существующий проект

Если Claude Code запущен — перезапусти его, чтобы подхватить новые скиллы.
Начни с /sdd-idea в пустой папке и расскажи про свою идею.
EOF

if [ "$backup_made" -eq 1 ]; then
  echo
  echo "Старые копии сохранены в: $backup_dir"
fi
