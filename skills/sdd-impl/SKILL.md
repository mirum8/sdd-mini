---
name: sdd-impl
description: >
  Build the next unchecked phase of an SDD project. Runs the doctor on
  the first phase, reads the Django + htmx recipe from PROJECT.md,
  executes Phase 1 setup or feature tasks, writes unit tests until
  coverage hits 100% on changed files, verifies via HTTP + regression
  against earlier phases, invokes frontend-design for any UI work, then
  runs simplify and security-review on the diff before committing
  `phase N: <title>`. **Only runs when the user explicitly invokes
  `/sdd-impl`.** Do NOT auto-invoke on phrases like "next phase",
  "continue", "implement", "build", "keep building", "построй фазу",
  "следующая фаза", "продолжай", etc. — those phrases alone are not
  enough; wait for the explicit slash command. Every run ends with one
  commit.
---

# sdd-impl — build the next phase

Reads `PROJECT.md`, finds the first phase with an unchecked task, implements it end-to-end (code + tests + verification + commit). PROJECT.md is self-contained — it carries the full Django + htmx recipe in its `## Стек` section, so this skill never opens a reference file.

## Plan mode (mandatory first action)

The first thing this skill does is switch to plan mode. Call `EnterPlanMode` before any other step.

Inside plan mode:
- Run the **Common preamble** below (all reads: parse `PROJECT.md`, check git status, detect setup vs feature sub-mode, look at the project files on disk).
- Compose a concrete plan for the next phase: files to create or modify, tests to add, commands to run (`docker compose`, migrations, test runner), expected commit message.
- Present that plan via `ExitPlanMode` for the user to approve.

Only after the user accepts the plan and plan mode exits do you perform file writes, run commands, run `simplify` / `security-review`, and make the `phase N: <title>` commit.

If the user rejects the plan, revise it and call `ExitPlanMode` again with the updated plan. Do not leave plan mode unilaterally.

## Sub-modes

`/sdd-impl` always works on a Django + htmx project. There are two sub-modes, decided by what's on disk:

- **Setup mode** — PROJECT.md exists but the project hasn't been built yet (no `manage.py`, no `docker-compose.yml`). Always Phase 1. The skill follows the recipe in `### Структура проекта (Фаза 1)` of PROJECT.md.
- **Feature mode** — the project already exists and at least one phase is done. The skill implements the tasks of the current phase (new views / models / forms / templates / tests).

Both sub-modes share a common tail: tests + 100% coverage → verification → regression → `simplify` → `security-review` → final verification → commit.

## Common preamble (every run)

1. **PROJECT.md present?** If not, say in Russian: «Сначала запусти `/sdd-idea`, чтобы появился план. `/sdd-impl` реализует фазы по готовому `PROJECT.md`.» Then exit.
2. **Parse the stack.** Find the `## Стек` section in PROJECT.md. Confirm `name: django-htmx`. If the section is missing or names a different stack, say in Russian: «В `PROJECT.md` нет секции `## Стек` или указан незнакомый стек. Похоже, план из старой версии SDD. Запусти `/sdd-idea` с опцией «Начать заново», чтобы обновить план.» Then exit.
3. **Status header.** Find the first phase with any unchecked `- [ ]` task. Print in Russian:

        <Project name>
        Стек: Django + htmx
        Сделано: <N>/<total> фаз
        Следующая: Фаза <K> — <title>

4. **All phases done?** Congratulate the user (Russian) and suggest `/sdd-feature` for extensions.
5. **Dirty git (feature mode).** If `git status --porcelain` is non-empty, `AskUserQuestion`:
   - Label «Продолжить с первой незакрытой задачи» → leave changes as-is, continue.
   - Label «Откатить изменения и начать фазу заново» → run `git checkout -- .` (only after explicit confirmation), then continue.
6. **Snapshot the plan.** If this phase hasn't been snapshotted yet, copy `PROJECT.md` → `PROJECT.v<N>.md` (N = next free integer). Snapshot happens once per phase, not per run. Indicator that this run is the start of a phase: none of the phase's tasks are marked `- [x]` yet.
7. **Doctor — setup mode only.** If this is setup mode (no project on disk yet — see detection above), run `"$HOME/.claude/skills/sdd-impl/scripts/sdd-doctor.sh"` now. Look at the last line of stdout:
   - `SDD_DOCTOR: ok` or `SDD_DOCTOR: warnings=<N>` → continue.
   - `SDD_DOCTOR: blockers=<N>` → `AskUserQuestion` (one question, Russian, informal "ты"): «Доктор нашёл блокеры. Попробовать поставить недостающие инструменты автоматически? На macOS через Homebrew (если он есть), иначе — откроется системный диалог установки. Может попросить sudo-пароль.»
      - «Да, поставь» → run `"$HOME/.claude/skills/sdd-impl/scripts/sdd-doctor.sh" --install`. Look at the new last line: if `ok` or `warnings=<N>` → continue; if still `blockers=<N>` → surface the (post-install) "Сначала почини вот это" block from the doctor's output and exit.
      - «Нет, я сам» → surface the original "Сначала почини вот это" block and exit.

   In feature mode, skip this step — the environment was validated at the first run; if something is actually broken later, let the real `docker compose` / `git` command fail with its concrete error, then suggest running the doctor manually for diagnosis.

