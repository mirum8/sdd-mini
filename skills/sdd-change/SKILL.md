---
name: sdd-change
description: >
  Change something in an existing SDD plan — rewrite a spec section,
  adjust tasks in an unimplemented phase, or modify already-shipped
  behavior by appending a migration phase. Interviews the user (2–3
  turns), then edits PROJECT.md. **Only runs when the user explicitly
  invokes `/sdd-change`.** Do NOT auto-invoke on phrases like "change
  the spec", "rewrite the plan", "adjust phase 3", "actually scratch
  that", "поменяй план", "измени спеку", "переделай фазу", "передумал",
  etc. — those phrases alone are not enough; wait for the explicit
  slash command. Does NOT write code — only changes the plan. After
  this, the user runs /sdd-impl if a migration phase was added or an
  unimplemented phase was edited.
---

# sdd-change — modify an existing plan

Edits an existing SDD project's `PROJECT.md` when the user wants to change something they already committed to: a spec paragraph, an unimplemented phase, or the behavior of already-shipped code. **No code is written.** The output is a rewritten `PROJECT.md` (and a `PROJECT.v<N>.md` backup).

## How this differs from `/sdd-feature`

- `/sdd-feature` **adds** new phases for net-new functionality.
- `/sdd-change` **modifies** the existing plan: rewrites spec text in place, rewrites tasks in an unimplemented phase in place, or — when the code is already shipped — appends a **migration phase** that changes the current behavior.

The split matters because the actions are opposite in spirit: feature = append; change = mutate. A vibe coder shouldn't have to know which happens when — this skill reads the state and does the right thing.

## Plan mode (mandatory first action)

The first thing this skill does is switch to plan mode. Call `EnterPlanMode` before any other step.

Inside plan mode:
- Read `PROJECT.md` and real code per the stack's file list.
- Run the 2–3 interview turns via `AskUserQuestion`.
- Classify the change (Step 4 below) — spec-only, unimplemented-phase, or migration — and compose the edit **in memory only**, without touching `PROJECT.md` yet.
- Present the full proposal (what stays, what changes, what gets appended) via `ExitPlanMode` for the user to approve.

Only after the user accepts the plan and plan mode exits do you back up `PROJECT.md` → `PROJECT.v<N>.md` and write the change.

If the user rejects the plan, revise it and call `ExitPlanMode` again with the updated proposal. Do not leave plan mode unilaterally.

## Why this is a separate skill

Completed phases correspond to real code in git. You can't "unimplement" a phase by flipping `- [x]` back to `- [ ]` — the code is still there. That means a change request has to branch on "is this already built?": if not, rewrite the plan in place; if yes, append a migration phase and let the spec describe the new intent. Squeezing that fork into `/sdd-feature` (whose job is pure appending) would make both skills muddier.

## Steps

### 1. Read the current state

- `PROJECT.md` — spec, stack recipe, phase list with checkboxes.
- If missing, print in Russian:
  > Похоже, это не SDD-проект — нет `PROJECT.md`. `/sdd-change` меняет существующий план. Если начинаешь с нуля — `/sdd-idea`.
  Then stop.
- **Confirm the stack** from PROJECT.md's `## Стек` section — `name:` should be `django-htmx` (the only stack SDD ships). Read these files as "real code": `manage.py`, `<slug>/settings.py`, `<slug>/urls.py`, `core/models.py`, `core/views.py`, `core/urls.py`, `core/admin.py`, filenames in `templates/core/` and `core/tests/`.
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

    Что именно нужно поменять?

### 3. Interview — 2–3 `AskUserQuestion` turns

Tight. The stack, audience, and architecture are already fixed. The only thing to figure out is **what changes and where it lives**.

**Turn 1 — open description.**
- «Опиши своими словами, что хочешь поменять. Это может быть описание в спеке, план будущей фазы, или поведение того, что уже работает.»

