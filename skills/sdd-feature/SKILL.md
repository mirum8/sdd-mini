---
name: sdd-feature
description: >
  Extend an existing SDD project with a new feature. Interviews the user
  about the feature (2–3 turns), then appends new phases to PROJECT.md.
  The 100% coverage rule still applies to each new phase. **Only runs
  when the user explicitly invokes `/sdd-feature`.** Do NOT auto-invoke
  on phrases like "add a feature", "new feature", "extend", "добавь
  фичу", "хочу добавить", "расширь", etc. — those phrases alone are not
  enough; wait for the explicit slash command. Does NOT write code —
  only extends the plan. After this, the user runs /sdd-impl to build
  the new phases.
---

# sdd-feature — append new phases to an existing plan

Extends an existing SDD project with a new feature: short interview to understand what we're adding, then write new phases into `PROJECT.md`. **No code is written.** After this, the user runs `/sdd-impl`, which builds the new phases the same way it built the original ones.

## Why this is a separate skill (not just `/sdd-idea` again)

`/sdd-idea` is from scratch — there's no project yet. `/sdd-feature` is for a project that already lives and needs to be extended without breaking what's done. Two nuances:
- Never touch completed phases in `PROJECT.md` — they correspond to real code already in git.
- Consider real code, not just the plan: the new feature may conflict with existing models / views, and those fixes must become tasks in the new phases.

## Steps

### 1. Read the current state

- `PROJECT.md` — spec + stack recipe + phase list with checkboxes.
- If missing, print in Russian:
  > Похоже, это не SDD-проект — нет `PROJECT.md`. `/sdd-feature` расширяет существующие проекты. Если начинаешь с нуля — `/sdd-idea`.
  Then stop.
- **Parse the stack** from PROJECT.md's `## Стек` section — read `name:` and `impl_mode:`. Use the stack name to decide which files to read as "real code":
  - `django-htmx`: `manage.py`, `<slug>/settings.py`, `<slug>/urls.py`, `core/models.py`, `core/views.py`, `core/urls.py`, `core/admin.py`, filenames in `templates/core/` and `core/tests/`.
  - `nextjs`: `package.json`, `prisma/schema.prisma`, `src/app/` tree, `src/lib/` utilities, filenames in `src/app/**/*.test.*`.
  - `fastapi-htmx`: `app/main.py`, `app/models.py`, `app/database.py`, filenames in `app/templates/` and `tests/`.
  - Handoff stacks: read whatever the recipe in PROJECT.md's `### Структура проекта` section lists as the project's main folders.
- Goal: know what's **actually** in the app, not just what was planned.
- Parse `PROJECT.md` into three groups:
  - **Completed phases:** all tasks `- [x]`.
  - **In-progress phase:** mix of checked and unchecked tasks.
  - **Future phases:** all unchecked.

### 2. Print a status header

Show the user you understand the current state. Russian:

    <Project name>
    Сейчас в приложении: <1–2 lines describing what's already built, read from code>
    В плане: <N> фаз всего, <M> завершены, <K> в работе, <L> ещё не начаты.

### 3. Interview — 2–3 `AskUserQuestion` turns

Shorter than `/sdd-idea` because stack, audience, and core decisions are already made. Focus on:

- **What exactly.** Describe the user action and expected result. What concrete screens/steps appear?
- **Where it lives.** New page, addition to an existing one, or background work with no UI?
- **New data.** New model? New field on an existing model? Need a migration?
- **Interaction with existing features.** Does this change any current behavior? (If yes, flag it early — those changes go as tasks in the first new phase.)
- **MVP bounds for this feature.** What's the minimum to call it "done"?

Use the code context: propose answer options that cite actual existing models/pages. "Add a `category` field to the existing `Recipe` model?" is far more useful than "new model or new field?".

### 4. Conflicts and unfinished phases

Before writing the plan, handle two edges:

#### a) Unfinished or in-progress phases

If present, `AskUserQuestion` with three options:

