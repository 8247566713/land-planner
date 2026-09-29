# InfraVision

Smart infrastructure planning & 3D visualization system. Measure land, convert
between Indian land units, lay out a project on the 2D planner, see it in 3D,
and generate a preliminary material-and-cost estimate.

```bash
npm install
cp .env.example .env   # set DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME, then:
npm run db:init        # create schema (idempotent migration)
npm run dev            # client http://localhost:5173 + API http://localhost:4000
npm run verify         # typecheck + 108 unit tests + production build
npm run smoke:api      # end-to-end API checks against a real MySQL database
npm run smoke          # visits all 9 screens in real headless Chrome (dev server must be running)
```

`npm run dev` starts both the Vite client and the tsx-run API. `npm run launch`
is the same but also opens your browser.

## What is here

| Screen | Does |
|---|---|
| **Dashboard** | Overview of the workspace, active project, recent projects. |
| **Projects** | Create, edit, re-classify, delete projects; pick the active one. |
| **Land** | Enter a plot, read its area in sq ft, gajulu, sq m, cent, gunta and acre; convert any value between units. |
| **2D Planner** | To-scale drawing of the plot and the components on it, with grid, per-component properties, and undo/redo. |
| **3D Model** | The same blueprint rendered with Three.js; follows the 2D plan as the single source of truth. |
| **Estimate** | Material & cost estimate for the active project; runs the same core in the browser and records revisions server-side. |
| **Calculators** | 8 infrastructure modules (house, road, railway, airport, bridge, dam, water treatment, college). |
| **AI Assistant** | Natural-language plan prompt (needs an AI provider configured on the server). |
| **Export** | Download a PDF summary or a CSV blueprint of the project. |

## Data accuracy notes

**"1 cent = 40.76 sq m" is wrong.** 435.6 sq ft is **40.4686 sq m**.
Cross-checked two ways: `435.6 x 0.09290304`, and `4046.8564 sq m / 100 cents`
(1 acre = 100 cents). Several popular articles quote 40.76, which would make
every metric area the app prints wrong. The test suite pins the correct value.

**"Cent" is not one size.** It is a customary unit fixed by local survey
practice, and those differ. The default is 435.6 sq ft (statutory in Tamil Nadu,
Kerala, Andhra Pradesh and Telangana), but it is user-configurable rather than
hardcoded, because the app cannot know what the local surveyor used. Read it
off the sale deed or patta.

Other relations the tests pin down:

```
1 gajulu (sq yd) = 9 sq ft          1 gunta = 1,089 sq ft = 121 gajulu
1 sq ft = 0.09290304 sq m           1 acre  = 43,560 sq ft = 4,046.86 sq m
1 ft = 0.3048 m (exact)             1 acre  = 100 cents = 40 guntas
```

Gunta and gajulu are constantly confused with each other in the field. They are
not the same thing and the app never treats them as such.

## Architecture

The rule that keeps this from turning into two disagreeing apps:

> **The 2D blueprint is the single source of truth. The 3D view and the
> estimate are derived from it.**

Nothing is authored in 3D. Components on the plan give the floor slabs; the wall
network from `core/walls.ts` gives the walls, doors and windows; the estimator
takes quantities off the same geometry. There is no second model to fall out of
sync.

```
src/core/     pure logic, no DOM, no Three.js  <- the portable part
  units.ts      unit conversion, region presets, formatting
  plan-model.ts Rect/Room/Wall/Opening, room catalogue, setbacks
  walls.ts      room rects -> wall network; door & window placement
  layout.ts     auto-suggest packing, growth, balcony attachment, editing ops
  blueprint.ts  project components (plot, block, road, ...) and their rules
  estimate.ts   material & cost takeoff from a blueprint
  calculators.ts 8 infrastructure planning modules
src/app/      React app (Vite + TypeScript)
  App.tsx       shell: sidebar, theme, routing
  pages/        one file per screen (9 screens)
  store.tsx     app store: toasts, health, meta, active project
  api.ts        typed client for the API
server/src/   Express API (tsx), same core for reproducible estimates
  routes/       projects, estimate/history, calculators, units, meta, ai
  db.ts         mysql2 pool; migrate.ts creates the schema
scripts/      api-smoke.mjs, start.mjs, ui-check.mjs
```

`src/core/` has no imports from the browser, which is what makes the estimate
identical whether it runs in the browser or on the server — the API records
revisions into MySQL, and the client can reproduce them from the same code path.

### How the auto-suggest works, and what it is not

Rectilinear **skyline packing** (bottom-left placement), then three cheap
improvement passes: grow rooms into genuinely free space, attach balconies to
the room they serve, and name rooms so the largest bedroom is the master.

This is a *starting point*, not an architect's house. It guarantees no
overlaps, everything inside the buildable envelope, and public rooms near the
front — then gets out of the way.

Rooms that do not fit are **reported, never dropped**. A planner that silently
loses a bedroom because the plot is too small is not trustworthy.

### Walls without CSG

Each wall is built as solid panels around its openings: full-height panel,
then below-sill, then lintel, then the door leaf or glass pane. Boolean
subtraction would look marginally better and cost far more — panel splitting
keeps the geometry cheap and keeps UVs intact for materials.

## Verification

- **108 unit tests** (`npm test`) pinning the unit constants, packing
  invariants across many plot sizes, wall topology, and opening placement.
- **`npm run smoke:api`** boots the real server and exercises every endpoint
  against the real MySQL database, then deletes the rows it created.
- **`npm run smoke`** (dev server running) drives real headless Chrome over the
  DevTools protocol and asserts all 9 screens mount with no error overlay and
  no console errors.

Not yet verified: how the 3D view *looks*. Nothing here asserts that the result
is visually correct — a human needs to look.