## Setup mode

Runs when no project files exist on disk.

### Project name and slug

Read the human name from `# <name>` at the top of `PROJECT.md`. Derive a slug for Django: lowercase, Cyrillic → `app`, spaces and dashes → underscores. Examples:

| PROJECT.md | slug |
|---|---|
| «Менеджер закладок» | `app` |
| «Recipe Tracker» | `recipe_tracker` |
| «Мой бюджет» | `app` |

When in doubt, use `app`. The human name (Russian) stays in `PROJECT.md`, `CLAUDE.md`, and the home page header. The slug is plumbing.

### Steps

Follow the recipe in PROJECT.md's `## Стек / ### Структура проекта (Фаза 1)` section literally:

1. **Create starter files** — each code block in the recipe indicates a target path (right above or inside the block). Write the contents verbatim, substituting `<Project display name>` / `<slug>` placeholders with the real values.
2. **Initialize git** if the doctor warned it wasn't initialized:

        git init
        git add .gitignore
        git commit --allow-empty -m "init"

   The empty commit ensures `phase 1: setup` is the second commit, which makes rollback via `/sdd-undo` cleaner.
3. **Run setup commands** listed in the recipe (e.g. `docker compose run ... django-admin startproject`). Commands run inside the container whenever possible.
4. **Patch any framework config** (Django settings) per the recipe's explicit list.
5. **UI gate for the home view.** If the recipe marks a template as "generated by frontend-design", use the `Skill` tool to invoke `frontend-design:frontend-design`. Pass context:
   - The project name and a one-or-two-sentence description (from the "Что это" section of `PROJECT.md`).
   - What already exists: the base template / layout from the recipe (Pico.css + htmx).
   - The constraint listed in the recipe (e.g. home template must include `<h1>{{ project_name }}</h1>` for the test to pass).

   Save the resulting template to the path the recipe indicates.
6. **Boot the container + run bootstrap commands** from the recipe (`docker compose up -d`, `docker compose exec -T app python manage.py migrate`, `docker compose exec -T app python manage.py createsuperuser --noinput`).
7. **Write a short `CLAUDE.md`** in the generated project with just a pointer:

        # <Project display name>

        Этот проект создан через SDD. Стек, правила, план по фазам и
        инструкция по сборке Phase 1 — в `PROJECT.md`. Читай его первым.

        Кратко:
        - Запуск: `docker compose up -d --build`
        - Тесты: см. секцию «Как тестировать» в `PROJECT.md`.
        - Покрытие: 100% на изменённых файлах — иначе фаза не
          коммитится.
        - Коммиты: один на фазу (`phase N: <заголовок>`). Откат — через
          `/sdd-undo`.

8. **Tick off** Phase 1 tasks in `PROJECT.md` as each is done (`- [ ]` → `- [x]`).

Then proceed to the common tail.

## Feature mode (Phase 2+)

Runs when project files exist on disk.

1. **Read context.** Open the files this phase's tasks touch — models, views, templates, tests. Don't read the whole project — only what you're working on.
2. **UI gate.** If any task in this phase involves creating or editing templates, CSS, or htmx fragments, **invoke `frontend-design:frontend-design` via the `Skill` tool *before* writing any UI code.** Pass:
   - Which page/component we're building (the specific task).
   - The project's existing visual style (base layout, current templates, any custom CSS).
   - The feature description from `PROJECT.md`.
   Use the skill's output as guidance for the UI in this phase.
3. **Implement tasks sequentially.** After each task, flip `- [ ]` to `- [x]` in `PROJECT.md`.
4. **Write unit tests alongside the code.** File layout and test framework come from PROJECT.md's `### Как тестировать` — follow that exactly. Typical location: `core/tests/test_<feature>.py`.
5. **Migrations.** If models changed, follow the migrate-dev-check sequence in PROJECT.md's `### Как тестировать` section. `migrate --check` must succeed before commit.
6. **htmx patterns.** Follow the pattern documented in PROJECT.md's `### Структура проекта` or `### Как тестировать` section. Every list/form view has full-page + fragment branches based on `request.htmx`.

Then proceed to the common tail.

## Common tail (both sub-modes)

### 1. Tests and coverage — first pass

Run the command in PROJECT.md's `### Как тестировать` section literally. Typical pattern:

    docker compose exec -T app coverage run --source='.' manage.py test
    docker compose exec -T app coverage report --fail-under=100 --include='core/*.py' --omit='core/migrations/*,core/tests/*,core/apps.py,core/admin.py'

