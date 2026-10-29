# SFCA results priorities

A composite action that reads the JSON report that the Salesforce Code Analyzer wrote and counts the violations by priority. The Code Analyzer action reports only a total, so a workflow that wants to fail on priority 1 and 2 violations and tolerate the rest needs these counts.

## Inputs

| Input          | Default            | Description                                         |
| -------------- | ------------------ | --------------------------------------------------- |
| `results-file` | `sfca_results.json` | Path to the JSON report that the Code Analyzer wrote. |

## Outputs

| Output      | Description                                       |
| ----------- | ------------------------------------------------- |
| `priority1` | Violations whose rule has priority 1 in the ruleset |
| `priority2` | Violations whose rule has priority 2              |
| `priority3` | Violations whose rule has priority 3              |
| `priority4` | Violations whose rule has priority 4              |
| `priority5` | Violations whose rule has priority 5              |
| `total`     | All violations in the report                      |
| `violations-table` | Markdown table of the violations with file, line, rule, severity, and message, ordered by file and then by line |

A missing report counts as 0 violations.

## Example

```yaml
- name: "Run Salesforce Code Analyzer"
  id: run-code-analyzer
  uses: forcedotcom/run-code-analyzer@v2
  with:
    run-arguments: --workspace . --view detail --output-file sfca_results.json --rule-selector "(pmd,cpd,sfge,regex):(Recommended,Custom)"
    github-token: ${{ github.token }}

- name: "Count SFCA violations by priority"
  id: priorities
  uses: ./.github/actions/parse-sfca-results

- name: "Fail on priority 1 and 2 SFCA violations"
  if: ${{ steps.priorities.outputs.priority1 != 0 || steps.priorities.outputs.priority2 != 0 }}
  run: exit 1
```

## Notes

- The counts come from the report's `violationCounts`, which holds the count for each severity. A severity is the priority the ruleset gave the rule.
- The script `count.sh` runs on its own for a local check: `bash count.sh sfca_results.json`.
- Only `jq` and `bash` are needed, and both are on every GitHub-hosted runner.
