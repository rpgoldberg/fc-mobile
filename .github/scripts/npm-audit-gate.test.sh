#!/usr/bin/env bash
#
# Tests for npm-audit-gate.sh.
#
#   bash .github/scripts/npm-audit-gate.test.sh
#
# Deliberately does NOT use `set -e`: several cases assert on a non-zero exit
# status, which is the exact interaction that broke the workflow this gate
# replaces.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/npm-audit-gate.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
LAST_OUTPUT=""
LAST_STATUS=0

fixture() {
  # fixture <name> <<'JSON' ... JSON
  local name="$1"
  cat > "$WORK/$name"
}

run_gate() {
  LAST_OUTPUT="$("$@" 2>&1)"
  LAST_STATUS=$?
}

ok() {
  PASSED=$((PASSED + 1))
  printf 'ok   %s\n' "$1"
}

ko() {
  FAILED=$((FAILED + 1))
  printf 'FAIL %s\n' "$1"
  printf '     status=%s\n' "$LAST_STATUS"
  printf '     output:\n'
  printf '%s\n' "$LAST_OUTPUT" | sed 's/^/       /'
}

expect_status() {
  local name="$1" want="$2"
  if [ "$LAST_STATUS" = "$want" ]; then
    ok "$name (exit $want)"
  else
    ko "$name (expected exit $want, got $LAST_STATUS)"
  fi
}

expect_contains() {
  local name="$1" needle="$2"
  case "$LAST_OUTPUT" in
    *"$needle"*) ok "$name (output contains '$needle')" ;;
    *) ko "$name (output missing '$needle')" ;;
  esac
}

# --------------------------------------------------------------------------
# Fixtures: shapes that `npm audit --json` actually emits.
# --------------------------------------------------------------------------

fixture clean.json <<'JSON'
{
  "auditReportVersion": 2,
  "vulnerabilities": {},
  "metadata": {
    "vulnerabilities": { "info": 0, "low": 0, "moderate": 0, "high": 0, "critical": 0, "total": 0 }
  }
}
JSON

fixture medlow.json <<'JSON'
{
  "auditReportVersion": 2,
  "vulnerabilities": {
    "tmp": { "name": "tmp", "severity": "moderate", "range": "<=0.2.3", "fixAvailable": true },
    "brace-expansion": { "name": "brace-expansion", "severity": "low", "range": "1.0.0 - 1.1.11", "fixAvailable": true }
  },
  "metadata": {
    "vulnerabilities": { "info": 0, "low": 1, "moderate": 1, "high": 0, "critical": 0, "total": 2 }
  }
}
JSON

fixture high.json <<'JSON'
{
  "auditReportVersion": 2,
  "vulnerabilities": {
    "axios": { "name": "axios", "severity": "high", "range": "1.0.0 - 1.17.0", "fixAvailable": true }
  },
  "metadata": {
    "vulnerabilities": { "info": 0, "low": 0, "moderate": 0, "high": 1, "critical": 0, "total": 1 }
  }
}
JSON

fixture critical.json <<'JSON'
{
  "auditReportVersion": 2,
  "vulnerabilities": {
    "form-data": { "name": "form-data", "severity": "critical", "range": "<2.5.4", "fixAvailable": true }
  },
  "metadata": {
    "vulnerabilities": { "info": 0, "low": 0, "moderate": 0, "high": 0, "critical": 1, "total": 1 }
  }
}
JSON

fixture mixed.json <<'JSON'
{
  "auditReportVersion": 2,
  "vulnerabilities": {
    "axios": { "name": "axios", "severity": "high", "range": "1.0.0 - 1.17.0", "fixAvailable": true },
    "form-data": { "name": "form-data", "severity": "critical", "range": "<2.5.4", "fixAvailable": false },
    "tmp": { "name": "tmp", "severity": "moderate", "range": "<=0.2.3", "fixAvailable": true }
  },
  "metadata": {
    "vulnerabilities": { "info": 0, "low": 0, "moderate": 1, "high": 1, "critical": 1, "total": 3 }
  }
}
JSON

fixture npm-error.json <<'JSON'
{
  "error": {
    "code": "ENOLOCK",
    "summary": "This command requires an existing lockfile.",
    "detail": "Try creating one first with: npm i --package-lock-only"
  }
}
JSON

