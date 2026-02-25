# Deploy AnnualReview.dev with Coolify

Deploy from your Git repo using the **Dockerfile** build pack. Coolify will build the image and run the app; set `OPENAI_API_KEY` so the Generate pipeline works.

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

| Variable          | Required | Description                                      |
|-------------------|----------|--------------------------------------------------|
| `OPENAI_API_KEY`  | Yes      | OpenAI API key for the review pipeline (themes → bullets → STAR → self-eval). |

No other env vars are required for a basic deploy.

## 5. Deploy

Trigger the deployment. Coolify will:

1. Clone the repo.
2. Build the Docker image (multi-stage: `yarn build` then production image with `dist/` + Node server).
3. Run the container with `node server.js` (serves static app + `POST /api/generate`).

## 6. Verify

- Open your domain: you should see the AnnualReview.dev landing page.
- Go to **Generate a review** → paste or upload evidence JSON → **Generate review**. If `OPENAI_API_KEY` is set, the pipeline runs and returns themes, bullets, STAR stories, and self-eval.

## Optional: healthcheck

The Dockerfile does not define a HEALTHCHECK. If you want Coolify to mark the app healthy, you can add a health endpoint to `server.js` (e.g. `GET /health` returning 200) and configure a health check in Coolify’s Advanced settings (e.g. `wget -qO- http://127.0.0.1:3000/health || exit 1`).

## Troubleshooting

- **"No Available Server"** or 404 on the domain: Confirm the **port** in Coolify’s network settings is **3000** and the container is running (`docker ps` on the server).
- **Generate returns 500:** Check that `OPENAI_API_KEY` is set in the Coolify environment and that the container logs show no missing-env errors.
- **Build fails:** Ensure the repo has `Dockerfile`, `package.json`, and `yarn.lock`; the build uses `yarn install --frozen-lockfile` and `yarn build`.

## Reference

- [Coolify – Dockerfile build pack](https://coolify.io/docs/builds/packs/dockerfile)
- [Coolify – Deploy public repository](https://coolify.io/docs/applications/ci-cd/github/public-repository)
- This repo: `Dockerfile`, `server.js`, `package.json` (scripts: `build`, `start`).
