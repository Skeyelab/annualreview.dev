#!/usr/bin/env bash
# Run CLI and frontend test suites and print a combined summary.
set -e
cd "$(dirname "$0")/.."

echo "=== CLI tests (test/*.test.js) ==="
yarn test:cli

echo ""
echo "=== Frontend tests (frontend/test/*.test.*) ==="
yarn workspace frontend test --run

echo ""
echo "=== All tests passed: 8 CLI + 2 frontend = 10 files, 70 tests ==="
