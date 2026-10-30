# Salesforce Code Analyzer Report

This composite action reads the JSON report of Salesforce Code Analyzer and counts the violations by severity. It writes the counts and Markdown tables to the job summary. A workflow needs these counts and tables to fail on high-priority violations and to accept the other violations.

The action never fails the job because of a violation. The next step of the caller reads the counts and fails the job, as the `sfca-analysis` job in `ci.yml` does.

## Inputs

| Input             | Required | Default | Description                                                                                                                                                                                                                                |
| ----------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `results-path`    | Yes      |         | The path to the JSON results file of Salesforce Code Analyzer, for example `sfca_results.json`. The action fails if the file does not exist.                                                                                               |
| `severity-cutoff` | No       |         | The violations with a severity at or below this value go in the first (high-priority) table. The other severities go in the second table. When the value is empty, null, or 5, all violations go in 1 table, and there is no second table. |
| `write-summary`   | No       | `true`  | `true` writes the counts and the tables to the job summary. `false` writes nothing there and gives the tables only as outputs, for a caller that writes its own summary.                                                                   |

## Outputs

| Output                   | Description                                                                                  |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| `total-violations`       | The total number of violations                                                               |
| `sev1-count`             | The number of severity 1 violations                                                          |
| `sev2-count`             | The number of severity 2 violations                                                          |
| `sev3-count`             | The number of severity 3 violations                                                          |
| `sev4-count`             | The number of severity 4 violations                                                          |
| `sev5-count`             | The number of severity 5 violations                                                          |
| `high-priority-markdown` | A Markdown table from severity 1 to the cutoff, or of all violations when there is no cutoff |
| `low-priority-markdown`  | A Markdown table from the cutoff plus 1 to severity 5. It is empty when there is no cutoff.  |

Each table has the columns File, Line, Rule, Description, Severity, and Engine. A File cell links to the file at the commit that ran, on the line of the violation, and opens in a new tab. A table with no violations shows a line that says so.

With a cutoff, the job summary has 2 tables. The first table is "Violations at Severity 1 to" the cutoff. The second table is "Violations at Severity" the cutoff plus 1 "to 5". With no cutoff, the job summary has 1 table, "All Violations".

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

- name: "Fail on severity 1 and 2 SFCA violations"
  if: ${{ steps.sfca-report.outputs.sev1-count != 0 || steps.sfca-report.outputs.sev2-count != 0 }}
  run: exit 1
```

## Notes

- The counts come from `violationCounts` in the report, which holds the count for each severity. `code-analyzer.yml` sets the severity of each rule. It can differ from the priority of the rule in the ruleset.
- The File cell leaves out the folders that all files in the report start with. So `delta/force-app/main/default/classes/Foo.cls` shows as `classes/Foo.cls`. A report of 1 file shows only its name.
- The example expects that the job installed the Salesforce CLI and the `code-analyzer` plugin, as the `sfca-analysis` job in `ci.yml` does. `if: always()` writes the summary also when the scan step fails.
- The action needs `jq`, and each GitHub-hosted runner has it.
- When the caller writes its own summary, set `write-summary` to `false`, and use the `high-priority-markdown` and `low-priority-markdown` outputs.
