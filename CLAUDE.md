# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** a web application. It's a distribution repo for five Claude Code skills (`sdd-idea`, `sdd-impl`, `sdd-undo`, `sdd-feature`, `sdd-change`). `sdd-impl` bundles `scripts/sdd-doctor.sh`; `sdd-idea` bundles `references/django-htmx.md` (the only stack recipe). `install.sh` copies the whole `skills/` tree into `~/.claude/skills/`. All "code" here is Markdown (SKILL.md files + the one reference) and Bash.

When users run the skills, they generate **target Django + htmx web apps**. SDD only ships one stack — see "Stack" below. Don't confuse this repo's stack (shell + markdown) with what the skills produce (Django + htmx web apps in Docker).

## Commands

```bash
./install.sh                                       # copy skills into ~/.claude/skills/
~/.claude/skills/sdd-impl/scripts/sdd-doctor.sh    # verify env (exits 0=ok, 1=blockers, 2=warnings)
bash -n skills/sdd-impl/scripts/sdd-doctor.sh      # syntax-check the doctor script
bash -n install.sh                                 # syntax-check the installer
```

There is no test suite, linter, or build. Validation is manual: run `install.sh`, then exercise a skill in a scratch directory.

## Workflow when editing skills

**Always load `/skill-creator` before touching anything under `skills/`.** That includes `SKILL.md` bodies, frontmatter (`description` affects triggering), `references/django-htmx.md`, and `scripts/*`. The skill-creator provides the evaluation loop (snapshot old version → test cases → with-skill vs baseline → iterate) and the description-optimization tooling — skipping it means editing prompts blind. Load it at the start of the session, not only at commit time.

This applies to every change, big or small: tweaking a description, fixing a step in a SKILL.md, editing the recipe. Load `/skill-creator`, then make the change.

## Architecture

### Skills follow the Claude Code skill convention

```
skills/<name>/
├── SKILL.md              # required — YAML frontmatter + instructions
├── references/           # optional — markdown docs loaded on demand
└── scripts/              # optional — executable code
```

Each `SKILL.md` is an instruction file Claude Code loads when triggered. The YAML frontmatter (`name`, `description`) controls trigger matching — the description is where trigger phrases (EN + RU) go, and Claude Code uses it to decide when to invoke the skill. The Markdown body is the procedure the skill executes. Reference and script files live beside SKILL.md and are read or executed only when the skill needs them.

### The five skills form a pipeline

- `sdd-idea` — interview → confirms the idea is a web app (or reframes a mobile/desktop/CLI idea as a web MVP) → writes `PROJECT.md` (spec + Django + htmx recipe inlined + phased plan). Writes **no code**.
- `sdd-impl` — reads `PROJECT.md`, builds the next unchecked phase end-to-end. Phase 1 sets up the Docker container, Django project, home page, and tests; later phases add features. Commits `phase N: <title>`.
- `sdd-undo` — `git revert` of the last `phase N: ...` commit plus any trailing review commits. Never `reset`, never force-push.
- `sdd-feature` — interview → **appends** new phases to an existing `PROJECT.md`. Writes **no code**.
- `sdd-change` — interview → **mutates** an existing `PROJECT.md`: rewrites spec text in place, rewrites an unimplemented phase in place, or (when the target behavior is already shipped) appends a migration phase. Writes **no code**. Completed `- [x]` phases are never rewritten — they're the record of what's in git.

`sdd-feature` and `sdd-change` are split on purpose: feature = append new functionality; change = mutate the plan or re-do existing behavior. The fork on "is this already built?" is what makes change a separate skill — its answer drives whether we edit the plan in place or append a migration phase.

Skills do not invoke each other. The transition between them is the user re-running the next command.

### Stack

SDD ships exactly one stack: **Django 5 + htmx + SQLite + Pico.css in Docker**. The full recipe lives in `skills/sdd-idea/references/django-htmx.md`. Every PROJECT.md inlines this recipe so `/sdd-impl` and `/sdd-feature` never have to open the reference file at runtime.

