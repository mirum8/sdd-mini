---
name: nextjs
summary: Next.js 15 (App Router) + Prisma + SQLite + Tailwind + Vitest in Docker. For SPA-grade interactivity — drag-and-drop, live updates, complex UI.
impl_mode: scaffold
---

## When to pick this stack

Pick this when the UI needs heavy client-side logic: drag-and-drop between columns, inline-edit in large tables, reactive UI with optimistic updates, kanban, block editors. Django + htmx does not scale well to these — real React + client state is needed. Next.js App Router + Server Components keep SSR and API routes inside one framework. Prisma covers the data layer without a separate ORM. Keep SQLite for "zero configuration" — good enough for MVP.

## Minimal MVP tech

- Node.js 22 LTS
- `next@15` (App Router)
- `react@19`, `react-dom@19`
- `prisma@6`, `@prisma/client@6` — ORM + migrations
- `better-sqlite3` — SQLite driver for Prisma
- `tailwindcss@3` — styling (minimally configured)
- `vitest@2`, `@vitest/coverage-v8`, `@testing-library/react`, `@testing-library/jest-dom`, `jsdom` — tests
- TypeScript 5
- Docker + `docker compose` v2

## Phase 1 recipe

Phase 1 boots a container with the Next.js dev server, the SQLite DB via Prisma, a home page, a health route, and one passing test.

**Phase 1 steps:**

1. Write the files below.
2. If git isn't initialized, `git init && git add .gitignore && git commit --allow-empty -m "init"`.
3. Install deps and generate the Prisma client inside the container:

        docker compose run --rm --no-deps app npm install
        docker compose run --rm --no-deps app npx prisma migrate dev --name init

4. Build and run:

        docker compose build
        docker compose up -d

5. UI gate for `src/app/page.tsx`: invoke `frontend-design:frontend-design`, pass the project name and "Что это" from PROJECT.md. The component must render an `<h1>` with the project name — otherwise the test fails.

### `package.json`

```json
{
  "name": "<slug>",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -H 0.0.0.0 -p 5000",
    "build": "next build",
    "start": "next start -H 0.0.0.0 -p 5000",
    "test": "vitest run",
    "test:coverage": "vitest run --coverage"
  },
  "dependencies": {
    "@prisma/client": "^6.0.0",
    "better-sqlite3": "^11.0.0",
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/react": "^16.0.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "@vitest/coverage-v8": "^2.0.0",
    "autoprefixer": "^10.4.0",
    "jsdom": "^25.0.0",
    "postcss": "^8.4.0",
    "prisma": "^6.0.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.0.0",
    "vitest": "^2.0.0"
  }
}
```

### `Dockerfile`

```dockerfile
FROM node:22-slim

ENV NODE_ENV=development

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

EXPOSE 5000

CMD ["npm", "run", "dev"]
```

### `docker-compose.yml`

```yaml
services:
  app:
    build: .
    ports:
      - "${SDD_PORT:-5000}:5000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - DATABASE_URL=file:./dev.db
    stdin_open: true
    tty: true
```

### `.dockerignore`

```
.git
.gitignore
node_modules/
.next/
coverage/
prisma/*.db
prisma/*.db-journal
PROJECT.v*.md
```

### `.gitignore`

```
node_modules/
.next/
.env
.env.local
coverage/
prisma/*.db
prisma/*.db-journal
.DS_Store
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

### `next.config.ts`

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;
```

### `tailwind.config.ts`

```ts
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};

export default config;
```

### `postcss.config.js`

```js
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
```

### `src/app/globals.css`

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

### `src/app/layout.tsx`

```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "<Project display name>",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  );
}
```

### `src/app/page.tsx`

Generated by `frontend-design` in the UI gate. Hard constraint: the component must render an `<h1>` with the project name (so the test passes). The `PROJECT_NAME` constant lives in `src/lib/config.ts`.

### `src/lib/config.ts`

```ts
export const PROJECT_NAME = "<Project display name>";
```

### `src/app/api/health/route.ts`

```ts
import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({ status: "ok" });
}
```

### `prisma/schema.prisma`

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}
```

(Models appear from Phase 2 onward — an empty schema is fine for setup.)

### `src/lib/db.ts`

```ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

### `vitest.config.ts`

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    coverage: {
      provider: "v8",
      include: ["src/**/*.{ts,tsx}"],
      exclude: ["src/**/*.test.{ts,tsx}", "src/app/layout.tsx", "src/lib/db.ts"],
      thresholds: { lines: 100, functions: 100, branches: 100, statements: 100 },
    },
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
```

### `vitest.setup.ts`

```ts
import "@testing-library/jest-dom/vitest";
```

### `src/app/page.test.tsx`

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import Page from "./page";
import { PROJECT_NAME } from "@/lib/config";

describe("Home page", () => {
  it("renders the project name", () => {
    render(<Page />);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(PROJECT_NAME);
  });
});
```

### `src/app/api/health/route.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { GET } from "./route";

describe("GET /api/health", () => {
  it("returns 200 with status ok", async () => {
    const res = await GET();
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ status: "ok" });
  });
});
```

## How to test

Inside the container, `src/**/*.{ts,tsx}`, 100% coverage on changed files. Command:

    docker compose exec -T app npm run test:coverage

`vitest.config.ts` already enforces 100% thresholds. The phase does not close until vitest is green.

Covered:
- Every Server / Client Component — at least one render + key states.
- Every API route — happy path + error path.
- Every utility in `src/lib/*.ts` (excluding `db.ts` — it's the Prisma singleton).
- Every Server Action — successful call + validation error paths.

Not covered:
- `src/app/layout.tsx` — shell, nothing to verify.
- `src/lib/db.ts` — global Prisma singleton.
- Autogenerated: `.next/`, Prisma client.

Files: sibling `*.test.tsx` / `*.test.ts` next to the code, not a separate `tests/`. Framework: `vitest` + `@testing-library/react`. No Jest, Playwright, or Cypress in MVP scope.

### Prisma migrations

After editing `prisma/schema.prisma`:

    docker compose exec -T app npx prisma migrate dev --name <short_name>
    docker compose exec -T app npx prisma generate

Migration files are committed with the phase.

## Do not bring in

- Redux, Zustand, MobX — React state + Server Actions cover MVP needs.
- tRPC, GraphQL — App Router + Server Actions already connect server-to-client.
- Jest, Playwright, Cypress — vitest + Testing Library is simpler and faster.
- Styled-components, Emotion, CSS-in-JS — Tailwind.
- Postgres, MySQL — SQLite is enough for MVP; migration is separate work.
- Class components — functional only, with hooks.
- Auth libraries (NextAuth, Clerk) at MVP — if auth is needed, add it as its own phase with justification.
- Running `npm` / `node` on the host — everything through `docker compose exec` / `docker compose run`.
