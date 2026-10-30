# SFCA Results Priorities

This composite action reads the JSON report of Salesforce Code Analyzer, counts the violations by priority, and makes a Markdown table of them. A workflow needs these counts to fail on priority 1 and 2 violations and to accept the other violations.

CI in this repository does not call this action. It calls [`sf-code-analyzer-report`](../sf-code-analyzer-report/README.md), which also writes the job summary.

## Inputs

| Input          | Default             | Description                                   |
| -------------- | ------------------- | --------------------------------------------- |
| `results-file` | `sfca_results.json` | The path to the JSON report of Code Analyzer. |

## Outputs

| Output             | Description                                                                                                          |
| ------------------ | -------------------------------------------------------------------------------------------------------------------- |
| `priority1`        | The number of violations whose rule has priority 1 in the ruleset                                                    |
| `priority2`        | The number of violations whose rule has priority 2                                                                   |
| `priority3`        | The number of violations whose rule has priority 3                                                                   |
| `priority4`        | The number of violations whose rule has priority 4                                                                   |
| `priority5`        | The number of violations whose rule has priority 5                                                                   |
| `total`            | The number of all violations in the report                                                                           |
| `violations-table` | A Markdown table of the violations with the file, line, rule, severity, and message, sorted by file and then by line |

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

- The counts come from `violationCounts` in the report, which holds the count for each severity. A severity is the priority that the ruleset gave the rule.
- The script `count.sh` makes the counts, and `table.sh` makes the `violations-table` output. You can run each script alone for a local check, for example `bash count.sh sfca/sfca_results.json`.
- The example expects that the job installed the Salesforce CLI and the `code-analyzer` plugin, as the `sfca-analysis` job in `ci.yml` does.
- The action needs only `jq` and `bash`, and each GitHub-hosted runner has both.
