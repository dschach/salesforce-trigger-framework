#!/usr/bin/env bash
# Write a Markdown table of the violations in a Salesforce Code Analyzer JSON report.
#
# Usage: table.sh [results-file]
#
# Writes violations-table to $GITHUB_OUTPUT as a multi-line value, and prints the
# table to stdout. Rows sort by file name, then by line number within each file.
# A missing report, or one with no violations, gives the header row alone.

set -euo pipefail

file="${1:-sfca_results.json}"
out="${GITHUB_OUTPUT:-/dev/stdout}"
delimiter="SFCA_TABLE_EOF"

table=$(
	echo "| File | Line | Rule | Severity | Message |"
	echo "| ---- | ---- | ---- | -------- | ------- |"
	if [ -f "$file" ]; then
		jq -r '
			.violations
			| map(. as $v | ($v.locations[$v.primaryLocationIndex]) as $loc
				| { file: $loc.file, line: $loc.startLine, rule: $v.rule, severity: $v.severity, message: $v.message })
			| sort_by(.file, .line)
			| .[]
			| "| \(.file) | \(.line) | \(.rule) | \(.severity) | \(.message | gsub("\\|"; "\\|") | gsub("\n"; " ")) |"
		' "$file"
	fi
)

if [ "$out" = "/dev/stdout" ]; then
	echo "$table"
else
	{
		echo "violations-table<<$delimiter"
		echo "$table"
		echo "$delimiter"
	} >> "$out"
fi
