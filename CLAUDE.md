# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** a web application. It's a distribution repo for four Claude Code skills (`sdd-idea`, `sdd-impl`, `sdd-undo`, `sdd-feature`). `sdd-impl` bundles `scripts/sdd-doctor.sh`; `sdd-idea` bundles `references/*.md` (stack recipes). `install.sh` copies the whole `skills/` tree into `~/.claude/skills/`. All "code" here is Markdown (SKILL.md files + reference files) and Bash.

When users run the skills, they scaffold **target projects** in whichever stack `sdd-idea` picks for the idea. Don't confuse this repo's stack (shell + markdown) with the stacks those skills produce.

## Commands

```bash
./install.sh                                       # copy skills into ~/.claude/skills/
~/.claude/skills/sdd-impl/scripts/sdd-doctor.sh    # verify env (exits 0=ok, 1=blockers, 2=warnings)
bash -n skills/sdd-impl/scripts/sdd-doctor.sh      # syntax-check the doctor script
bash -n install.sh                                 # syntax-check the installer
```

There is no test suite, linter, or build. Validation is manual: run `install.sh`, then exercise a skill in a scratch directory.

## Architecture

### Skills follow the Claude Code skill convention

```
skills/<name>/
├── SKILL.md              # required — YAML frontmatter + instructions
├── references/           # optional — markdown docs loaded on demand
└── scripts/              # optional — executable code
```

Each `SKILL.md` is an instruction file Claude Code loads when triggered. The YAML frontmatter (`name`, `description`) controls trigger matching — the description is where trigger phrases (EN + RU) go, and Claude Code uses it to decide when to invoke the skill. The Markdown body is the procedure the skill executes. Reference and script files live beside SKILL.md and are read or executed only when the skill needs them.

### The four skills form a pipeline

- `sdd-idea` — interview → picks a stack from its own `references/*.md` → writes `PROJECT.md` (spec + stack recipe inlined + phased plan). Writes **no code**.
- `sdd-impl` — reads `PROJECT.md`, builds the next unchecked phase end-to-end. For scaffold-mode stacks (`django-htmx`, `nextjs`) it runs Phase 1 automatically; for handoff-mode stacks it prints a next-steps message and records a marker commit. Commits `phase N: <title>`.
- `sdd-undo` — `git revert` of the last `phase N: ...` commit plus any trailing review commits. Never `reset`, never force-push.
- `sdd-feature` — interview → appends new phases to an existing `PROJECT.md`. Writes **no code**.

Skills do not invoke each other. The handoff is via the user re-running the next command.

### Stack is per idea, not fixed

`sdd-idea/references/*.md` is the private recipe library — 7 stacks today (`django-htmx`, `nextjs`, `flutter`, `tauri`, `cli-python`, `fastapi-htmx`, `game-web`). Each reference has a fixed schema (frontmatter with `name`, `summary`, `impl_mode`; body sections "When to pick this stack", "Minimal MVP tech", "Phase 1 recipe", "How to test", "Do not bring in"). Adding a new stack = one new file in that folder.

`sdd-idea` picks exactly one reference per interview and **inlines** the chosen recipe into `PROJECT.md`'s `## Стек` section so PROJECT.md is self-contained. `sdd-impl` and `sdd-feature` read only PROJECT.md — they must never open a reference file at runtime.

Scaffold vs handoff is a property of the reference (`impl_mode:` frontmatter). Only `django-htmx` and `nextjs` are scaffold-automated today; everything else is handoff because the required toolchain (Rust, Android SDK, Xcode, .venv) is outside the Docker + git baseline.

### Doctor contract

`skills/sdd-impl/scripts/sdd-doctor.sh` is a one-time environment-readiness check. It runs:
- at the end of `install.sh` (confirms the install worked);
- once in `/sdd-impl` **setup mode only** (first Phase 1 of a scaffold-mode project);
- on demand if the user runs it directly for diagnosis.

It does **not** run on every `/sdd-impl` phase, in `/sdd-feature`, or in `/sdd-undo`. Those skills either don't touch the environment (`/sdd-feature` writes markdown; `/sdd-undo` does a git revert) or surface real errors from the real commands (`docker compose` failures) rather than preflight-checking every time. If a later invocation actually hits an environment issue, let the real command fail with its real message, then point the user at the doctor as a diagnostic.

**Preserve these invariants so the parse-on-install still works:**
- Exit codes: `0` all green, `1` blockers, `2` warnings only.
- Last stdout line is exactly `SDD_DOCTOR: ok` | `SDD_DOCTOR: blockers=<N>` | `SDD_DOCTOR: warnings=<N>`. The install (and any skill that does invoke it) greps for this — don't break the format.
- Frontend-design plugin is detected by grepping `"frontend-design@"` in `$SDD_PLUGINS_JSON` (default `~/.claude/plugins/installed_plugins.json`).
- Port is configurable via `SDD_PORT` (default `5000`).
- The doctor is stack-agnostic on purpose: it checks Docker + git + disk + port + plugin, and nothing about Python/Node/Flutter/etc. — each stack's own tooling requirements live in its reference recipe, not here.

### Installer invariants

- Backups go to `~/.claude/sdd-backups/<timestamp>/`, **never** inside `~/.claude/skills/`. If a backup lands in the skills dir, Claude Code registers `sdd-idea.bak-...` as a separate skill — this has burned us. Keep backups outside `skills/`.
- OS gate: refuses anything other than `Darwin` or `Linux`. Windows/WSL is not supported on purpose.
- All four skill names are hard-coded in the install loop: `sdd-idea sdd-impl sdd-undo sdd-feature`.
- Legacy cleanup: if an old `~/.claude/scripts/sdd-doctor.sh` exists from earlier installs, move it aside to the timestamped backup dir — don't leave a stale copy that stale skills might run.

### Language conventions

- **Internal files are English.** SKILL.md bodies, references, installer comments, doctor comments — all English.
- **User-facing output is Russian, informal "ты".** Messages the skill prints to chat, everything written into the user's `PROJECT.md`, and the short `CLAUDE.md` pointer written into the user's generated project.
- When editing a SKILL.md, keep the quoted Russian message templates Russian; don't "localize" them to English.

## Cross-cutting rules (from user's global CLAUDE.md)

- Don't add comments or javadocs unless asked.
- Don't add extra logging.
- When reporting a bug, start by writing a test that reproduces it — don't jump to a fix.
- Don't over-engineer.
