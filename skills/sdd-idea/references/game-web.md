---
name: game-web
summary: Phaser 3 + Vite + TypeScript + Vitest. Simple browser 2D games — arcades, puzzles, snake, tetris.
impl_mode: handoff
---

## When to pick this stack

Pick this for a 2D browser game: snake, 2048, breakout, a platformer, a puzzle, a mini-game for embedding in a blog. Phaser 3 is a mature JS game engine with physics, sprites, audio, asset management. Vite gives an instant dev server and a small production bundle. TypeScript catches type errors before runtime — valuable in a game loop. Vitest covers tests for individual scenes and pure logic (testing the rendered game itself isn't worthwhile).

## When NOT to pick

If the game is 3D — pick Three.js or Babylon.js. If real-time multiplayer is needed — that's a separate WebSocket/WebRTC project; Phaser isn't the right fit. If it's more of an "interactive canvas widget" than a game — plain canvas API is often enough.

## Minimal MVP tech

- Node.js 22 LTS
- `phaser@^3.85`
- `vite@^5.0`
- TypeScript 5
- `vitest@^2.0`, `@vitest/coverage-v8`, `jsdom` — tests
- No Docker — Vite dev server + HMR runs faster on the host

## Phase 1 recipe (handoff)

SDD does not automate this scaffold — Claude builds Phase 1 from this recipe.

**What Phase 1 must produce:**

1. Initialize:

        npm create vite@latest . -- --template vanilla-ts
        npm install phaser
        npm install -D vitest @vitest/coverage-v8 jsdom

2. Structure:

        src/
        ├── main.ts           — entry point, new Phaser.Game(config)
        ├── config.ts         — game config (width/height/physics)
        ├── scenes/
        │   ├── BootScene.ts  — asset loading
        │   └── MainScene.ts  — first playable scene
        └── utils/
            └── score.ts      — pure logic (score, levels) — this is what you actually test
        public/
        └── assets/           — sprites, audio, fonts
        tests/
        └── score.test.ts
        index.html
        vite.config.ts
        vitest.config.ts
        package.json
        tsconfig.json

3. `index.html` — one `<div id="game"></div>` and `<script type="module" src="/src/main.ts">`.
4. `src/main.ts` creates `Phaser.Game` with `MainScene`, which renders the project name in the center of the screen — the first visible result.
5. First test on `src/utils/score.ts` (increment/reset) to prove tests run.
6. Dev: `npm run dev` → `http://localhost:5000`.

### `vite.config.ts`

```ts
import { defineConfig } from "vite";

export default defineConfig({
  server: { host: "0.0.0.0", port: 5000 },
  build: { outDir: "dist", sourcemap: true },
});
```

### `vitest.config.ts`

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    coverage: {
      provider: "v8",
      include: ["src/utils/**/*.ts"],
      thresholds: { lines: 100, functions: 100, branches: 100, statements: 100 },
    },
  },
});
```

(Coverage intentionally targets only `src/utils/` — pure logic. Phaser scenes rely on Canvas/WebGL, which doesn't live in jsdom; test them by running the game manually.)

## How to test

    npm run test -- --coverage

Covered:
- Every function in `src/utils/*` — pure logic (score, enemy AI, level generation).
- Every pure class without Phaser dependencies.

NOT covered (and why):
- Phaser scenes — depend on WebGL/Canvas; the real test is running the game in a browser.
- `main.ts` — game boot.
- Asset management.

Manual checks:
- Open the game in a browser — is it playable? Does it break on rapid actions?
- Test on mobile — do touch events work (if intended)?

## Do not bring in

- React / Vue / Svelte — a DOM framework ruins performance in a game loop.
- Three.js / Babylon.js — if 3D isn't needed, don't bring it; 2D Phaser suffices.
- Jest — Vitest is faster and integrates with Vite.
- A server component — MVP lives as static files on GitHub Pages / Netlify / Vercel.
- Multiplayer / WebSockets — a separate, larger project; not MVP.
- Third-party physics engines beyond what Phaser has.
- Large asset packs from a CDN — keep assets local in `public/assets/`.
