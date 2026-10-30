# PMD Rules for Code Analyzer

`code-analyzer.yml` at the root of the repository loads these files. Code Analyzer reads the rule severities from `code-analyzer.yml`, not from the priorities in the rulesets.

| File                        | What it holds                                                                                   |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| `pmd-stock-rules.xml`       | The stock PMD rules that this project uses, with their properties                               |
| `pmd-custom-rules-apex.xml` | The custom XPath rules for Apex                                                                 |
| `pmd-java-rules-1.0.0.jar`  | The custom Java rules, with their ruleset `rulesets/devsecops-java.xml` in the jar              |
| `THIRD_PARTY_LICENSES.md`   | The license of the Salesforce code that 1 rule in the jar adapts. It must stay next to the jar. |
| `ruleset.xml`               | All XML rulesets in 1 file, for a run of PMD alone. Code Analyzer does not read it.             |

## The Java Rules

The jar holds 4 rules that XPath cannot express. They read the access mode of a DML statement, or a file other than the file that PMD checks:

| Rule                               | Severity | What it reports                                                           |
| ---------------------------------- | -------- | ------------------------------------------------------------------------- |
| `FlagSystemMode`                   | 2        | Each database operation in system mode, also in test classes              |
| `RequireAccessMode`                | 2        | A database operation that does not state its access mode                  |
| `NoCredentialNamedField`           | 2        | A custom field with a name that suggests a credential, on any object      |
| `RequireInvocableNoArgConstructor` | 1        | From API 66.0, an invocable class with no visible no-argument constructor |

`code-analyzer.yml` adds the jar with `java_classpath_entries` and loads its ruleset by the resource name `rulesets/devsecops-java.xml`.

## Rebuild the Jar

The source is the Maven project `docs/samples/pmd-java-rules` in the DevSecOps standards repository. This jar was built from its `main` branch at commit `5cdf667`, and the build ran all 21 rule tests.

1. Copy `docs/samples/pmd-java-rules` from the DevSecOps repository to a folder of its own.
2. In that folder, run `mvn package`. The build runs the tests and writes `target/pmd-java-rules-1.0.0.jar`.
3. Copy the jar to this folder, and copy `THIRD_PARTY_LICENSES.md` with it.

The `pmd.version` in the `pom.xml` of the project must match the PMD version in Code Analyzer: PMD 7.26.0 in Code Analyzer 5.16.0. CI installs the latest Code Analyzer, so rebuild the jar when Code Analyzer uses a new PMD version.
