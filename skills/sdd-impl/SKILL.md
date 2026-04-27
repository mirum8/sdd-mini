---
name: sdd-impl
description: >
  Build the next unchecked phase of an SDD project. Runs the doctor on
  the first phase, reads the Django + htmx recipe from ./tech-stack.md
  (copied into the project by /sdd-idea), executes Phase 1 setup or
  feature tasks, writes unit tests until
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

Reads `PROJECT.md`, finds the first phase with an unchecked task, implements it end-to-end (code + tests + verification + commit). `PROJECT.md` carries the spec and the phase plan; the Django + htmx recipe (scaffolding files, test commands, htmx patterns, «do not bring in» list) lives in `./tech-stack.md`, which `/sdd-idea` copied into the project. This skill reads `tech-stack.md` literally — it's the stack contract.

## Audience and tone

The user is a vibe coder. Speak Russian informally ("ты"), friendly, short sentences. Most messages in this skill are canned (status header, phase-complete report, doctor question, error options), but when you need to compose free text — explaining a test failure, a coverage gap, what went wrong with a command — describe it in terms the user can act on, not the internal machinery. Avoid `payload`, `endpoint`, `workflow`, `cron`, `middleware`, `fragment`, `swap`, `pending` in user-facing Russian; full guidance in `sdd-idea/SKILL.md` → "How to talk about features and screens".

## Plan gate (sub-mode-aware)

Before any file writes, the skill stops once for user approval. **How** it stops depends on the sub-mode — because what's at stake is different.

**Setup mode (Phase 1):** the plan is recipe-verbatim — there are no design decisions, only «follow `tech-stack.md` Phase 1 step by step». A formal `EnterPlanMode` here adds friction without payoff and, in some harnesses, exits unilaterally the moment you run the doctor (a `Bash` script). So in setup mode:

1. Detect sub-mode by disk state (`manage.py` + `docker-compose.yml` absent → setup).
2. Run the **Common preamble** below — including the doctor — without entering plan mode. All steps are read-only.
3. Present a short plan inline in chat: project name, slug, port (from doctor), the file list from the recipe, what `frontend-design` will be asked to do.
4. `AskUserQuestion` with two options: «Поехали, строим (Рекомендуется)» / «Подожди, поправлю». Wait for confirmation before executing.

**Feature mode (Phase 2+):** here decisions matter — model fields, view organisation, htmx fragment splits — so the formal plan-mode workflow is worth the friction.

1. Call `EnterPlanMode` first.
2. Inside plan mode, run the Common preamble (reads only — git status, PROJECT.md, tech-stack.md, the files this phase will touch).
3. Write the plan to the plan file the harness specifies, then call `ExitPlanMode` for approval.
4. Only after the user accepts do you write files, run commands, invoke other skills, and commit.

If the user rejects the plan in either mode, revise and re-confirm. Do not leave the gate unilaterally.

## Sub-modes

`/sdd-impl` always works on a Django + htmx project. There are two sub-modes, decided by what's on disk:

- **Setup mode** — PROJECT.md exists but the project hasn't been built yet (no `manage.py`, no `docker-compose.yml`). Always Phase 1. The skill follows the recipe in `./tech-stack.md` (the `## Phase 1 recipe` section).
- **Feature mode** — the project already exists and at least one phase is done. The skill implements the tasks of the current phase (new views / models / forms / templates / tests).

Both sub-modes share a common tail: tests + 100% coverage → verification → regression → `simplify` → `security-review` → final verification → commit.

## Common preamble (every run)

1. **PROJECT.md present?** If not, say in Russian: «Сначала запусти `/sdd-idea`, чтобы появился план. `/sdd-impl` реализует фазы по готовому `PROJECT.md`.» Then exit.
2. **Parse the stack.** Find the `## Стек` section in PROJECT.md. Confirm `name: django-htmx`. If the section is missing or names a different stack, say in Russian: «В `PROJECT.md` нет секции `## Стек` или указан незнакомый стек. Похоже, план из старой версии SDD. Запусти `/sdd-idea` с опцией «Начать заново», чтобы обновить план.» Then exit.
3. **Recipe present? Read it cold.** Confirm `./tech-stack.md` exists in cwd. If missing, say in Russian: «В проекте нет `tech-stack.md` — рецепт стека, по которому я собираю фазы. Похоже, план создан старой версией SDD. Запусти `/sdd-idea` с опцией «Начать заново» — план и рецепт обновятся вместе.» Then exit. Otherwise, **read `./tech-stack.md` in full into context now**, even if you remember it from a previous run. The recipe is the contract; deviations creep in when you work from a cached memory of «the recipe» instead of the file actually on disk.
4. **Status header.** Find the first phase with any unchecked `- [ ]` task. Print in Russian:

        <Project name>
        Стек: Django + htmx
        Сделано: <N>/<total> фаз
        Следующая: Фаза <K> — <title>

