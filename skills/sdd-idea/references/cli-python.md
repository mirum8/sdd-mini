---
name: cli-python
summary: Python 3.12 + Typer + Rich + pytest. Terminal utilities — batch rename, converters, local automation.
impl_mode: handoff
---

## When to pick this stack

Pick this when the idea is a command-line utility: batch rename, a format converter, a report generator, an API client, a local automation script. No UI, just arguments, stdout/stderr, and an exit code. Typer gives typed subcommands with autocompletion; Rich handles colored output, tables, and progress bars; pytest is the industry standard for Python tests.

## Minimal MVP tech

- Python 3.12
- `typer[all]>=0.12` — CLI (subcommands, autocompletion, help)
- `rich>=13.7` — formatted output
- `pytest>=8.0` — tests
- `pytest-cov>=5.0` — coverage
- `pydantic>=2.0` — if typed configs/data are useful
- Plain `.venv` — Docker is overkill for a CLI; it runs on the host
- `hatch` or `setuptools` — build + PATH install

## Phase 1 recipe (handoff)

SDD does not automate Python CLIs (Docker is overkill; `.venv` management is outside scope). Claude builds Phase 1 from this recipe.

**What Phase 1 must produce:**

1. Create `.venv`:

        python3.12 -m venv .venv
        source .venv/bin/activate
        pip install --upgrade pip

2. Directory shape:

        pyproject.toml
        src/
        └── <slug>/
            ├── __init__.py
            ├── cli.py          — Typer app
            └── commands/
                ├── __init__.py
                └── hello.py    — first command
        tests/
        ├── __init__.py
        └── test_hello.py

3. `pyproject.toml`:

        [project]
        name = "<slug>"
        version = "0.1.0"
        requires-python = ">=3.12"
        dependencies = ["typer[all]>=0.12", "rich>=13.7"]

        [project.scripts]
        <slug> = "<slug>.cli:app"

        [project.optional-dependencies]
        dev = ["pytest>=8.0", "pytest-cov>=5.0"]

        [build-system]
        requires = ["hatchling"]
        build-backend = "hatchling.build"

4. `src/<slug>/cli.py`:

        import typer
        from .commands import hello

        app = typer.Typer(help="<Project display name>")
        app.add_typer(hello.app, name="hello")

        if __name__ == "__main__":
            app()

5. `src/<slug>/commands/hello.py` — a real first command (not a placeholder "hello world"; something from PROJECT.md, even if trimmed).
6. First test in `tests/test_hello.py` using `typer.testing.CliRunner`:

        from typer.testing import CliRunner
        from <slug>.cli import app

        runner = CliRunner()

        def test_hello_runs():
            result = runner.invoke(app, ["hello", "--name", "world"])
            assert result.exit_code == 0
            assert "world" in result.stdout

7. Editable install: `pip install -e ".[dev]"`. After that the `<slug>` command is available globally inside the venv.

## How to test

- All tests: `pytest`
- Coverage: `pytest --cov=src/<slug> --cov-report=term-missing --cov-fail-under=100`
- Integration (if added): `pytest tests/integration/` — real CLI invocations via `CliRunner` or `subprocess`.

Covered:
- Every command — happy path + invalid arguments path.
- Every branch (flags, fallbacks).
- Every utility in `src/<slug>/utils.py`.

Not covered:
- `__main__` block in `cli.py`.
- Pure dataclasses / Pydantic models with no behavior.

## Do not bring in

- Click — Typer is built on Click and is more ergonomic.
- argparse — too much boilerplate for this stack.
- Docker — overkill for CLIs, run via venv.
- Manual `setup.py` — pyproject.toml + hatchling.
- `print()` for production output — use `rich.console.Console`.
- A big framework (Django/Flask) — CLI should start in milliseconds.
- Async, if the work isn't IO-bound — CLIs are usually simple and synchronous.
