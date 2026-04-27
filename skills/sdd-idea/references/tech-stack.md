---
name: django-htmx
summary: Django 5 + htmx + SQLite + Pico.css in Docker. Server-rendered web apps — trackers, managers, small internal tools.
---

## What this stack covers

The only stack SDD ships. It targets ordinary web apps: trackers, recipe/budget/notes managers, a simple blog, a checklist, an internal tool. One database, forms, lists, filters, admin for the owner. Everything flows through plain HTTP requests; interactivity comes from htmx (no React, no JS build step). Sized for a single user or a small group, not millions.

## Minimal MVP tech

- Python 3.12
- `Django>=5.0,<6.0` — framework, admin, ORM, forms, migrations, auth
- `django-htmx>=1.21` — middleware + `{% django_htmx_script %}`
- `django-environ>=0.11` — environment variables
- `coverage>=7.6` — coverage measurement
- SQLite (Django's default; file `db.sqlite3`)
- Pico.css (classless, CDN)
- htmx (CDN)
- Docker + `docker compose` v2
- `django.test.TestCase` + `django.test.Client` for tests

## Phase 1 recipe

Phase 1 writes all the files below, boots the container, and verifies the home page + admin. Python runs only inside the container — the host never installs Python.

**Phase 1 steps:**

1. Create the files listed below at the indicated paths.
2. If git isn't initialized, `git init && git add .gitignore && git commit --allow-empty -m "init"`.
3. Bootstrap the Django project inside the container:

        docker compose run --rm --no-deps app django-admin startproject <slug> .
        docker compose run --rm --no-deps app python manage.py startapp core

   If no image is built yet, `docker compose build` first.
4. Patch `<slug>/settings.py`:
   - `ALLOWED_HOSTS = ["*"]`
   - `INSTALLED_APPS` — add `"core"`, `"django_htmx"`
   - `MIDDLEWARE` — after `CommonMiddleware` add `"django_htmx.middleware.HtmxMiddleware"`
   - `TEMPLATES[0]["DIRS"] = [BASE_DIR / "templates"]`
   - `STATIC_URL = "/static/"`, `STATICFILES_DIRS = [BASE_DIR / "static"]`
   - `DATABASES["default"]["NAME"] = BASE_DIR / "db.sqlite3"`
   - `SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-insecure-<slug>")`
   - `DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"`
   - Add module-level constant `PROJECT_NAME = "<Project display name>"`
5. Replace `<slug>/urls.py`:

        from django.contrib import admin
        from django.urls import include, path

        urlpatterns = [
            path("admin/", admin.site.urls),
            path("", include("core.urls")),
        ]

6. Delete `core/tests.py` (use the `core/tests/` package instead).
7. Create the `static/` directory so Django doesn't log `staticfiles.W004` on every boot — `STATICFILES_DIRS` points there but Django won't create it automatically:

        mkdir -p static
        touch static/.gitkeep

   The `.gitkeep` file makes the otherwise-empty directory survive `git clone`.
8. Build, migrate, create superuser:

        docker compose build
        docker compose up -d
        docker compose exec -T app python manage.py migrate
        docker compose exec -T app python manage.py createsuperuser --noinput

   Superuser credentials come from env (`DJANGO_SUPERUSER_*` in compose → `admin` / `admin@example.com` / `admin`).
9. UI gate for `templates/core/home.html`: invoke `frontend-design:frontend-design`, pass the project name and the "Что это" paragraph from PROJECT.md. The resulting template must start with `{% extends "core/base.html" %}` and must contain `<h1>{{ project_name }}</h1>` inside `{% block content %}` (otherwise the test fails).

### Slug derivation

Human name comes from `# <name>` in `PROJECT.md`. Slug (used in `django-admin startproject`) is English, lowercase, spaces and dashes turn into `_`. If the name is Cyrillic, use the neutral `app`. Examples: "Recipe Tracker" → `recipe_tracker`, «Мой бюджет» → `app`.

### `requirements.txt`

```
Django>=5.0,<6.0
django-htmx>=1.21
django-environ>=0.11
coverage>=7.6
```

### `Dockerfile`

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "manage.py", "runserver", "0.0.0.0:5000"]
```

### `docker-compose.yml`

The port comes from `SDD_PORT`. Default: 5000 — `/sdd-impl` substitutes another if it's already in use.

```yaml
services:
  app:
    build: .
    ports:
      - "${SDD_PORT:-5000}:5000"
    volumes:
      - .:/app
    environment:
      - DJANGO_DEBUG=1
      - DJANGO_SECRET_KEY=dev-insecure-change-me
      - DJANGO_SUPERUSER_USERNAME=admin
      - DJANGO_SUPERUSER_EMAIL=admin@example.com
      - DJANGO_SUPERUSER_PASSWORD=admin
    stdin_open: true
    tty: true
