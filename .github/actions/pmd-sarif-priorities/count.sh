#!/usr/bin/env bash
# Count the violations in a PMD SARIF report by rule priority.
#
# Usage: count.sh [sarif-file]
#
# Writes priority1 to priority5 and total to $GITHUB_OUTPUT, and prints the same
# lines to stdout. A missing report counts as 0 violations, which is what PMD
# writes when it finds nothing on a pull request with no analyzable files.
#
# PMD's SARIF output lists each rule once under tool.driver.rules with the priority
# that the ruleset gave it, and each result names its rule by ruleId. The counts
# therefore follow the ruleset's priorities, not the rules' defaults.

set -euo pipefail

file="${1:-pmd-report.sarif}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

emit() {
	echo "$1=$2" >> "$out"
	if [ "$out" != "/dev/stdout" ]; then
		echo "$1=$2"
	fi
}

if [ ! -f "$file" ]; then
	echo "No SARIF report at $file; reporting 0 violations." >&2
	for p in 1 2 3 4 5; do
		emit "priority$p" 0
	done
	emit total 0
	exit 0
fi

counts=$(jq -r '
	.runs[0] as $run
	| ($run.tool.driver.rules // [] | map({ key: .id, value: (.properties.priority | tonumber) }) | from_entries) as $priorityOf
	| ($run.results // []) as $results
	| [range(1; 6) as $p | [$results[] | select($priorityOf[.ruleId] == $p)] | length] + [$results | length]
	| @tsv
' "$file")

read -r p1 p2 p3 p4 p5 total <<< "$counts"
emit priority1 "$p1"
emit priority2 "$p2"
emit priority3 "$p3"
emit priority4 "$p4"
emit priority5 "$p5"
emit total "$total"