**Turn 2 — classify, with options grounded in what was said.** Offer the surfaces that actually match the request. Each option names a concrete target:
- Spec section: «Поменять описание в спеке — раздел «<section title>»».
- Unimplemented phase: «Переписать Фазу <N>: <title>».
- Already-built behavior: «Добавить фазу миграции — <one-line label>» and, in the option description, note that the completed phase stays `[x]` as a historical record and a new phase will do the migration.
- A single change can legitimately touch more than one surface — allow multi-select, or do a follow-up turn per surface.

**Turn 3 — details per surface.** Ask only what's needed to write the edit:
- **Spec:** exact new wording (or a short summary; the skill writes the prose).
- **Unimplemented phase:** new goal, new task list, new checkpoint.
- **Migration:** user-visible behaviors to change, any data migration needed, what to keep vs. drop.

If the change is tiny ("поменяй чекпоинт Фазы 3 на <X>"), one turn is enough — don't drag it out. Cap at 3–4 turns in the worst case.

Use the code context: propose options citing real models/pages/files. "Убрать поле `phone` из `LoginForm` и добавить `email`?" beats "менять модели?".

### 4. Classify and design the edit

Every change falls into one or more of three surfaces. Decide which, then compose the edit.

#### a) Spec-only edit

Sections like `## Что это`, `## Как это работает`, `## Данные`, `## Граничные случаи`, `## Аккаунты и доступ`. Rewrite in place. Keep headings intact. Don't touch phases. No migration phase needed — the spec is the north star, not executable code.

If the spec change implies code changes that aren't shipped yet, that's fine (the future phases will build to the new spec). If it implies changes to code that **is** shipped, you also need a migration phase — fall through to (c).

#### b) Unimplemented phase edit

A phase is "unimplemented" only if **every** task in it is `- [ ]`. A single `- [x]` inside a phase means at least something has been built against that plan — treat it as already-implemented and use a migration phase instead (c).

Rewrite the phase's goal, task list, and checkpoint in place. Keep the phase number. Update the title if the scope changed. Don't renumber following phases unless the change makes a later phase redundant — if it does, `AskUserQuestion` before removing or renumbering.

#### c) Migration phase (behavior already shipped)

**Never rewrite a completed phase.** Its `- [x]` checkboxes represent real code in git — editing them lies about what happened. Instead, append a new phase at the end of `## Фазы`. That phase's tasks **change** the existing code (edit models / views / templates / tests) to match the new intent.

Put structural changes at the *start* of the migration phase so the app stays runnable while `/sdd-impl` applies the tasks in order. Example tasks for "switch login from phone to email":

- "Добавить поле `email` в модель `User`, снять `unique` с `phone`"
- "`makemigrations` + `migrate` + data-migration: перенести телефоны в email, где это возможно, остальные пометить"
- "Переписать `LoginForm`: поле `email` вместо `phone`"
- "Обновить `login.html` и `test_login.py`"
- "Проверка: пользователь входит по email, старые аккаунты мигрированы."

