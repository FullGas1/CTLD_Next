#!/usr/bin/env bash
# tools/ci_watch.sh
# Push feature_ci-setup, wait for CI, print busted log summary.
# Usage (from repo root):  bash tools/ci_watch.sh

REPO="FullGas1/CTLD_Next"
BRANCH="feature_ci-setup"
API="https://api.github.com/repos/$REPO"

# ── 1. Optionally push if on the CI branch ──────────────────────────────
CURRENT=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT" = "$BRANCH" ]; then
  git push origin "$BRANCH" 2>&1 | grep -v "^$" || true
fi

# ── 2. Get run ID just triggered (wait up to 60s for it to appear) ───────
echo "Waiting for new run on $BRANCH..."
BASELINE_ID=$(curl -sk "$API/actions/runs?branch=$BRANCH&per_page=1" \
  | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

RUN_ID=""
for i in $(seq 1 12); do
  sleep 10
  LATEST_ID=$(curl -sk "$API/actions/runs?branch=$BRANCH&per_page=1" \
    | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  if [ "$LATEST_ID" != "$BASELINE_ID" ] && [ -n "$LATEST_ID" ]; then
    RUN_ID="$LATEST_ID"
    break
  fi
  echo -n "."
done

# If no new run appeared, use latest existing run
if [ -z "$RUN_ID" ]; then
  echo ""
  echo "(No new run detected — using most recent run)"
  RUN_ID=$(curl -sk "$API/actions/runs?branch=$BRANCH&per_page=1" \
    | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
fi

echo ""
echo "Run ID: $RUN_ID"
echo "URL: https://github.com/$REPO/actions/runs/$RUN_ID"

# ── 3. Poll until completed ──────────────────────────────────────────────
echo "Polling..."
CONCLUSION=""
for i in $(seq 1 60); do
  sleep 5
  DATA=$(curl -sk "$API/actions/runs/$RUN_ID")
  STATUS=$(echo "$DATA" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
  CONCLUSION=$(echo "$DATA" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
  echo -n "."
  if [ "$STATUS" = "completed" ]; then
    echo ""
    break
  fi
done

echo "Result: $CONCLUSION"

# ── 4. Fetch busted Tests job logs ──────────────────────────────────────
JOBS=$(curl -sk "$API/actions/runs/$RUN_ID/jobs")
BUSTED_JOB_ID=$(echo "$JOBS" | grep -B2 '"busted Tests"' | grep '"id"' | grep -o '[0-9]*' | tail -1)

if [ -n "$BUSTED_JOB_ID" ]; then
  echo ""
  echo "=== busted Tests log ==="
  curl -sk "$API/actions/jobs/$BUSTED_JOB_ID/logs" \
    | grep -E "Error|Failure|error|failure|successes|pending|passed|failed" \
    | grep -v "^$" \
    | head -80
fi

# ── 5. Also check Merge Build ────────────────────────────────────────────
BUILD_JOB_ID=$(echo "$JOBS" | grep -B2 '"Merge Build"' | grep '"id"' | grep -o '[0-9]*' | tail -1)
BUILD_CONCLUSION=$(echo "$JOBS" | grep -A20 '"Merge Build"' | grep '"conclusion"' | head -1 | cut -d'"' -f4)
echo ""
echo "Merge Build: $BUILD_CONCLUSION"
echo "Lua 5.1 Syntax: $(echo "$JOBS" | grep -A20 '"Lua 5.1 Syntax Check"' | grep '"conclusion"' | head -1 | cut -d'"' -f4)"

[ "$CONCLUSION" = "success" ] && exit 0 || exit 1
