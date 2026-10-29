# SFCA results priorities

A composite action that reads the JSON report that the Salesforce Code Analyzer wrote, counts the violations by priority, and builds a Markdown table of them. A workflow that wants to fail on priority 1 and 2 violations and tolerate the rest needs these counts.

CI in this repository does not call this action. It calls [`sf-code-analyzer-report`](../sf-code-analyzer-report/README.md), which also writes the job summary.

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
  run: |
    mkdir -p sfca
    sf code-analyzer run --workspace . --output-file sfca/sfca_results.json --rule-selector "(pmd,cpd,sfge,regex):(Recommended,Custom)"

- name: "Count SFCA violations by priority"
  id: priorities
  uses: ./.github/actions/parse-sfca-results
  with:
    results-file: sfca/sfca_results.json

- name: "Fail on priority 1 and 2 SFCA violations"
  if: ${{ steps.priorities.outputs.priority1 != 0 || steps.priorities.outputs.priority2 != 0 }}
  run: exit 1
```

## Notes

- The counts come from the report's `violationCounts`, which holds the count for each severity. A severity is the priority the ruleset gave the rule.
- The script `count.sh` makes the counts, and `table.sh` makes the `violations-table` output. Both run on their own for a local check, for example `bash count.sh sfca/sfca_results.json`.
- The example assumes that the job installed the Salesforce CLI and the `code-analyzer` plugin, as the `sfca-analysis` job in `ci.yml` does.
- Only `jq` and `bash` are needed, and both are on every GitHub-hosted runner.