Also update the spec at the top of `PROJECT.md` so it describes the new intended behavior. The completed phase stays as-is (it's an accurate record of what was built at the time); the spec and the migration phase together describe what the app is *becoming*.

#### d) Combinations

A real change often hits several surfaces at once — "вход по email вместо телефона" typically touches the spec (describe the new flow), the already-built code (migration phase), and sometimes an unimplemented phase that assumed the old behavior. Do all of them in the same session and present them as **one bundle** in `ExitPlanMode` so the user sees the whole change atomically.

### 5. In-progress phase (mix of `[x]` and `[ ]`)

If the change lands on a phase that's half-done, `AskUserQuestion` with three options:

1. Label «Закончу эту фазу как есть, потом миграция» (default) — treat as already-implemented: append a migration phase at the end. Safest. The half-finished phase finishes on its current plan; the migration phase changes the result afterwards.
2. Label «Откачу эту фазу, потом поменяю план» — tell the user to run `/sdd-undo` first, then re-run `/sdd-change`. Exit this skill with a note. This is right when the user wants to change the direction of the current phase itself.
3. Label «Поменять только оставшиеся задачи» — rewrite only the `- [ ]` tasks inside the phase. The `- [x]` ones stay. Only safe if the new direction doesn't contradict what's already been done. If it does, steer the user to option 1 or 2.

### 6. Stack guardrails

- **Do not switch the stack.** The chosen stack lives in `PROJECT.md`'s `## Стек / name:` — changes must stay on it. If the change genuinely requires a different stack (e.g. the user now wants a mobile app instead of a web app), that's a *new* SDD project, not a change. Tell the user to start over with `/sdd-idea` in a fresh folder — SDD has no "swap the stack" operation because it would effectively rewrite the whole project anyway.
- **Stay inside the stack's «Чего не тащить» list.** PROJECT.md's `## Стек / ### Чего не тащить` enumerates what the original plan deliberately avoided. A change doesn't un-avoid those — e.g. don't introduce React into a Django+htmx project because "now this page needs to feel live".

### 7. Backup and write

Only after `ExitPlanMode` returns approval:

- Copy `PROJECT.md` → `PROJECT.v<N>.md` (N = next free integer).
- Rewrite `PROJECT.md`:
  - **Completed phases — verbatim**, do not touch a single checkbox.
  - **Updated spec sections** — replace in place; don't reorder sections the user didn't change.
  - **Edited unimplemented phase** — replace its body in place; keep the phase number.
  - **Migration phase** — append at the bottom of `## Фазы`, numbered as the next phase. Add a separator comment before it:

        ---
        <!-- Изменение «<short label>» — внесено <today's date YYYY-MM-DD> -->

  - Migration phases follow the same shape as `/sdd-idea` / `/sdd-feature`: goal, effort (Low/Medium/High), `- [ ]` tasks, concrete checkpoint, "Тесты Фазы N" section. Put structural tasks first.
  - If the change reshapes the data model, update `## Данные` too (new field, renamed model, etc.).
  - If anything is still undecided, add a line under `## Открытые вопросы`.

### 8. Report

In Russian. Vary by which surfaces changed — only show lines for surfaces that actually got touched:

    ✓ Внёс изменения в план.

    Что поменялось:
      • Спека: раздел «<section>» — <one-line summary>
      • Фаза <N>: переписал задачи
      • Фаза <N+1>: миграция «<label>» — <one-line goal>

    Бэкап старого плана: PROJECT.v<N>.md

    Что дальше:
      <pick the line that matches what changed>
      • Появилась новая фаза — запусти /sdd-impl, построю её.
      • Переписал задачи в ещё не построенной фазе — когда дойдёшь до неё, /sdd-impl пойдёт по новому плану.
      • Поменялась только спека, код не трогаем — следующие фазы будут строиться уже под новое описание.

Then `AskUserQuestion`:
- Label «Подправить ещё раз» → back to Step 3 focused on what the user wants different.
- Label «Готово» → exit.

## Rules

- **Completed phases are sacred.** Their `- [x]` checkboxes are the only reliable record of what's actually in git. Rewriting them is lying; instead, append a migration phase and let the spec describe the new intent.
- **Never rewrite a partially-done phase** unless the user explicitly picked option 3 of Step 5. The default is "finish as-is, then migrate".
- **Always back up before rewriting** `PROJECT.md`.
- **Do not write code.** That's `/sdd-impl`'s job. Migration phases describe what code should change; `/sdd-impl` makes it happen.
- **Do not switch the stack.** See Step 6.
- **Short interview.** If you're at turn 5, you're overthinking. Cap at 3–4. Most of the project is already decided.
- **Every migration task is concrete and verifiable.** "Improve login UX" is not a task; "Заменить поле `phone` на `email` в `LoginForm`, добавить миграцию данных, переписать `test_login.py`" is. 100% coverage on `/sdd-impl`'s side only works with concrete tasks.
- **Do not invoke other skills.** The return to `/sdd-impl` is the user's next command.
