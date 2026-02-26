# PRD: AnnualReview (GitHub → Evidence → Narrative)

## 1) Overview
AnnualReview is a web app that connects to a developer's GitHub account, analyzes their work over a selected time window (e.g., last calendar year), and generates an evidence-backed annual review draft: themes, impact bullets, STAR stories, and an appendix of links. The product turns raw activity into an "impact narrative" that is safe (no hallucinated claims) and easy to paste into HR systems.

## 2) Problem
Developers struggle to write annual reviews because:
- Work is spread across many PRs/repos and hard to summarize.
- People default to activity metrics ("I merged 45 PRs") instead of impact.
- Evidence gathering (links, dates, artifacts) is time-consuming.
- Managers want clear themes + outcomes + proof, not a changelog.

## 3) Goals / Non-goals
### Goals
- Generate a polished self-review draft with **every claim traceable** to GitHub evidence.
- Produce copy/paste-ready outputs in common formats (generic + "bullets-first").
- Minimize user effort: connect, pick year, generate, optionally add context, regenerate.
- Offer privacy controls and redaction.

### Non-goals (v1)
- Full Jira/Slack ingestion (future phase).
- Auto-confirming business metrics (no access; user provides).
- Performance rating recommendations.

## 4) Target Users
- Individual contributors (mid → staff) writing self-evals.
- Tech leads who want theme-based reporting.
- Contractors/freelancers producing end-of-year summaries.

## 5) Key Use Cases
1. **Self review draft:** "Give me my annual review narrative for 2025."
2. **Brag doc:** Ongoing or end-of-year evidence compilation.
3. **Promotion packet starter:** Top themes + STAR stories + proof links.

## 6) Architecture
- **Frontend:** Vite + React SPA (`frontend/`). Proxies `/api` and `/auth` to the backend in dev.
- **Backend:** Rails 8 API (`backend/`). OmniAuth for GitHub OAuth, Solid Queue for async jobs, SQLite for storage.
- **Models:** `User` (github_id, login, access_token) → has_many `ReviewYear` (year, start/end dates, evidence JSON, pipeline_result JSON, goals).
- **Jobs:** `CollectJob` (fetches GitHub PRs/reviews/releases, normalizes into evidence) and `GenerateJob` (runs LLM pipeline: themes → bullets → STAR → self-eval).
- **Production:** Docker Compose — Rails API (Puma + Thruster), Solid Queue worker, nginx serving the Vite build.

## 7) User Journey (MVP)
1. Sign in via GitHub OAuth (OmniAuth).
2. Select a review year (defaults to calendar year range, customizable start/end).
3. **Collect** — a background job fetches PRs + reviews + releases via the GitHub API and normalizes evidence into a stored JSON payload on the ReviewYear record.
4. **Generate** — a background job runs the LLM pipeline and stores themes, bullets, STAR stories, and self-eval sections on the ReviewYear.
5. View / export the generated narrative with evidence links.
6. Optional: add goals or context → regenerate.

## 8) Functional Requirements
### Auth & Data
- GitHub OAuth via OmniAuth with least-privilege scopes.
- User record stores github_id, login, and encrypted access_token.
- Import user's PRs authored, reviews performed, and relevant metadata:
  - title/body, repo, merged_at, labels, files changed counts, review counts, linked issues/releases when available.
- Per-year data model: each ReviewYear stores raw evidence JSON and generated pipeline_result JSON.

### Story Engine
- Theme clustering (4–8 max) with confidence scoring.
- Bullet generation grounded in evidence IDs/URLs (1–3 citations per bullet).
- STAR story generation grounded in anchor PRs.
- "Missing info questions" when impact cannot be proven from GitHub alone.

### Output & Export
- Render outputs in app with "copy" buttons.
- Export to Markdown + JSON.
- Evidence appendix with links grouped by theme.

### Privacy / Safety
- Redaction controls: hide repo names / replace with "internal repo".
- Exclude selected repos/PRs.
- No fabricated metrics: anything not in evidence must be labeled "needs confirmation."

## 9) Non-Functional Requirements
- Data freshness: collect job completes within a few minutes for typical accounts (hundreds of PRs).
- Reliability: Solid Queue retries and idempotent imports.
- Security: encrypted tokens at rest; minimal OAuth scopes; clear "disconnect & delete" flow.
- Cost control: LLM calls only after structured data is prepared; cache intermediate results in the ReviewYear record.
- Deployment: Docker Compose with persistent SQLite volume; Coolify-compatible.

## 10) Success Metrics
- Activation: % users who connect GitHub and generate a draft.
- Time-to-value: median time from connect → first draft.
- Output usability: % who copy/export at least one section.
- Regeneration rate after adding context (signals usefulness).

## 11) MVP Scope
### In
- GitHub OAuth, year selection, collect PRs+reviews+releases via background job
- Theme clustering + bullets + STAR stories + evidence appendix via background job
- Markdown export
- Basic redaction + exclusions

### Out (later)
- Slack/Jira (and other sources) ingestion — see `docs/multi-source-plan.md`
- Team-wide rollups
- Automated metric lookups (CI, incident tools)
- Manager dashboard

## 12) Open Questions / Risks
- Best GitHub scopes for private repos vs public-only mode.
- How to infer "impact" safely from limited GitHub artifacts.
- Handling monorepos where PRs are broad and hard to theme.
- Rate limiting and pagination for large orgs.

## 13) Milestones
- **M1 (done):** Rails API + OAuth + CollectJob + evidence viewer
- **M2 (done):** GenerateJob + LLM pipeline (themes → bullets → STAR → self-eval)
- **M3:** Export + redaction + privacy controls
- **M4:** Polish: context prompts + goals + regenerate loop
