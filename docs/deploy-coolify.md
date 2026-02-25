# Deploy AnnualReview.dev with Coolify

Deploy from your Git repo using the **Dockerfile** build pack. Coolify will build the image and run the app. Set the required env vars so the Generate pipeline and GitHub OAuth work.

## 1. Create a new resource

- In Coolify, open your project → **Create New Resource**.
- Choose **Public Repository** (or GitHub App / Deploy Key if the repo is private).
- Paste the repo URL, e.g. `https://github.com/Skeyelab/annual-review-story-kit`.

## 2. Use the Dockerfile build pack

- **Build pack:** Switch from Nixpacks to **Dockerfile**.
- **Base directory:** `/` (root).
- **Branch:** `main` (or your default).

Continue to the next step.

## 3. Network and port

- **Port:** `3000`. The app listens on `PORT` (default 3000) and binds to `0.0.0.0` ([Coolify Dockerfile docs](https://coolify.io/docs/builds/packs/dockerfile) recommend this so the app is reachable via the domain).
- **Domain:** Add your domain (e.g. `annualreview.dev`). Coolify can provision free SSL via Let's Encrypt.

## 4. Environment variables

In **Environment Variables** add:

| Variable             | Required | Description                                                                 |
|----------------------|----------|-----------------------------------------------------------------------------|
| `SESSION_SECRET`     | Yes      | Random string for signing session cookies (e.g. `openssl rand -hex 32`).   |
| `GITHUB_CLIENT_ID`   | Yes*     | From [GitHub OAuth App](https://github.com/settings/developers).           |
| `GITHUB_CLIENT_SECRET`| Yes*     | From the same OAuth App.                                                    |
| `OPENAI_API_KEY`     | Yes      | OpenAI API key for the review pipeline (themes → bullets → STAR → self-eval). |

\* OAuth is optional if you only use token paste or CLI for evidence; required for “Sign in with GitHub” and in-app fetch.

**GitHub OAuth App:** Create an OAuth App (or use existing). Set **Authorization callback URL** to:
`https://<your-coolify-domain>/api/auth/callback/github`  
No trailing slash; must match the public URL Coolify gives the app.

**Proxy:** Coolify’s reverse proxy should send `X-Forwarded-Proto: https` and `Host` so the server can build the correct callback URL and set `Secure` cookies.

## 5. Deploy

Trigger the deployment. Coolify will:

1. Clone the repo.
2. Build the Docker image (multi-stage: `yarn build` then production image with `dist/` + Node server).
3. Run the container with `node server.js` (serves static app + `/api/*`).

## 6. Verify

- Open your domain: you should see the AnnualReview.dev landing page.
- Go to **Generate a review** → paste or upload evidence JSON → **Generate review**. If `OPENAI_API_KEY` is set, the pipeline runs and returns themes, bullets, STAR stories, and self-eval.
- If OAuth is configured, “Sign in with GitHub” and in-app fetch should work.

## Optional: healthcheck

The Dockerfile does not define a HEALTHCHECK. If you want Coolify to mark the app healthy, add a health endpoint to the server (e.g. `GET /health` returning 200) and configure a health check in Coolify’s Advanced settings (e.g. `wget -qO- http://127.0.0.1:3000/health || exit 1`).

## Troubleshooting

- **"No Available Server"** or 404 on the domain: Confirm the **port** in Coolify’s network settings is **3000** and the container is running (`docker ps` on the server).
- **Generate returns 500:** Check that `OPENAI_API_KEY` is set in the Coolify environment and that the container logs show no missing-env errors.
- **Build fails:** Ensure the repo has `Dockerfile`, `package.json`, and `yarn.lock`; the build uses `yarn install --frozen-lockfile` and `yarn build`.

## Reference

- [Coolify – Dockerfile build pack](https://coolify.io/docs/builds/packs/dockerfile)
- [Coolify – Deploy public repository](https://coolify.io/docs/applications/ci-cd/github/public-repository)
- This repo: `Dockerfile`, `server.js`, `package.json` (scripts: `build`, `start`).
