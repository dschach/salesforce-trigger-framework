# PMD rules for Code Analyzer

`code-analyzer.yml` at the repository root loads these files. Code Analyzer reads its rule severities from `code-analyzer.yml`, not from the priorities in the rulesets.

| File                        | What it holds                                                                                   |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| `pmd-stock-rules.xml`       | The stock PMD rules this project uses, with their properties                                    |
| `pmd-custom-rules-apex.xml` | The custom XPath rules for Apex                                                                 |
| `pmd-java-rules-1.0.0.jar`  | The custom Java rules, with their ruleset `rulesets/devsecops-java.xml` inside the jar          |
| `THIRD_PARTY_LICENSES.md`   | The licence of the Salesforce code that 1 rule in the jar adapts. It must stay next to the jar. |
| `ruleset.xml`               | All the XML rulesets in 1 file, for a run of PMD by itself. Code Analyzer does not read it.     |

## The Java rules

The jar holds 4 rules that XPath cannot express, because they read the access mode of a DML statement or a file other than the one PMD checks:

| Rule                               | Severity | What it reports                                                           |
| ---------------------------------- | -------- | ------------------------------------------------------------------------- |
| `FlagSystemMode`                   | 2        | Every database operation in system mode, test classes included            |
| `RequireAccessMode`                | 2        | A database operation that does not state its access mode                  |
| `NoCredentialNamedField`           | 2        | A custom field whose name suggests a credential, on any object            |
| `RequireInvocableNoArgConstructor` | 1        | From API 66.0, an invocable class with no visible no-argument constructor |

`code-analyzer.yml` adds the jar with `java_classpath_entries` and loads its ruleset by the resource name `rulesets/devsecops-java.xml`.

## Rebuild the jar

The source is the Maven project `docs/samples/pmd-java-rules` in the DevSecOps standards repository. This jar was built from its `main` branch at commit `5cdf667`, and the build ran all 21 rule tests.

1. Copy `docs/samples/pmd-java-rules` from the DevSecOps repository to a folder of its own.
2. In that folder, run `mvn package`. The build runs the tests and writes `target/pmd-java-rules-1.0.0.jar`.
3. Copy the jar to this folder, and copy `THIRD_PARTY_LICENSES.md` with it.

The `pmd.version` in the project's `pom.xml` must match the PMD version that Code Analyzer bundles: PMD 7.26.0 in Code Analyzer 5.16.0. CI installs the latest Code Analyzer, so rebuild the jar when Code Analyzer moves to a new PMD version.
