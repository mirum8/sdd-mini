---
name: sdd-undo
description: >
  Safely undo the last SDD phase. Reverts the most recent `phase N: ...`
  commit (plus any trailing review commits), unchecks the affected tasks
  in PROJECT.md, and restarts the Docker container so the user can retry
  the phase. Trigger on "/sdd-undo", "rollback", "undo last phase",
  "undo that", and Russian variants: "откати", "отмени", "верни как было",
  "хочу переделать фазу", "эта фаза получилась плохо". Uses `git revert`
  (never `reset`) — history stays clean and the revert itself is a commit
  the user can see and undo again.
---

# sdd-undo — safe rollback of the last phase

Reverts the last SDD phase safely: via `git revert`, not history rewriting. The user can run it as many times as they want — each invocation creates one new revert commit.

## Why this skill exists

A vibe coder doesn't know about `git reset --hard` and shouldn't have to. Sometimes a phase comes out wrong — wrong view, weird UX, or `/simplify` / `/security-review` made things worse. We need a safe "take it back, let me try again" button.

## Steps

### 1. Sanity check git

`git revert` needs git + a repo. Don't run the full doctor — just:

    git rev-parse --is-inside-work-tree >/dev/null 2>&1

If that fails, stop with the Russian message:

> Сначала нужен git и репозиторий. Запусти `git init` и сделай хоть один коммит.

### 2. Find the last phase commit

Look for the most recent commit whose message starts with `phase <N>:`:

    git log --extended-regexp --grep='^phase [0-9]+: ' -n 1 --format='%H %s'

If no such commit exists, there's nothing to undo. Print in Russian:

> Пока нет ни одной завершённой фазы — откатывать нечего. Запусти `/sdd-impl`, чтобы собрать Фазу 1.

Then stop.

### 3. Capture trailing review commits too

After `phase N: ...` there may be fixes from `/simplify` and `/security-review`. List all commits from the phase commit (inclusive) to `HEAD`:

    git log --format='%H %s' <phase-sha>^..HEAD

Collect the SHA list — they all get reverted together as a range.

### 4. Show the user what will be undone

In Russian, briefly:

    Откатим:
      • Фаза <N>: <заголовок>   (<short-sha>)
      • review-фикс: <subject>  (<short-sha>)   ← if present
      • review-фикс: <subject>  (<short-sha>)   ← if present

    Это вернёт файлы в то состояние, в котором они были после Фазы <N-1>.
    Появится новый revert-коммит, история не перепишется. Продолжаем?

### 5. Confirmation via `AskUserQuestion`

- Label «Да, откатить» → proceed.
- Label «Нет, подожду» → exit with no changes.

### 6. Run the revert

    git revert --no-edit <phase-sha>^..HEAD

`--no-edit` skips the message editor; git will produce `Revert "phase N: ..."` automatically. The range form guarantees that any series of review fixes AND the phase itself are reverted as one chain of revert commits.

If revert fails with a conflict (rare — usually means the user made hand-edits between commits), explain in Russian:

> Revert не прошёл автоматически — кажется, в рабочей копии или между коммитами есть что-то, что я не понимаю. Пока я не стану трогать, чтобы не сломать твою работу. Варианты:
> — посмотри `git status`, разберись руками;
> — либо позови меня обратно, покажу, как починить.

Then stop the skill.

### 7. Update PROJECT.md

Find phase `<N>` in `PROJECT.md` and flip all its `- [x]` boxes back to `- [ ]`. Do NOT touch tasks in other phases. Do NOT remove the phase.

If the phase was marked `⚠` (skipped tasks from a previous run), strip the `⚠` too — fresh start.

### 8. Restart the container (best-effort)

    docker compose ps --status running | grep -q app && docker compose restart app

Swallow errors silently if Docker is unavailable — the user will see the doctor next time they run `/sdd-impl`.

### 9. Report to the user in Russian

    ✓ Откатил Фазу <N>: <заголовок>.

    Что сделал:
      • создал revert-коммит: <short-sha>
      • снял галочки с задач Фазы <N> в PROJECT.md
      • перезапустил контейнер (or: Docker не поднят — запусти сам, когда будет надо)

    Теперь можно:
      • запустить /sdd-impl снова — попробую собрать Фазу <N> иначе;
      • поправить PROJECT.md вручную, если хочешь изменить задачи или чекпоинт, и потом /sdd-impl.

## What not to do

- **Never `git reset`**, even if the user asks to "fully delete". Revert is always safe; reset throws away recoverable history.
- **Never force-push.** Not even once.
- **Do not touch `PROJECT.v<N>.md` backups.** They're the user's safety net.
- **Only undo one phase per invocation.** If the user wants to go back further, they run `/sdd-undo` again. This keeps each step visible and controllable.
- **Do not delete files by hand.** `git revert` handles it.
- **Do not run tests after the revert.** We just returned the project to a state where tests already passed (end of phase N-1). The container restart is enough sanity.