If tests fail, fix until green.

If coverage is below 100% on included paths, add the missing tests. Up to 3 attempts; after three, `AskUserQuestion` in Russian:
- Label «Попробовать с другой стороны» — one more approach.
- Label «Закрыть фазу с пометкой ⚠» — mark the problematic file in `PROJECT.md` and move on.
- Label «Стоп» — exit; the user will investigate.

### 2. Verification

Bring up the app:

    docker compose up -d --build

Wait 15 seconds, confirm `GET /` returns 200.

Run this phase's checkpoint from `PROJECT.md` — as HTTP request(s) + a content assertion (look for a specific substring in the HTML/JSON). Use `curl` or a short in-container Python script. Don't click anything in a browser — this has to be automated.

Then **regression:** run every previous phase's checkpoint. If any fails, stop and surface to the user.

### 3. `simplify` on the diff

Invoke `simplify` via the `Skill` tool. Context: "Here is the list of files I changed in this phase: `<list>`. The phase goal from PROJECT.md is: `<goal>`. The stack is Django + htmx. Walk through and remove anything unnecessary."

If `simplify` modified any file, return to step 1 (tests + coverage) and step 2 (verification). Once green again, continue.

### 4. `security-review` on the diff

Invoke `security-review` via the `Skill` tool. Surface Django + htmx-appropriate concerns:
- SQL injection (parameterize via the ORM).
- XSS in templates (autoescape is on by default).
- CSRF (htmx wired via `django_htmx`).
- Auth bypass.
- Secrets in commits.

Auto-apply only low-risk fixes (XSS fix, parameterization, removing a stray secret). Anything that changes behavior — `AskUserQuestion` before applying. Never change architecture or add dependencies beyond what the phase requires.

If anything was applied, return to steps 1 and 2.

### 5. Self-review

Skim the diff:
- Broken imports?
- Empty / obviously-template tests (ones that pass no matter what)?
- Missing parts of the phase's task list?

After `simplify` + `security-review` there's rarely anything left, but check. Fix anything clearly broken. For behavior changes, `AskUserQuestion`.

### 6. Commit

    git add <specific files from this phase>
    git commit -m "phase <N>: <phase title from PROJECT.md>"

**Never `git add -A`** — too easy to sweep in `.env`, `db.sqlite3`, caches. Track the files the phase touched and stage them by name. In setup mode that's the starter files + the framework-generated project; in feature mode, only the files that were actually edited.

Print the short SHA via `git log -1 --format=%h`.

### 7. Report to the user (Russian)

    ✓ Фаза <N>: <title> готова.

    Что появилось:
      - <1–3 lines describing the feature>
      - [setup mode only] Админка: http://localhost:<port>/admin/ (admin/admin)

    Проверь в браузере: http://localhost:<port>
    <short instruction, what to click>

    Коммит: <sha>

Then `AskUserQuestion`:
- Label «Следующая фаза» → tell the user to run `/sdd-impl` again.
- Label «Пауза» → thanks, exit.
- Label «Что-то не так» → user describes the issue; if it sounds like a bad phase, suggest `/sdd-undo`.

## Error handling

If something breaks during phase implementation (dependencies won't install, the container crashes, tests fail in a non-obvious way):
1. Try to fix — up to 3 attempts.
2. If fixing breaks a previous phase's work, fix it properly anyway (working code outranks phase boundaries), but note the cross-phase fix under the relevant phase in `PROJECT.md` as a comment line.
3. After 3 unsuccessful attempts, `AskUserQuestion` in Russian:
   - Label «Попробовать другим способом» → one more approach.
   - Label «Пропустить эту задачу с ⚠» → replace `- [ ]` with `- [ ] ⚠` in `PROJECT.md`, move on.
   - Label «Стоп» → exit, leave state as-is.
4. Never silently swallow errors. Always surface what went wrong to the user.

## What not to do

- Do not run framework CLIs on the host (`python manage.py`, etc.). Everything goes through `docker compose exec` or `docker compose run`.
- Do not change the stack. If it feels like a new dependency is needed, justify to yourself that the phase genuinely requires it. Never add Tailwind, React, Celery, Redis, DRF, etc. casually.
- Do not `git reset --hard` or force-push. Rollback is the user's call via `/sdd-undo`.
- Do not skip tests. 100% coverage on changed files (`core/*.py`, excluding migrations/tests/apps/admin) is a hard requirement.
- Do not rewrite `PROJECT.md` wholesale. Allowed: ticking boxes; adding a small sub-task if a phase missed something; marking a task `⚠`.
- Do not return JSON from views — htmx wants HTML fragments.
- Do not open a reference file from `~/.claude/skills/sdd-idea/references/`. PROJECT.md is the contract; everything you need is there.
