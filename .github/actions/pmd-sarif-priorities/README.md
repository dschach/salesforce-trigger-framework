# PMD SARIF priorities

A composite action that reads the SARIF report PMD wrote and counts the violations by rule priority. The PMD GitHub Action reports only a total, so a workflow that wants to fail on priority 1 and 2 violations and tolerate the rest needs these counts.

## Inputs

| Input        | Default            | Description                              |
| ------------ | ------------------ | ---------------------------------------- |
| `sarif-file` | `pmd-report.sarif` | Path to the SARIF report that PMD wrote. |

## Outputs

| Output      | Description                                         |
| ----------- | --------------------------------------------------- |
| `priority1` | Violations whose rule has priority 1 in the ruleset |
| `priority2` | Violations whose rule has priority 2                |
| `priority3` | Violations whose rule has priority 3                |
| `priority4` | Violations whose rule has priority 4                |
| `priority5` | Violations whose rule has priority 5                |
| `total`     | All violations in the report                        |

A missing report counts as 0 violations.

## Example

```yaml
- name: "Run PMD scan"
  id: pmd
  uses: pmd/pmd-github-action@v2
  with:
    version: "latest"
    sourcePath: "."
    rulesets: "pmd/ruleset.xml"

- name: "Count PMD violations by priority"
  id: priorities
  uses: ./.github/actions/pmd-sarif-priorities

- name: "Fail on priority 1 and 2 PMD violations"
  if: ${{ steps.priorities.outputs.priority1 != 0 || steps.priorities.outputs.priority2 != 0 }}
  run: exit 1
```

## Notes

- The counts follow the priorities in the ruleset, because PMD writes the ruleset's priority into each SARIF rule.
- The script `count.sh` runs on its own for a local check: `bash count.sh pmd-report.sarif`.
- Only `jq` and `bash` are needed, and both are on every GitHub-hosted runner.
