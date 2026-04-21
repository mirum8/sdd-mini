---
name: sdd-idea
description: >
  Planning-only skill for SDD projects. Turns a rough idea into a single
  PROJECT.md that holds both the spec AND the phased implementation plan,
  with the right stack picked for the idea (web, SPA, mobile, desktop,
  CLI, game). Trigger on "/sdd-idea", "I have an idea", "let's plan an
  app", "help me spec this", "new project", as well as Russian variants:
  "хочу сделать приложение", "давай спроектируем", "накидаем план",
  "новый проект", "спроектируй", "составь план". Invoke this skill (not
  a plain text reply) whenever the user is clearly scoping a new project
  and no PROJECT.md exists yet. Do NOT write code, do NOT run the doctor
  script, do NOT create scaffolds — the only output is PROJECT.md. Hands
  off to /sdd-impl for actual building.
---

# sdd-idea — idea → PROJECT.md

Turn a rough idea into `PROJECT.md` — a single file holding the spec, the stack recipe, and the phased plan. **This skill writes no code, does not run the doctor, does not scaffold anything.** Only `PROJECT.md` (and versioned `PROJECT.v<N>.md` backups on rewrite).

The goal is that the user leaves with a concrete plan, not a vague direction. A weak plan produces a bad project; a solid plan lets `/sdd-impl` move phase-to-phase without constantly re-asking the user what they want.

## Stack is SDD's choice, not a discussion

