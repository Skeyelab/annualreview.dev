# Deploying to Coolify

The app is a **Docker Compose** stack (Rails API + Solid Queue worker + React frontend). There is no Node server; Nixpacks/Node deployment is no longer supported.

**If you had an existing Coolify deployment** using Nixpacks or a single Node service: create a **new resource** of type **Docker Compose** (same repo, root `docker-compose.yml`). You can leave the old resource stopped or remove it after the new one works.

## Docker Compose (Rails stack)

1. **In Coolify:** Create a new resource → **Docker Compose**. Point it at this repo and use the root `docker-compose.yml`.

2. **Environment variables** (Coolify → your service → Environment)
   - `RAILS_MASTER_KEY` — from `backend/config/master.key` (required; Coolify will prompt if missing)
   - `GITHUB_CLIENT_ID` — from [GitHub OAuth App](https://github.com/settings/developers)
   - `GITHUB_CLIENT_SECRET` — from the same OAuth App
   - `OPENROUTER_API_KEY` — **recommended** for the generate pipeline; uses `anthropic/claude-3.5-sonnet` by default (best quality for structured performance review generation). Takes priority over `OPENAI_API_KEY` when both are set.
   - `OPENAI_API_KEY` — alternative to `OPENROUTER_API_KEY`; uses `gpt-4o-mini` by default.
   - `LLM_MODEL` — (optional) override the model, e.g. `google/gemini-2.0-flash` (OpenRouter, faster/cheaper) or `gpt-4o` (OpenAI)
   - `POSTHOG_API_KEY` — (optional) same project token as frontend; enables LLM analytics (Traces/Generations in PostHog). If missing, pipeline runs but no LLM events are sent.
   - `POSTHOG_HOST` — (optional) default `https://us.i.posthog.com`; use `https://eu.i.posthog.com` for EU.
   - **FRONTEND_URL:** Assign a domain to the **frontend** service in Coolify; Coolify then sets `SERVICE_URL_FRONTEND`, which the compose file uses for post-login redirects. Optionally set `FRONTEND_URL` manually. The frontend container listens on port 80. For other ports use `SERVICE_URL_<NAME>_<PORT>` with **hyphens** (e.g. `SERVICE_URL_MY-SERVICE_3000`). See [Coolify’s magic environment variables](https://coolify.io/docs/knowledge-base/docker/compose#coolifys-magic-environment-variables).

3. **GitHub OAuth App**
   - Set **Authorization callback URL** to:
     `https://<your-coolify-domain>/auth/github/callback`
   - (Requests hit the frontend; nginx proxies `/auth` to Rails.)

4. **What runs**
   - **frontend** — nginx serves the Vite build and proxies `/api` and `/auth` to the backend (port 80 exposed).
   - **backend** — Rails API (SQLite + Solid Queue in `backend_storage` volume).
   - **worker** — Solid Queue runner for collect/generate jobs.

5. **Proxy**
   - Coolify’s reverse proxy should send `X-Forwarded-Proto` and `Host`; the frontend container passes these to Rails.

---
