# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** a web application. It's a distribution repo for four Claude Code skills (`sdd-idea`, `sdd-impl`, `sdd-undo`, `sdd-feature`) plus one shell script (`sdd-doctor.sh`). `install.sh` copies them into `~/.claude/skills/` and `~/.claude/scripts/`. All "code" here is Markdown (SKILL.md files) and Bash.

When users run the skills, they scaffold **target projects** (Django + htmx + Docker). Don't confuse this repo's stack (shell + markdown) with the stack those skills produce.

## Commands

```bash
./install.sh                     # copy skills + doctor into ~/.claude/
~/.claude/scripts/sdd-doctor.sh  # verify env (exits 0=ok, 1=blockers, 2=warnings)
bash -n scripts/sdd-doctor.sh    # syntax-check the doctor script
bash -n install.sh               # syntax-check the installer
```

There is no test suite, linter, or build. Validation is manual: run `install.sh`, then exercise a skill in a scratch directory.

## Architecture

### Skills are pure Markdown

Each `skills/<name>/SKILL.md` is an instruction file Claude Code loads when triggered. The YAML frontmatter (`name`, `description`) controls trigger matching — the description is where trigger phrases (EN + RU) go, and Claude Code uses it to decide when to invoke the skill. The Markdown body is the procedure the skill executes. No code is compiled or executed from these files — they are prompts.

### The four skills form a pipeline

- `sdd-idea` — interview → writes `PROJECT.md` (spec + phased plan). Writes **no code**.
- `sdd-impl` — reads `PROJECT.md`, builds the next unchecked phase end-to-end (scaffold on Phase 1; feature work on Phase 2+). Commits `phase N: <title>`.
- `sdd-undo` — `git revert` of the last `phase N: ...` commit plus any trailing review commits. Never `reset`, never force-push.
- `sdd-feature` — interview → appends new phases to an existing `PROJECT.md`. Writes **no code**.

Skills do not invoke each other. The handoff is via the user re-running the next command.

### Target-project stack is locked

Any change to `sdd-idea` or `sdd-impl` must preserve: Python 3.12, Django 5, Django Templates (not Jinja), SQLite, Pico.css (classless), htmx + `django-htmx`, Docker + compose v2, `django.test.TestCase` + `coverage`. The skills explicitly refuse ideas that don't fit this stack rather than adapting. Don't add Tailwind, React, Alpine, Celery, Redis, DRF, pytest, Selenium, or Jinja.

### Doctor contract

`sdd-doctor.sh` is the gate before every build operation. Skills parse its output. **Preserve these invariants:**
- Exit codes: `0` all green, `1` blockers, `2` warnings only.
- Last stdout line is exactly `SDD_DOCTOR: ok` | `SDD_DOCTOR: blockers=<N>` | `SDD_DOCTOR: warnings=<N>`. Skills grep for this — don't break the format.
- Frontend-design plugin is detected by grepping `"frontend-design@"` in `$SDD_PLUGINS_JSON` (default `~/.claude/plugins/installed_plugins.json`).
- Port is configurable via `SDD_PORT` (default `5000`).

### Installer invariants

- Backups go to `~/.claude/sdd-backups/<timestamp>/`, **never** inside `~/.claude/skills/`. If a backup lands in the skills dir, Claude Code registers `sdd-idea.bak-...` as a separate skill — this has burned us. Keep backups outside `skills/`.
- OS gate: refuses anything other than `Darwin` or `Linux`. Windows/WSL is not supported on purpose.
- All four skill names are hard-coded in the install loop: `sdd-idea sdd-impl sdd-undo sdd-feature`.

### Language conventions in SKILL.md

- All text the skill prints to the user, and everything it writes into `PROJECT.md` / `CLAUDE.md` of the target project, is **Russian** (informal "ты"). Skill instructions themselves and all code/identifiers stay English.
- When editing a SKILL.md, keep Russian user-facing strings Russian; don't "localize" to English.

## Cross-cutting rules (from user's global CLAUDE.md)

- Don't add comments or javadocs unless asked.
- Don't add extra logging.
- When reporting a bug, start by writing a test that reproduces it — don't jump to a fix.
- Don't over-engineer.
