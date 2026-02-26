# Rails API (port 3000). Remove stale pid so foreman start works after a previous run.
web: cd backend && (test -f tmp/pids/server.pid && ! kill -0 $(cat tmp/pids/server.pid) 2>/dev/null && rm -f tmp/pids/server.pid; true) && FRONTEND_URL=http://localhost:5173 bin/rails server -p 3000
# Vite dev server (port 5173). Proxies /api and /auth to Rails.
frontend: yarn dev
# Solid Queue worker for collect/generate jobs.
jobs: cd backend && bin/jobs