The `references/` directory exists for modularity (the recipe is large and benefits from being a separate file) but currently holds exactly one file. Don't add more stacks without a separate decision — SDD targets vibe coders building web apps and the multi-stack abstraction was removed because it was carrying its weight only for one or two stacks anyway.

If a user's idea isn't naturally a web app, `/sdd-idea` tries to reframe it (mobile → mobile-friendly web + later PWA wrap; desktop → web app run locally + later Tauri wrap). If the reframe doesn't fit, the skill exits with a plain-Russian message that SDD can't help with that idea.

### Doctor contract

`skills/sdd-impl/scripts/sdd-doctor.sh` is a one-time environment-readiness check. It runs:
- at the end of `install.sh` (confirms the install worked);
- once in `/sdd-impl` **setup mode only** (first Phase 1 of a project);
- on demand if the user runs it directly for diagnosis.

It does **not** run on every `/sdd-impl` phase, in `/sdd-feature`, or in `/sdd-undo`. Those skills either don't touch the environment (`/sdd-feature` writes markdown; `/sdd-undo` does a git revert) or surface real errors from the real commands (`docker compose` failures) rather than preflight-checking every time. If a later invocation actually hits an environment issue, let the real command fail with its real message, then point the user at the doctor as a diagnostic.

**Optional `--install` mode.** The doctor also accepts `--install`: run checks, attempt macOS fixes (Homebrew for git / Docker / compose, `open -a Docker` for the daemon), re-run checks, emit the marker based on the post-install state. Only `/sdd-impl` setup mode calls it, and only after explicit user consent via `AskUserQuestion`. Linux `--install` is a no-op with an info line — auto-fix is macOS-only for now. No-flag behavior is unchanged, so `install.sh`'s verification still works exactly as before.

**Preserve these invariants so the parse-on-install still works:**
- Exit codes: `0` all green, `1` blockers, `2` warnings only.
- Last stdout line is exactly `SDD_DOCTOR: ok` | `SDD_DOCTOR: blockers=<N>` | `SDD_DOCTOR: warnings=<N>`. The install (and any skill that does invoke it) greps for this — don't break the format.
- Frontend-design plugin is detected by grepping `"frontend-design@"` in `$SDD_PLUGINS_JSON` (default `~/.claude/plugins/installed_plugins.json`).
- Port is configurable via `SDD_PORT` (default `5000`).
- The doctor checks Docker + git + disk + port + plugin. That's the universal baseline for SDD's one stack.

### Installer invariants

- `install.sh` overwrites existing SDD skill directories in place (`rm -rf` + `cp -R`). No backups. Local edits to `~/.claude/skills/sdd-*` will be lost on re-run — that's intentional, skills are sourced from this repo. Never write to `~/.claude/skills/sdd-*.bak` or similar, since Claude Code would register the suffixed copy as a separate skill.
- OS gate: refuses anything other than `Darwin` or `Linux`. Windows/WSL is not supported on purpose.
- All five skill names are hard-coded in the install loop: `sdd-idea sdd-impl sdd-undo sdd-feature sdd-change`.
- Legacy cleanup: if an old `~/.claude/scripts/sdd-doctor.sh` exists from earlier installs, delete it so stale copies don't get called by accident.

### Language conventions

- **Internal files are English.** SKILL.md bodies, the reference, installer comments, doctor comments — all English.
- **User-facing output is Russian, informal "ты".** Messages the skill prints to chat, everything written into the user's `PROJECT.md`, and the short `CLAUDE.md` pointer written into the user's generated project.
- When editing a SKILL.md, keep the quoted Russian message templates Russian; don't "localize" them to English.

## Cross-cutting rules (from user's global CLAUDE.md)

- Don't add comments or javadocs unless asked.
- Don't add extra logging.
- When reporting a bug, start by writing a test that reproduces it — don't jump to a fix.
- Don't over-engineer.