SDD never asks the user to pick the stack — that's a well-known source of bikeshedding and the opposite of what a vibe coder needs. Instead, SDD reads the user's idea, picks the best-fit stack from `references/*.md` (this skill's private recipe library), and commits to it. If the idea doesn't fit the default web stack, SDD picks a different stack — it never refuses.

The stack library in `references/`:

| File | Stack | `impl_mode` | Fit |
|---|---|---|---|
| `django-htmx.md` | Django 5 + htmx + SQLite + Pico.css + Docker | scaffold | Default web app. Trackers, managers, small internal tools |
| `nextjs.md` | Next.js 15 + Prisma + SQLite + Tailwind + Docker | scaffold | SPA-grade interactivity: drag-and-drop, live updates |
| `flutter.md` | Flutter + Riverpod + sqflite | handoff | Mobile iOS/Android |
| `tauri.md` | Tauri 2 + SvelteKit + SQLite | handoff | Cross-platform desktop |
| `cli-python.md` | Python + Typer + Rich + pytest | handoff | Terminal utilities |
| `fastapi-htmx.md` | FastAPI + htmx + SQLite + SQLAlchemy + Docker | handoff | Lightweight server-rendered web |
| `game-web.md` | Phaser 3 + Vite + TypeScript + Vitest | handoff | Browser 2D games |

`impl_mode: scaffold` — `/sdd-impl` automates Phase 1 end-to-end.
`impl_mode: handoff` — `/sdd-impl` hands off to Claude Code with the full recipe already in PROJECT.md.

Either way the user gets a complete, self-contained `PROJECT.md`.

## Audience and tone

The user is a vibe coder: building an app for themselves or a small group, not a professional developer. Speak Russian informally ("ты", not "вы"), friendly, minimal jargon. Short sentences. Anglicisms like "стек", "фича", "деплой" are fine when they read natural.

All user-facing output and everything written into `PROJECT.md` is Russian. Code and identifiers stay English.

## Step 1 — existing PROJECT.md

First check: is there a `PROJECT.md` in cwd already?

- **If present:** read it, then `AskUserQuestion` with three options:
  1. Label «Продолжить проект» → tell the user to run `/sdd-impl`, exit without rewriting anything.
  2. Label «Расширить фичей» → tell the user to run `/sdd-feature`, exit.
  3. Label «Начать заново» → back up `PROJECT.md` → `PROJECT.v<N>.md` (N = next free integer), then continue to Step 2.
- **If absent:** go to Step 2.

## Step 2 — the interview (8–12 turns)

Ask questions through `AskUserQuestion`. 1–3 related questions per turn, each with 2–4 concrete answer options grounded in what the user has said so far.

Goal: build a clear picture of *what* we're building and *for whom*. **Never ask about the stack.**

Cover the topics below. Don't skip without good reason — if a topic is clearly inapplicable (e.g. accounts for a personal single-user tool), skip silently and move on.

1. **The problem.** What's broken or missing? Why does it matter? What triggered this idea?
2. **The people.** Who uses it? How tech-savvy? Solo or multiple? How will they find the app?
3. **Core scenario.** Walk through a typical session step-by-step.
4. **Data.** What gets stored? How are records related? Rough shape of each record.
5. **Key actions.** Add / view / edit / delete / search / filter / share — which matter, which don't.
6. **Edge cases.** What if input is garbage? Storage fills up? Two users act at once (if multi-user)?
7. **Look and feel.** What apps/sites is this like in mood? Playful / minimal / data-dense?
8. **Accounts & access.** Login needed? Multiple users? Roles? Public parts vs private?
9. **Integrations.** External APIs? Import/export? Email/notifications?
10. **Priorities.** If you could only ship three features, which? Which are dreams for later?

Conversation rules:
- When the user gets animated on a topic, drill deeper.
- When they answer tersely or deflect, move on.
- Cite their earlier answers ("you said it's just for your family — so login probably isn't critical?").
- Don't introduce jargon the user hasn't used themselves.

## Step 3 — stack selection

Once you understand the idea, pick the best-fit stack. List every file in this skill's `references/` directory, read the frontmatter and "When to pick this stack" section of each. Match the user's idea to exactly one reference.

Heuristics:
- **Web app (CRUD, tracker, manager, blog, internal tool) → `django-htmx`.** This is the default. When in doubt, pick this.
- **SPA interactivity: drag-and-drop between columns, inline-edit tables, live collab, real-time feel → `nextjs`.**
- **Mobile, iOS/Android, offline-first, uses camera/GPS/push → `flutter`.**
- **Desktop, offline, tray icon, reads/writes local files → `tauri`.**
- **CLI, terminal utility, no UI → `cli-python`.**
- **Single-screen lightweight web tool, no admin, no auth → `fastapi-htmx`.** If the user talks about an admin or multiple user-editable models, prefer `django-htmx`.
- **2D browser game → `game-web`.**

Commit to the pick — do not ask the user "which stack?". Do not negotiate. If you picked wrong, the user can run `/sdd-idea` again with the «Начать заново» option.

Log one short Russian sentence telling the user what stack was picked and one sentence why. Example:
> Стек: Django + htmx. Это обычное веб-приложение — трекер с формами и списками; Django закроет админку и данные без лишней возни.

Then go to Step 4.

## Step 4 — propose the MVP

Formulate the **minimum version that still solves the core problem**. Not "everything we discussed" — "without which it wouldn't work at all".

Use `AskUserQuestion` to confirm. Example phrasing: «Вот что предлагаю собрать первым — [2–4 lines]. Ок или что-то убрать/добавить?» This is the single approval gate before writing the plan.

## Step 5 — write PROJECT.md

Inline the chosen reference's recipe into PROJECT.md so the file is self-contained. `/sdd-impl` and `/sdd-feature` read only PROJECT.md — they must never open a reference file at runtime.

Structure — Russian headings, Russian prose inside each section (translate from the English reference as needed), language-neutral code blocks verbatim. Include only sections that are relevant; skip a section if it doesn't apply (e.g. `## Аккаунты и доступ` for a personal single-user tool).

    # <Название проекта>

    ## Что это
    2–3 sentences: what it does, for whom, why it matters.

    ## Как это работает
    Main user flows — concrete, step by step, not abstract.

    ## Данные
    What gets stored, how it's linked (only if relevant).

    ## Аккаунты и доступ
    (only if login matters)

    ## Интеграции
    (only if external APIs/services exist)

    ## Граничные случаи
    What happens when things go wrong.

    ## Открытые вопросы
    Things not yet decided.

    ## Стек
    **name:** <stack id from reference frontmatter>
    **impl_mode:** <scaffold | handoff>
    **summary:** <Russian one-liner, translated from the reference `summary`>

    ### Технологии (минимум для MVP)
    <list, translated from the reference "Minimal MVP tech" section>

    ### Структура проекта (Фаза 1)
    <full Phase 1 recipe — code blocks verbatim, prose translated to Russian>

    ### Как тестировать
    <translated from reference "How to test">

    ### Чего не тащить
    <translated from reference "Do not bring in">

    ## Фазы

    ### Фаза 1 — Настройка проекта
    **Цель:** <one Russian sentence>
    **Усилие:** Low

    - [ ] <tasks pulled from the chosen reference's Phase 1 recipe, translated to Russian>
    - [ ] ...
    - [ ] Проверка: <concrete checkpoint — e.g. «http://localhost:5000 открывается и показывает <Название проекта>»>

    **Тесты Фазы 1:** <derived from the reference's test guidance>

    ### Фаза 2 — <Core scenario title>
    **Цель:** ...
    **Усилие:** Medium

    - [ ] ...

    **Проверка:** ...
    **Тесты Фазы 2:** ...

    (and so on)

    ### Фаза N — Полировка и деплой
    **Цель:** приложение доступно по публичному URL.
    **Усилие:** Low

    - [ ] <deploy tasks — pick target appropriate for the stack>
    - [ ] Проверка: приложение открывается по публичной ссылке.

    **Тесты Фазы N:** все предыдущие чекпоинты ещё зелёные.

All prose inside `PROJECT.md` is Russian. Code blocks (Dockerfile, package.json, etc.) stay as-is. `## Стек` subsection titles (`Технологии`, `Структура проекта`, `Как тестировать`, `Чего не тащить`) are always Russian.

### Phase construction rules

- **Target size:** 4–7 phases for a typical idea. Up to 8 when there are many features.
- **Phase 1 is fixed by the chosen stack reference.** Translate its "Phase 1 recipe" steps into tasks. For `scaffold` stacks this is a boot-the-container phase; for `handoff` stacks it's a concrete "initialize the framework, make the first test pass" phase.
- **Phase 2 is the core loop.** One end-to-end slice through the most important action. Recipe tracker: "add recipe → see in list". Budget tracker: "enter expense → see balance". Everything else comes later.
- **Vertical slices, not horizontal layers.** Each phase touches the whole stack (model + view + template + tests) for one feature. Do not do "all models first, then all views".
- **Each phase ends in a runnable state.** No "half a feature now, half next time".
- **Last phase is always polish + deploy.** Stack-specific target: Django/Next.js/FastAPI → Render.com or Fly.io; Flutter → publish on internal track + TestFlight; Tauri → build artifacts + GitHub Releases; Phaser → deploy to static hosting; CLI → publish to PyPI (optional).
- **Checkpoints are observable, not "it works".** Not "user sees the list" but "open /recipes, click Add, type 'Borscht', submit — should appear on home page".
- **Effort:** Low / Medium / High. Not hours — vibe coders can't calibrate hours.
- **Tests are mandatory.** Every phase has a "Тесты Фазы N" section listing what must be covered by unit tests. 100% coverage on changed files (framework-appropriate definition, pulled from the reference) is enforced by `/sdd-impl` for `scaffold` stacks; for `handoff` stacks it's a rule documented in PROJECT.md for Claude Code to follow manually.

### Coverage self-check

After writing `PROJECT.md`, mentally walk each MVP item and each "add later" item: **every one must be a task in at least one phase.** If something isn't covered, add a task — don't save a plan with a hole.

## Step 6 — offer next steps

Show a summary: chosen stack, phase titles, and one-line checkpoints. Then `AskUserQuestion` with three options:

1. Label «Продолжим интервью» → return to Step 2, focused on what the user wants to deepen ("the data model", "feature X", "edge cases"). After the follow-up, rewrite `PROJECT.md` (old version goes to `PROJECT.v<N>.md`).
2. Label «Поменять план» → no re-interview; user says what to change (split a phase, merge two, reprioritize, move something to "later"), you apply it, rewrite `PROJECT.md` with backup.
3. Label «Поехали, строим!» → the plan is final. Print this message to the user (adapt to stack impl_mode):

   For `scaffold` stacks:
   > Готово. План — в `PROJECT.md`. Запусти `/sdd-impl` — построю Фазу 1 и подниму приложение в браузере.

   For `handoff` stacks:
   > Готово. План — в `PROJECT.md`, там же весь рецепт стека. Запусти `/sdd-impl` — скажу, что дальше строить вручную (SDD для этого стека scaffold не автоматизирует, но рецепт уже у тебя).

Options 1 and 2 can be chosen as many times as the user wants — versioning protects previous drafts. **Only «Поехали, строим!» hands off control.**

## What not to do

- Do not run the doctor. Environment doesn't matter at the planning stage.
- Do not create any file other than `PROJECT.md` and its `PROJECT.v<N>.md` backups.
- Do not try to do Phase 1's tasks — that's `/sdd-impl`'s job.
- Do not discuss framework, library, or hosting choices with the user. SDD picks; the user ships.
- Do not refuse an idea because it doesn't fit Django. Pick a different reference instead.
- Do not write «ТЫ ДОЛЖЕН» / "YOU MUST" in the plan — the tone is bad for vibe coders.
- Do not ask all-or-nothing questions — always give options.
- Do not draw ASCII diagrams or flowcharts in `PROJECT.md` unless the user explicitly asks.

## Example trigger prompts

> «Хочу сделать приложение для учёта книг, которые читаю. Чтобы можно было ставить
> оценку, писать короткие заметки, и видеть статистику по месяцам.»

Flow: interview → pick `django-htmx` → MVP proposal → `PROJECT.md` with ~5 phases → handoff to `/sdd-impl`.

> «Канбан для команды на 5 человек с drag-and-drop карточек между колонками.»

Flow: interview → pick `nextjs` → MVP proposal → `PROJECT.md` with ~5 phases → handoff to `/sdd-impl`.

> «iOS-приложение чтобы в зале отмечать подходы и веса.»

Flow: interview → pick `flutter` → MVP proposal → `PROJECT.md` with ~5 phases, impl_mode handoff → `/sdd-impl` will tell the user Claude Code continues from PROJECT.md manually.
