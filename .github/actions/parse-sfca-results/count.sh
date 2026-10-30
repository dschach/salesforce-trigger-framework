#!/usr/bin/env bash
# Count the violations in a Salesforce Code Analyzer JSON report by severity.
#
# Usage: count.sh [results-file]
#
# Writes priority1 to priority5 and total to $GITHUB_OUTPUT, and prints the same
# lines to stdout. A missing report counts as 0 violations, which is what the
# Code Analyzer writes when it finds nothing on a pull request with no analyzable
# files.
#
# The report's violationCounts object holds the count for each severity, 1 to 5.
# code-analyzer.yml sets the severity of each rule, so it can differ from the priority
# in the ruleset. The output names say priority, but each count is of a severity.

set -euo pipefail

file="${1:-sfca_results.json}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

emit() {
  echo "$1=$2" >> "$out"
  if [ "$out" != "/dev/stdout" ]; then
    echo "$1=$2"
  fi
}

if [ ! -f "$file" ]; then
  echo "No JSON report at $file; reporting 0 violations." >&2
  for p in 1 2 3 4 5; do
    emit "priority$p" 0
  done
  emit total 0
  exit 0
fi

counts=$(jq -r '.violationCounts | [.sev1, .sev2, .sev3, .sev4, .sev5, .total] | @tsv' "$file")

read -r p1 p2 p3 p4 p5 total <<< "$counts"
emit priority1 "$p1"
emit priority2 "$p2"
emit priority3 "$p3"
emit priority4 "$p4"
emit priority5 "$p5"
emit total "$total"
