# AnnualReview.dev

Turn GitHub contributions into an evidence-backed annual review. **https://annualreview.dev**

This repo contains:
- `frontend/` — Vite + React SPA (run with `yarn dev` or `yarn build`)
- `backend/` — Rails API + Solid Queue (run with `foreman start` or `yarn dev:full`)
- `PRD.md` — one-page product requirements doc
- `prompts/` — Cursor-ready prompt templates for a GitHub→story pipeline
- `AGENTS.md` — suggested agent workflow and guardrails

## Suggested pipeline
1) Import GitHub evidence (PRs, reviews, releases) into a structured JSON payload.
2) Run prompts in order:
   - `prompts/00_system.md` (as system)
   - `prompts/10_theme_cluster.md`
   - `prompts/20_impact_bullets.md`
   - `prompts/30_star_stories.md`
   - `prompts/40_self_eval_sections.md`

## Development

Run the full stack (Rails API + Vite frontend + Solid Queue worker) with one command:

```bash
yarn dev:full
```

This frees ports 5173 and 3000 if something is already running, then starts Foreman. You can also run `foreman start` directly if no other instance is running.

- **Rails API** → http://localhost:3000
- **Vite (React)** → http://localhost:5173 — open this in the browser; it proxies `/api` and `/auth` to Rails.

**Before first run:**

1. `cd backend && bundle install && bin/rails db:prepare && bin/rails db:schema:load:queue`
2. Copy `.env` (or create it) with `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `OPENAI_API_KEY`.
3. In your GitHub OAuth app, set **Authorization callback URL** to `http://localhost:5173/auth/github/callback`.

**Without Foreman:** Run `yarn dev` for the frontend and `cd backend && bin/rails server -p 3000` for the API separately.

**If you see "A server is already running" or "Port 5173 is in use":** Use `yarn dev:full` instead of `foreman start`; it stops whatever is on ports 3000 and 5173, then starts the stack.

## How to get the data to paste

**Quick path:** [docs/how-to-get-evidence.md](docs/how-to-get-evidence.md) — create a GitHub token, run collect + normalize, then paste or upload **evidence.json** on the Generate page.

## Production (Docker Compose / Coolify)

The production stack uses Docker Compose with three services:

- **backend** — Rails API (Puma + Thruster)
- **worker** — Solid Queue for collect/generate jobs
- **frontend** — nginx serves the Vite build and proxies `/api` and `/auth` to the backend

See [docs/deploy-coolify.md](docs/deploy-coolify.md) for Coolify-specific setup.

**Required env:** `RAILS_MASTER_KEY`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `OPENAI_API_KEY`. In GitHub OAuth App settings, set **Authorization callback URL** to `https://<your-domain>/auth/github/callback`. See [docs/oauth-scopes.md](docs/oauth-scopes.md).

**Optional (analytics):** `VITE_POSTHOG_API_KEY` — enables client-side PostHog (pageviews and autocapture). For EU host use `VITE_POSTHOG_HOST=https://eu.i.posthog.com`.

## CLI Scripts

- **Collect:** `GITHUB_TOKEN=xxx yarn collect --start YYYY-MM-DD --end YYYY-MM-DD --output raw.json` — fetches your PRs and reviews from GitHub for the date range.
- **Normalize:** `yarn normalize --input raw.json --output evidence.json` — turns raw API output into the evidence contract.
- **Generate:** `yarn generate evidence.json` — runs the LLM pipeline (themes → bullets → STAR → self-eval). Writes to `./out` by default; use `--out dir` to override. Requires `OPENAI_API_KEY`.

## Evidence grounding contract
Every generated bullet/claim must cite evidence items by id+url. If impact is not proven, output must ask for confirmation instead of guessing.