fixture garbage.txt <<'TXT'
npm error code E401
npm error Unable to authenticate, need: Basic realm="GitHub Package Registry"
TXT

: > "$WORK/empty.json"

# --------------------------------------------------------------------------
# Policy evaluation
# --------------------------------------------------------------------------

run_gate bash "$GATE" "$WORK/clean.json"
expect_status "clean report passes" 0
expect_contains "clean report says PASS" "PASS"

run_gate bash "$GATE" "$WORK/medlow.json"
expect_status "moderate+low are permitted by policy" 0
expect_contains "moderate+low still reported" "moderate"

run_gate bash "$GATE" "$WORK/high.json"
expect_status "HIGH blocks (ratified gate: HIGH+CRITICAL block)" 1
expect_contains "HIGH failure names the package" "axios"

run_gate bash "$GATE" "$WORK/critical.json"
expect_status "CRITICAL blocks" 1

run_gate bash "$GATE" "$WORK/mixed.json"
expect_status "mixed report blocks on the HIGH/CRITICAL portion" 1
expect_contains "mixed report counts criticals" "critical: 1"
expect_contains "mixed report counts highs" "high: 1"

# --------------------------------------------------------------------------
# Unusable audit output must NOT be silently reported as a pass.
# This is the failure mode `npm audit ... || true` would introduce.
# --------------------------------------------------------------------------

run_gate bash "$GATE" "$WORK/npm-error.json"
expect_status "npm error payload is a gate error, not a pass" 2
expect_contains "npm error payload surfaces npm's summary" "ENOLOCK"

run_gate bash "$GATE" "$WORK/garbage.txt"
expect_status "non-JSON output is a gate error, not a pass" 2

run_gate bash "$GATE" "$WORK/empty.json"
expect_status "empty output is a gate error, not a pass" 2

run_gate bash "$GATE" "$WORK/does-not-exist.json"
expect_status "missing report file is a gate error" 2

# --------------------------------------------------------------------------
# Regression: `npm audit` exits non-zero whenever it finds ANY vulnerability.
# The gate must evaluate the report anyway instead of dying on that exit code
# (the `bash -e` + command-substitution interaction that broke this workflow).
# --------------------------------------------------------------------------

make_npm_stub() {
  # make_npm_stub <fixture-file> <exit-code>
  mkdir -p "$WORK/bin"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'cat %q\n' "$1"
    printf 'exit %s\n' "$2"
  } > "$WORK/bin/npm"
  chmod +x "$WORK/bin/npm"
}

make_npm_stub "$WORK/medlow.json" 1
run_gate env PATH="$WORK/bin:$PATH" bash "$GATE"
expect_status "npm exit 1 on permitted findings still evaluates to a pass" 0
expect_contains "policy verdict was actually reached" "PASS"

make_npm_stub "$WORK/high.json" 1
run_gate env PATH="$WORK/bin:$PATH" bash "$GATE"
expect_status "npm exit 1 on a HIGH evaluates to a policy block" 1
expect_contains "block verdict was actually reached" "FAIL"

make_npm_stub "$WORK/clean.json" 0
run_gate env PATH="$WORK/bin:$PATH" bash "$GATE"
expect_status "npm exit 0 with a clean report passes" 0

make_npm_stub "$WORK/garbage.txt" 1
run_gate env PATH="$WORK/bin:$PATH" bash "$GATE"
expect_status "a broken npm audit run fails the gate rather than passing blind" 2

# The step body GitHub Actions generates runs under `bash -e`. Invoking the
# gate from such a shell must still reach a verdict.
make_npm_stub "$WORK/medlow.json" 1
run_gate env PATH="$WORK/bin:$PATH" bash -e -c "bash '$GATE'"
expect_status "gate is safe to call from a 'bash -e' step body" 0

# --------------------------------------------------------------------------
# Step summary side effect
# --------------------------------------------------------------------------

: > "$WORK/summary.md"
run_gate env GITHUB_STEP_SUMMARY="$WORK/summary.md" bash "$GATE" "$WORK/high.json"
expect_status "summary run still blocks on HIGH" 1
if grep -q "axios" "$WORK/summary.md"; then
  ok "writes the finding into GITHUB_STEP_SUMMARY"
else
  LAST_OUTPUT="$(cat "$WORK/summary.md")"
  ko "writes the finding into GITHUB_STEP_SUMMARY"
fi

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