5. **All phases done?** Congratulate the user (Russian) and suggest `/sdd-feature` for extensions.
6. **Dirty git (feature mode).** If `git status --porcelain` is non-empty, `AskUserQuestion`:
   - Label «Продолжить с первой незакрытой задачи» → leave changes as-is, continue.
   - Label «Откатить изменения и начать фазу заново» → run `git checkout -- .` (only after explicit confirmation), then continue.
7. **Doctor — setup mode only.** If this is setup mode (no project on disk yet — see detection above), run `"$HOME/.claude/skills/sdd-impl/scripts/sdd-doctor.sh"` now. Look at the last line of stdout:
   - `SDD_DOCTOR: ok` or `SDD_DOCTOR: warnings=<N>` → continue.
   - `SDD_DOCTOR: blockers=<N>` → `AskUserQuestion` (one question, Russian, informal "ты"): «Доктор нашёл, что для сборки не хватает нескольких инструментов. Попробовать поставить их автоматически? На macOS через Homebrew (если он есть), иначе — откроется системный диалог установки. Может попросить sudo-пароль.»
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

Follow the recipe in `./tech-stack.md` (the `## Phase 1 recipe` section) literally:

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

        Этот проект создан через SDD.

        - `PROJECT.md` — что это за проект, как работает, план по фазам.
        - `tech-stack.md` — рецепт стека (Docker, Django, тесты, htmx).
          `/sdd-impl` читает его, когда собирает фазы. Руками обычно
          менять не нужно.

        Кратко:
        - Запуск: `docker compose up -d --build`
        - Тесты: см. раздел «How to test» в `tech-stack.md`.
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
4. **Write unit tests alongside the code.** File layout and test framework come from `./tech-stack.md` (`## How to test` section) — follow that exactly. Typical location: `core/tests/test_<feature>.py`.
5. **Migrations.** If models changed, follow the migrate-dev-check sequence in `./tech-stack.md` (`## How to test` → migrations subsection). `migrate --check` must succeed before commit.
6. **htmx patterns.** Follow the pattern documented in `./tech-stack.md` (`## How to test` → htmx pattern subsection). Every list/form view has full-page + fragment branches based on `request.htmx`.

Then proceed to the common tail.

## Common tail (both sub-modes)

### 1. Tests and coverage — first pass

Run the test command from `./tech-stack.md` (`## How to test` section) literally. Typical pattern:

    docker compose exec -T app coverage run --source='.' manage.py test
    docker compose exec -T app coverage report --fail-under=100 --include='core/*.py' --omit='core/migrations/*,core/tests/*,core/apps.py,core/admin.py'

If tests fail, fix until green.

If coverage is below 100% on included paths, add the missing tests. Up to 3 attempts; after three, `AskUserQuestion` in Russian:
- Label «Попробовать с другой стороны» — one more approach.
- Label «Закрыть фазу с пометкой ⚠» — mark the problematic file in `PROJECT.md` and move on.
- Label «Стоп» — exit; the user will investigate.

### 2. Verification — two passes

Bring up the app:

    docker compose up -d --build

Wait 15 seconds, confirm `GET /` returns 200.

**Pass 1 — `curl` smoke.** Run this phase's checkpoint from `PROJECT.md` as HTTP request(s) + a content assertion (look for a specific substring in the HTML/JSON). Use `curl` or a short in-container Python script. This catches the dumb stuff fast: routes wired, templates rendering, forms accepting POSTs, redirects following.

**Pass 2 — `agent-browser` user flow.** After curl is green, invoke `agent-browser` via the `Skill` tool to emulate a real user. Pass:
- The base URL: `http://localhost:<port>` (use the actual `SDD_PORT` from `.env` if set, else `5000`).
- The current phase's checkpoint, expressed as a click-by-click flow («открой /, нажми «Зарегистрироваться», заполни форму X, отправь, проверь, что попал на /me с приветствием»). The `Проверка:` line in `PROJECT.md` is already in this human form — pass it almost verbatim.
- A short list of regression flows from prior phases — same as for curl regression, but expressed as user actions.

