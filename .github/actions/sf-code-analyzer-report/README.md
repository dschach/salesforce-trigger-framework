# Salesforce Code Analyzer report

A composite action that reads the JSON report that the Salesforce Code Analyzer wrote, counts the violations by severity, and writes the counts and Markdown tables to the job summary. A workflow that wants to fail on high-priority violations and tolerate the rest needs these counts and the tables that show them.

The action never fails the job because of a violation. The caller's next step reads the counts and fails the job, as the `sfca-analysis` job in `ci.yml` does.

## Inputs

| Input             | Required | Default | Description                                                                                                                                                                                                                             |
| ----------------- | -------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `results-path`    | Yes      |         | Path to the Salesforce Code Analyzer results JSON file, for example `sfca_results.json`. The action fails if the file does not exist.                                                                                                   |
| `severity-cutoff` | No       |         | Violations with a severity at or below this value go in the first (high-priority) table. The remaining severities go in the second table. When it is empty, null, or 5, every violation goes in one table and there is no second table. |
| `write-summary`   | No       | `true`  | `true` writes the counts and the tables to the job summary. `false` writes nothing there and gives the tables as outputs only, for a caller that writes its own summary.                                                                |

## Outputs

| Output                   | Description                                                                              |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| `total-violations`       | Total number of violations found                                                         |
| `sev1-count`             | Number of severity 1 violations                                                          |
| `sev2-count`             | Number of severity 2 violations                                                          |
| `sev3-count`             | Number of severity 3 violations                                                          |
| `sev4-count`             | Number of severity 4 violations                                                          |
| `sev5-count`             | Number of severity 5 violations                                                          |
| `high-priority-markdown` | Markdown table from severity 1 to the cutoff, or every violation when there is no cutoff |
| `low-priority-markdown`  | Markdown table from the cutoff plus 1 to severity 5, empty when there is no cutoff       |

Each table has the columns File, Line, Rule, Description, Severity, and Engine. A File cell links to the file at the commit that ran, on the line of the violation, and opens in a new tab. A table with no violations shows a line that says so.

With a cutoff, the job summary has two tables, "Violations at Severity 1 to" the cutoff and "Violations at Severity" the cutoff plus 1 "to 5". With no cutoff, it has one table, "All Violations".

## Example

```yaml
- name: "Run Salesforce Code Analyzer"
  run: |
    mkdir -p sfca
    sf code-analyzer run --workspace . --output-file sfca/sfca_results.json --rule-selector "(pmd,cpd,sfge,regex):(Recommended,Custom)"

- name: "Report SFCA violations"
  if: always()
  id: sfca-report
  uses: ./.github/actions/sf-code-analyzer-report
  with:
    results-path: "sfca/sfca_results.json"
    severity-cutoff: "2"

- name: "Fail on priority 1 and 2 SFCA violations"
  if: ${{ steps.sfca-report.outputs.sev1-count != 0 || steps.sfca-report.outputs.sev2-count != 0 }}
  run: exit 1
```

## Notes

- The counts come from the report's `violationCounts`, which holds the count for each severity. A severity is the priority the ruleset gave the rule.
- The File cell drops the folders that every file in the report starts with, so `delta/force-app/main/default/classes/Foo.cls` shows as `classes/Foo.cls`. A report of one file shows only its name.
- The example assumes that the job installed the Salesforce CLI and the `code-analyzer` plugin, as the `sfca-analysis` job in `ci.yml` does. `if: always()` writes the summary even when the scan step fails.
- The action needs `jq`, which is on every GitHub-hosted runner.
- Set `write-summary` to `false` when the caller writes its own summary, and use the `high-priority-markdown` and `low-priority-markdown` outputs instead.
