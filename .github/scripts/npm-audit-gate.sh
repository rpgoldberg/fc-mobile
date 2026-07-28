#!/usr/bin/env bash
#
# Evaluate an `npm audit` report against the ratified FC severity gate:
#
#   CRITICAL, HIGH  -> block (remediate the dependency, do not loosen the gate)
#   MODERATE, LOW   -> reported, permitted
#
# Usage:
#   npm-audit-gate.sh                 run `npm audit --json --omit=dev` here
#   npm-audit-gate.sh <report.json>   evaluate a saved report
#   npm-audit-gate.sh -               read a report from stdin
#
# Exit codes:
#   0  no blocking findings
#   1  policy violation (at least one HIGH or CRITICAL)
#   2  the gate could not evaluate (audit did not produce a usable report)
#
# `npm audit` exits non-zero whenever it finds ANY vulnerability, including
# severities this policy permits. That exit code therefore carries no policy
# meaning and must not be allowed to decide the step -- which is exactly what
# happened while this ran inline under Actions' default `bash -e` shell. It is
# captured and ignored here; the verdict comes from the report contents. The
# report is validated first so that a genuinely broken audit run fails loudly
# (exit 2) instead of being mistaken for a clean scan.

set -uo pipefail

SOURCE="${1-}"
NPM_STDERR=""
report=""

die_unusable() {
  printf 'GATE ERROR: %s\n' "$1" >&2
  if [ -n "$NPM_STDERR" ]; then
    printf 'npm stderr:\n%s\n' "$NPM_STDERR" >&2
  fi
  if [ -n "${report}" ]; then
    printf 'first 20 lines of what the audit produced:\n' >&2
    printf '%s\n' "$report" | head -20 >&2
  fi
  exit 2
}

command -v jq >/dev/null 2>&1 || die_unusable "jq is required but not installed"

# ---------------------------------------------------------------- acquire ---
if [ -z "$SOURCE" ]; then
  command -v npm >/dev/null 2>&1 || die_unusable "npm is required but not installed"
  stderr_file="$(mktemp)"
  trap 'rm -f "$stderr_file"' EXIT
  report="$(npm audit --json --omit=dev 2>"$stderr_file")"
  npm_status=$?
  NPM_STDERR="$(cat "$stderr_file")"
  printf 'npm audit --json --omit=dev exited %s (ignored; verdict comes from the report)\n' "$npm_status"
elif [ "$SOURCE" = "-" ]; then
  report="$(cat)"
else
  [ -f "$SOURCE" ] || die_unusable "report file not found: $SOURCE"
  report="$(cat "$SOURCE")"
fi

# --------------------------------------------------------------- validate ---
[ -n "${report//[[:space:]]/}" ] || die_unusable "audit produced no output"

printf '%s' "$report" | jq -e . >/dev/null 2>&1 ||
  die_unusable "audit output is not valid JSON"

npm_error="$(printf '%s' "$report" | jq -r '.error // empty | "\(.code // "?"): \(.summary // "no summary")"')"
if [ -n "$npm_error" ]; then
  die_unusable "npm audit reported an error: $npm_error"
fi

printf '%s' "$report" | jq -e '.metadata.vulnerabilities | objects' >/dev/null 2>&1 ||
  die_unusable "audit output has no .metadata.vulnerabilities block"

counts="$(printf '%s' "$report" | jq -r '
  .metadata.vulnerabilities as $v
  | ["critical","high","moderate","low","info"]
  | map("\(.): \($v[.] // 0)")
  | join("  ")
')"

critical="$(printf '%s' "$report" | jq -r '.metadata.vulnerabilities.critical // 0')"
high="$(printf '%s' "$report" | jq -r '.metadata.vulnerabilities.high // 0')"

case "$critical$high" in
  *[!0-9]*) die_unusable "vulnerability counts are not numeric (critical=$critical high=$high)" ;;
esac

# ----------------------------------------------------------------- report ---
list_findings() {
  # list_findings <severity-filter-expr>
  printf '%s' "$report" | jq -r --argjson wanted "$1" '
    (.vulnerabilities // {})
    | to_entries
    | map(select(.value.severity as $s | $wanted | index($s)))
    | sort_by(.key)
    | .[]
    | "  - \(.value.severity | ascii_upcase) \(.key) \(.value.range // "?") [fix: " +
      (if (.value.fixAvailable == false) then "none available"
       elif ((.value.fixAvailable | type) == "object")
         then "\(.value.fixAvailable.name)@\(.value.fixAvailable.version)"
       else "available" end) + "]"
  '
}

blocking="$(list_findings '["critical","high"]')"
permitted="$(list_findings '["moderate","low","info"]')"

printf 'npm audit severity counts: %s\n' "$counts"
printf 'policy: CRITICAL and HIGH block; MODERATE and LOW are permitted\n'

if [ -n "$permitted" ]; then
  printf '\npermitted findings (reported, not blocking):\n%s\n' "$permitted"
fi

if [ -n "$blocking" ]; then
  printf '\nblocking findings:\n%s\n' "$blocking"
fi

# ------------------------------------------------------------ summary out ---
if [ -n "${GITHUB_STEP_SUMMARY-}" ]; then
  {
    printf '## Dependency vulnerability gate\n\n'
    printf '`%s`\n\n' "$counts"
    printf 'Policy: **CRITICAL and HIGH block**, MODERATE and LOW are permitted.\n\n'
    if [ -n "$blocking" ]; then
      printf '### Blocking findings\n\n```\n%s\n```\n\n' "$blocking"
    fi
    if [ -n "$permitted" ]; then
      printf '### Permitted findings\n\n```\n%s\n```\n\n' "$permitted"
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

# ---------------------------------------------------------------- verdict ---
if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
  printf '\nGATE FAIL: %s critical + %s high finding(s) violate the security gate policy.\n' "$critical" "$high"
  printf 'Remediate by bumping the affected dependency. Do not relax the gate.\n'
  exit 1
fi

printf '\nGATE PASS: no CRITICAL or HIGH findings.\n'
exit 0
