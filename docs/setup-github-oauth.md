# Making it real: GitHub OAuth and web flow

Right now the app has **no auth**. The Generate page expects pasted/uploaded evidence JSON. The collector runs only via CLI (`GITHUB_TOKEN=xxx yarn collect ...`). To get a real "Connect GitHub" flow you need:

1. **A GitHub OAuth App** (not a "GitHub App" — that’s for bot/install flows).
2. **Auth routes and session** on your server.
3. **An import API** that uses the user’s token to run collect + normalize and return evidence.

---

## 1) Create a GitHub OAuth App

1. Go to **GitHub → Settings → Developer settings → OAuth Apps** (or [github.com/settings/developers](https://github.com/settings/developers)).
2. **New OAuth App**.
3. Fill in:
   - **Application name:** e.g. `AnnualReview (dev)` or `AnnualReview`.
   - **Homepage URL:** `http://localhost:3000` (dev) or `https://annualreview.dev` (prod).
   - **Authorization callback URL:**  
     - Dev: `http://localhost:3000/api/auth/github/callback`  
     - Prod: `https://annualreview.dev/api/auth/github/callback`  
     (You can only set one per app; use a separate OAuth App for prod if needed.)
4. After creating, copy **Client ID** and generate a **Client secret**.

---

## 2) Environment variables

Add to `.env` (or your host’s env):

```bash
# GitHub OAuth (from the OAuth App above)
GITHUB_CLIENT_ID=your_client_id
GITHUB_CLIENT_SECRET=your_client_secret

# Session (any random string; used to sign cookies)
SESSION_SECRET=some_long_random_string
```

Never commit the client secret or session secret. Use different values for dev vs prod.

---

## 3) Scopes (what you’ll request)

From [docs/oauth-scopes.md](./oauth-scopes.md):

| Mode            | Scopes                      | When to use              |
|-----------------|-----------------------------|---------------------------|
| Public repos    | `read:user` `public_repo`    | Default, minimal trust.   |
| Include private | `read:user` `repo`          | User opts in.             |

Start with public-only: request `read:user` and `public_repo` in the authorize URL. You can add a second button or query param later for `?scope=private` that requests `repo` instead.

---

## 4) What’s not implemented yet

The codebase currently has:

- **Landing** → links to `/generate` (paste/upload JSON). No "Connect GitHub" button that hits an auth URL.
- **Generate** → paste/upload evidence, then `POST /api/generate`. No "Import from GitHub" that uses a stored token.
- **Server** (`server.js`) → static + `POST /api/generate`. No `/api/auth/*` routes, no session.

You need to add:

| Piece | Purpose |
|-------|--------|
| **GET /api/auth/github** | Redirect user to `https://github.com/login/oauth/authorize?client_id=...&redirect_uri=...&scope=read:user%20public_repo` |
| **GET /api/auth/github/callback** | Exchange `?code=...` for an access token (POST to GitHub), store token in session, redirect to `/generate` or `/` |
| **Session middleware** | e.g. `express-session` with a secret; store `req.session.githubAccessToken` (and optionally `req.session.user`) |
| **GET /api/me** (optional) | Return current user from session so the UI can show "Signed in as …" or "Connect GitHub" |
| **POST /api/import** | Body: `{ start_date, end_date }`. Use `req.session.githubAccessToken`, call `collectRaw()` then normalize, return evidence JSON so the front end can pass it to `/api/generate` or pre-fill the textarea |
| **POST /api/auth/logout** | Clear session, redirect to `/` |

Then on the front end:

- **Landing:** add "Connect GitHub" that goes to `/api/auth/github` (or two buttons: public vs private with different scope params).
- **Generate:** add "Import from GitHub" (date picker + button) that calls `POST /api/import` and then either runs generate or drops the JSON into the textarea.

---

## 5) Callback URL checklist

- **Local:** callback URL must be exactly `http://localhost:3000/api/auth/github/callback` (or whatever port you use). No trailing slash.
- **Prod:** same idea, e.g. `https://annualreview.dev/api/auth/github/callback`. HTTPS and domain must match where the app is hosted.

If the callback URL doesn’t match exactly, GitHub will show an error and not redirect back with the code.

---

## 6) Token storage and security

- Store the **access token** in the server-side session only (signed cookie or server-side store like Redis). Don’t send it to the browser.
- Use **HTTPS** in production so the session cookie is protected.
- Follow [oauth-scopes.md](./oauth-scopes.md): public-only by default; only request `repo` when the user explicitly chooses "include private repos."

Once the OAuth App exists and these routes + session + import API are implemented, the app becomes "real": users can connect GitHub, pick a timeframe, import evidence, and generate without touching the CLI or pasting JSON.