1. Label «Добавить после всех существующих фаз» (default) — new phases continue the list. Unfinished phases stay where they are. Safest.
2. Label «Доделаю их потом, новые — следующими» — new phases go right after the last completed phase; unfinished phases slide down and are renumbered. Explain in the message that the numbering of "future" tasks will change.
3. Label «Эти незавершённые уже неактуальны, замени их» — delete unfinished phases and put new ones in their place. Re-confirm — this is destructive for the plan (not for code, but still).

#### b) Conflicts with existing code

If the new feature requires changing existing models / views / templates, those changes **must** appear in the first new phase **as explicit tasks**. Example:

- "Добавить поле `category` в модель `Recipe`"
- "Добавить `category` в `RecipeForm`"
- "Обновить `recipe_list.html`, чтобы показывать категорию"
- `makemigrations` + `migrate` as part of the phase.

Put structural changes at the *start* of the first new phase so the app stays runnable when `/sdd-impl` applies them.

### 5. Backup and write

- Copy `PROJECT.md` → `PROJECT.v<N>.md` (N = next free integer).
- Rewrite `PROJECT.md`:
  - Completed phases — **verbatim**, do not touch a single checkbox.
  - Add a separator comment before the new phases:

        ---
        <!-- Фича «<feature name>» — добавлена <today's date YYYY-MM-DD> -->

  - New phases begin at the next number. Count:
    - **Small feature** (a filter, a new field, one page without data): 1 phase.
    - **Medium** (new page with its own data): 2 phases.
    - **Large** (a whole subsystem — notifications, roles, export): 3–4 phases.
  - Each new phase follows the same shape as `/sdd-idea`: goal, effort (Low/Medium/High), `- [ ]` tasks, concrete checkpoint, "Тесты Фазы N" section.
  - Update the spec sections at the top of `PROJECT.md` if the feature really changes the picture (What This Is, How It Works, Data). Add — yes. Remove descriptions of already-built features — no.
  - If there are unresolved questions, add them under "Открытые вопросы".

### 6. Report

In Russian:

    ✓ Добавил фичу «<feature name>» в план.

    Новые фазы:
      Фаза <N+1>: <заголовок> — <one-line goal>
      Фаза <N+2>: <заголовок> — <one-line goal>   ← if any
      (…)

    Бэкап старого плана: PROJECT.v<N>.md

    Запусти /sdd-impl — построю первую из новых фаз.

Then `AskUserQuestion`:
- Label «Начать строить сейчас» → tell the user to run `/sdd-impl` (skills don't invoke each other).
- Label «Подправить план» → return to Step 3 or 4, focused on what the user wants changed.
- Label «Готово, потом» → exit.

## Rules

- **Completed phases are sacred.** Their checkboxes represent real code in git. Rewriting them is lying to ourselves.
- **Do not remove descriptions of already-built features** from the spec at the top of `PROJECT.md`.
- **Always back up before rewriting** `PROJECT.md`.
- **Do not write code.** That's `/sdd-impl`'s job.
- **Do not switch the stack.** The chosen stack lives in `PROJECT.md`'s `## Стек / name:` — new phases must stay on it. If a feature genuinely requires a different stack (e.g. the user now wants a mobile client for a Django web app), that's a *new* SDD project, not a feature. Adding a new dependency within the current stack is fine, but treat it as a specific task in the first new phase and explain **why** in the phase description.
- **Stay inside the stack's «Чего не тащить» list.** PROJECT.md's `## Стек / ### Чего не тащить` enumerates what the original plan deliberately avoided. A new feature doesn't un-avoid those — e.g. don't introduce React into a Django+htmx project because "this new page is interactive".
- **Short interview.** If you're asking a 6th question, you're overcomplicating. Cap at 3–4 turns. The project exists; most decisions are already made.
- **Every new task is verifiable.** Not "improve UX" — but "add a Share button to the recipe card that copies a link to the clipboard". 100% coverage on `/sdd-impl`'s side only works with concrete tasks.
