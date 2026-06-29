#!/usr/bin/env bash
# tools/ci_watch.sh
# Push feature_ci-setup, wait for CI, print full busted log.
# Usage (from repo root):  bash tools/ci_watch.sh [branch]
#
# Requires: gh (scoop install gh) — token auto-extracted from git credential store.

set -euo pipefail

export PATH="$PATH:/c/Users/Moi/scoop/shims"

BRANCH="${1:-feature_ci-setup}"
REPO="FullGas1/CTLD_Next"

# ── Extract GitHub token from git credential store ───────────────────────
export GH_TOKEN
GH_TOKEN=$(printf 'protocol=https\nhost=github.com\n' \
  | git credential fill 2>/dev/null \
  | grep '^password=' | cut -d= -f2-)

if [ -z "$GH_TOKEN" ]; then
  echo "ERROR: no GitHub token found. Run 'gh auth login' manually."
  exit 1
fi

# ── 1. Push if on the CI branch ──────────────────────────────────────────
CURRENT=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT" = "$BRANCH" ]; then
  echo "Pushing $BRANCH..."
  git push origin "$BRANCH" 2>&1 | grep -v "^$" || true
else
  echo "(on branch $CURRENT — not pushing)"
fi

# ── 2. Wait for new run to appear ────────────────────────────────────────
echo "Waiting for CI run on $BRANCH..."
BASELINE=$(gh run list --repo "$REPO" --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "0")

RUN_ID=""
for i in $(seq 1 12); do
  sleep 8
  LATEST=$(gh run list --repo "$REPO" --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "0")
  if [ "$LATEST" != "$BASELINE" ] && [ "$LATEST" != "0" ]; then
    RUN_ID="$LATEST"
    echo "New run detected: $RUN_ID"
    break
  fi
  echo -n "."
done

if [ -z "$RUN_ID" ]; then
  echo ""
  echo "(no new run in 96s — using most recent)"
  RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
fi

echo "https://github.com/$REPO/actions/runs/$RUN_ID"

# ── 3. Watch until complete ──────────────────────────────────────────────
gh run watch "$RUN_ID" --repo "$REPO" 2>/dev/null || true

# ── 4. Print result + full busted log ───────────────────────────────────
echo ""
echo "=== Job summary ==="
gh run view "$RUN_ID" --repo "$REPO" 2>/dev/null || true

echo ""
echo "=== busted Tests log ==="
gh run view "$RUN_ID" --repo "$REPO" --log --job "busted Tests" 2>/dev/null \
  | grep -v "^20[0-9][0-9]-" \
  | head -150

CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO" --json conclusion --jq '.conclusion' 2>/dev/null)
[ "$CONCLUSION" = "success" ] && exit 0 || exit 1