```

### `.dockerignore`

```
.git
.gitignore
__pycache__/
*.pyc
*.pyo
.venv/
db.sqlite3
.coverage
htmlcov/
PROJECT.v*.md
```

### `.gitignore`

```
__pycache__/
*.py[cod]
.venv/
.env
db.sqlite3
.coverage
htmlcov/
staticfiles/
.DS_Store
```

(`db.sqlite3` is ignored — data belongs to the specific machine, not the repo.)

### `.coveragerc`

```ini
[run]
source = .
branch = True

[report]
include =
    core/*.py
omit =
    core/migrations/*
    core/tests/*
    core/apps.py
    core/admin.py
    core/__init__.py
exclude_lines =
    pragma: no cover
    def __repr__
    def __str__
    raise NotImplementedError
show_missing = True
skip_covered = False
```

### `templates/core/base.html`

Structural baseline. `frontend-design` can add custom CSS via `extra_head` but doesn't rewrite this shell.

```html
{% load django_htmx %}
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% block title %}{{ project_name }}{% endblock %}</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  <script src="https://unpkg.com/htmx.org@2.0.3" defer></script>
  {% block extra_head %}{% endblock %}
</head>
<body>
  <main class="container">
    {% block content %}{% endblock %}
  </main>
  {% django_htmx_script %}
</body>
</html>
```

### `core/urls.py`

```python
from django.urls import path

from . import views

app_name = "core"

urlpatterns = [
    path("", views.home, name="home"),
]
```

### `core/views.py`

```python
from django.conf import settings
from django.shortcuts import render


def home(request):
    return render(request, "core/home.html", {"project_name": settings.PROJECT_NAME})
```

### `core/tests/__init__.py`

Empty file.

### `core/tests/test_home.py`

Replace `<Project display name>` in the assertion with the real name — it must match what the home page renders.

```python
from django.test import TestCase
from django.urls import reverse


class HomeViewTests(TestCase):
    def test_home_returns_200_with_project_name(self):
        response = self.client.get(reverse("core:home"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "<Project display name>")


class AdminLoginTests(TestCase):
    def test_admin_login_page_accessible(self):
        response = self.client.get("/admin/login/")
        self.assertEqual(response.status_code, 200)
```

### `templates/core/home.html`

Not fixed here — generated by `frontend-design` in the UI gate. Hard constraints only:
- First line: `{% extends "core/base.html" %}`.
- `{% block content %}` contains `<h1>{{ project_name }}</h1>` somewhere.

## How to test

Inside the container, `core/*.py`, 100% coverage on changed files. Command:

    docker compose exec -T app coverage run --source='.' manage.py test
    docker compose exec -T app coverage report --fail-under=100 \
      --include='core/*.py' \
      --omit='core/migrations/*,core/tests/*,core/apps.py,core/admin.py'

Framework: `django.test.TestCase` + `django.test.Client`. No Selenium, pytest-django, or live-server.

Covered (mandatory):
- Every view — happy path (GET/POST, 200/302 + content assertion) and error path (bad input, 404, unauthenticated if auth is present).
- Every model method (not auto-attributes) — especially ones that compute or filter.
- Every form's `clean_*` and `clean()`.
- Custom template tags / filters, when added.

Not covered:
- `__str__` / `__repr__`.
- Getter properties that just return a field as-is.
- Django-generated form fields and serializers.

Files: `core/tests/test_<feature>.py`. One file per feature group, not per class.

### htmx pattern

Every list/form view renders either a full page or a fragment:

    def task_list(request):
        tasks = Task.objects.all()
        if request.htmx:
            return render(request, "core/_task_list.html", {"tasks": tasks})
        return render(request, "core/task_list.html", {"tasks": tasks})

Fragments live at `templates/core/_*.html` (leading underscore). Full pages `extends "core/base.html"`; fragments don't. CSRF for htmx is already wired via `django_htmx` — don't disable it.

### Migrations

After model changes:

    docker compose exec -T app python manage.py makemigrations
    docker compose exec -T app python manage.py migrate
    docker compose exec -T app python manage.py migrate --check

`migrate --check` must pass before commit.

## Do not bring in

- Flask, FastAPI, Jinja — different template engine / different framework.
- React, Vue, Svelte, Alpine, jQuery — the whole point of htmx is to avoid them.
- Tailwind, Bootstrap, any JS bundler — Pico.css classless is enough.
- Celery, Redis, WebSockets — 90% of tasks are solved by plain HTTP.
- DRF — no JSON API needed; the server serves HTML.
- pytest, Selenium, live-server — stock `TestCase` + `Client` covers it.
- Running Python on the host — everything goes through `docker compose exec` / `docker compose run`.