The browser-driven check catches what `curl` misses: htmx fragments swapping correctly, the dark theme actually applied, JavaScript executing, forms accepting input through real DOM events, redirects following from the user's perspective, visible errors that 200-OK responses can hide.

If `agent-browser` reports a failure, fix the issue and restart from step 1 (tests + coverage). If `agent-browser` is unavailable in this environment, fall back to extending the `curl` checks to cover what you would have asked the browser to verify (form POSTs, follow-redirects, htmx fragment endpoints) and note the fallback in the user-facing report.

**Regression:** run every previous phase's checkpoint — both passes — before declaring the phase verified. A new model migration that breaks an old view, a settings tweak that 500s the home page, a CSS rename that hides a button — those land here, not in the new phase's tests. If any prior phase fails, stop and surface to the user.

### 3. `simplify` on the diff

**Setup mode:** skip. Phase 1 is recipe-verbatim — the authored Python is roughly thirty lines (one `home` view, one-route urls.py, two test methods), and the templates are a fixed `base.html` plus whatever `frontend-design` produced for `home.html`. Spinning up three parallel review subagents over recipe-mandated code costs more than it pays. Do a quick inline self-check on the home template instead: every `{% extends %}` / `{% block %}` is balanced, no broken Django tags, project name renders.

**Feature mode:** invoke `simplify` via the `Skill` tool. Context: "Here is the list of files I changed in this phase: `<list>`. The phase goal from PROJECT.md is: `<goal>`. The stack is Django + htmx. Walk through and remove anything unnecessary."

If `simplify` modified any file, return to step 1 (tests + coverage) and step 2 (verification). Once green again, continue.

### 4. `security-review` on the diff

The bundled `security-review` skill diffs against `origin/HEAD`, which fails on local-only repos with `fatal: ambiguous argument 'origin/HEAD...'`. SDD projects don't have a remote until **Phase 8 (deploy)**. So:

**No remote yet (`git remote -v` empty):** skip the skill. Do a fast inline scan of the staged diff:
- Any new file (outside the recipe-mandated dev fallbacks in `docker-compose.yml` / `.env.example`) contains plaintext credentials, API tokens, or secret-looking strings?
- Any new template renders user input through `|safe` / `mark_safe` / `{% autoescape off %}`?
- Any new view touches `cursor.execute` directly with f-string interpolation?
- Any new view touches `redirect(request.GET[...])` or similar open-redirect patterns?
- Any new auth-decorated view forgets `@login_required` / `LoginRequiredMixin`?

If any of those fire, fix or flag. If clean, mention in the user-facing report: «security-review подключится с Phase 8, когда появится remote — до тех пор делаю быструю инлайновую проверку».

**Remote configured:** invoke `security-review` via the `Skill` tool with the Django + htmx-appropriate concerns:
- SQL injection (parameterize via the ORM).
- XSS in templates (autoescape is on by default).
- CSRF (htmx wired via `django_htmx`).
- Auth bypass.
- Secrets in commits.

Auto-apply only low-risk fixes (XSS fix, parameterization, removing a stray secret). Anything that changes behavior — `AskUserQuestion` before applying. Never change architecture or add dependencies beyond what the phase requires.

If anything was applied (in either branch), return to steps 1 and 2.

### 5. Self-review

Skim the diff:
- Broken imports?
- Empty / obviously-template tests (ones that pass no matter what)?
- Missing parts of the phase's task list?

After `simplify` + `security-review` there's rarely anything left, but check. Fix anything clearly broken. For behavior changes, `AskUserQuestion`.

### 6. Commit

**Setup mode:** the recipe's `.gitignore` is comprehensive (excludes `db.sqlite3`, `.env`, `__pycache__`, `.coverage`, `staticfiles/`), so `git add -A` is safe and saves enumerating ~25 starter files by name. Use it.

    git add -A
    git commit -m "phase 1: <phase title from PROJECT.md>"

**Feature mode:** stage by explicit path — the working tree may contain stray dev artifacts (an editor's swap file, a half-finished scratch script) that aren't worth committing. List the files this phase actually touched.

    git add path/one path/two ...
    git commit -m "phase <N>: <phase title from PROJECT.md>"

In both modes, print the short SHA via `git log -1 --format=%h`.

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
- The recipe lives in `./tech-stack.md` (project-local). Read it whenever you need scaffolding, test commands, or htmx details. `PROJECT.md` holds the spec and the phase plan — it's not the recipe.
