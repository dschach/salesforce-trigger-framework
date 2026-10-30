# Contributing

Thanks for helping with the Salesforce Trigger Framework. This guide covers how to set up the project, how to test a change, and how a change gets merged.

## Before you start

Open an issue before you start a change, so that we can agree on the approach and avoid duplicate work. Use the bug report or feature request form.

The framework is on its version 1 line, so a change must not alter an existing public method or behavior. A change that would break existing handlers waits for the next major version. Say in the issue if you think your change is one of those.

## Set up the project

You need:

- Node.js at the version in the `engines` field of `package.json`
- The [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) and its `code-analyzer` plugin
- A Dev Hub org, for scratch orgs

Then:

```bash
git clone https://github.com/dschach/salesforce-trigger-framework
cd salesforce-trigger-framework
npm ci
sf plugins install code-analyzer
```

`npm ci` installs Prettier and its plugins, and it installs the commit hook that formats the files you stage.

## Project layout

| Path                   | What it holds                                                                                                                         |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `force-app/`           | The framework: `TriggerHandler` and its test. This is the only package directory, so it is all that a deploy of the project installs. |
| `sample-handler/`      | A sample trigger, handler, and test. It is not a package directory; deploy it with `--source-dir sample-handler`.                     |
| `config/`              | The scratch org definition, and the PMD rulesets in `config/pmd/`.                                                                    |
| `code-analyzer.yml`    | The Salesforce Code Analyzer configuration that CI uses.                                                                              |
| `scripts/`             | Helper scripts, run through the npm scripts below.                                                                                    |
| `docs/`, `doc-assets/` | The generated documentation site and its assets. Do not edit `docs/` by hand.                                                         |

## Make and test a change

1. Create a branch named `<type>/<short-topic>`, for example `fix/bypass-case`.
2. Create a scratch org and deploy the framework and the sample. `bash scripts/orginit.sh` does all of it, but it first deletes the scratch org with the alias `TriggerFramework`. Or step by step:

   ```bash
   sf org create scratch --definition-file config/project-scratch-def.json --alias my-scratch --duration-days 1
   sf project deploy start --source-dir force-app --source-dir sample-handler --target-org my-scratch
   ```

3. Run every Apex test with coverage:

   ```bash
   sf apex run test --test-level RunLocalTests --code-coverage --result-format human --target-org my-scratch --wait 20
   ```

   Coverage of `TriggerHandler` is 100 percent today, so a change needs tests that keep it there.

4. Check formatting and static analysis:

   ```bash
   npm run prettier:verify
   npm run codeanalyzer:run
   ```

   CI fails a pull request on any Code Analyzer violation at severity 1 or 2.

## Code standards

- Classes and triggers use the API version in `sfdx-project.json`, and every class declares its sharing.
- Every database operation in the sample and in the README states its access mode. Handler examples use system mode, `WITH SYSTEM_MODE` or `AccessLevel.SYSTEM_MODE`, as the README section on data access explains.
- Code Analyzer reports every system-mode operation with the rule `FlagSystemMode` at severity 2, which fails CI. When system mode is deliberate, suppress the rule on the method or the class with `@SuppressWarnings('PMD.FlagSystemMode')`, and give the reason in its ApexDoc. A reviewer accepts or rejects each suppression.
- Every public method has an ApexDoc comment, and every sentence in it ends with a period.
- A method that can throw has an `@exception` tag, followed by the same line with a `@throws` tag. The documentation generator reads `@exception`.
- Every `@example` in an ApexDoc comment, and every Apex block in the README, must compile.

## Commits and pull requests

- Write commit messages and pull request titles as [Conventional Commits](https://www.conventionalcommits.org/) with a scope, starting with a lower-case verb: `fix(handler): guard null arguments`.
- Pull requests merge by squash only. The pull request title becomes the commit message on `main`, and the description becomes its body, so fill in every section of the pull request template.
- Do not put version numbers in titles or descriptions. Release Please sets the version and writes the changelog from the commit messages.
- 2 checks must pass before a merge: `format-lint` (Prettier) and `sfca-analysis` (Code Analyzer). The `scratch-org-test` check runs the Apex tests when Apex or project metadata changes. It needs the project's Dev Hub secret, so it does not run on a pull request from a fork.

## npm scripts

| Script                       | What it does                                                                                                                                                                                                                                        |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run prettier`           | Formats every file Prettier can parse.                                                                                                                                                                                                              |
| `npm run prettier:verify`    | Checks formatting, as CI does.                                                                                                                                                                                                                      |
| `npm run prettier:docs`      | Formats only the HTML pages in `docs/` and `doc-assets/`. `npm run prettier` formats them too.                                                                                                                                                      |
| `npm run codeanalyzer:run`   | Runs Code Analyzer with the Recommended and Custom rules, as CI does, and writes the results to `sfca/`.                                                                                                                                            |
| `npm run codeanalyzer:setup` | Rewrites `code-analyzer.yml` with every rule and its settings, removes the paths from your machine that the config command writes in comments, and formats the file. The pre-commit hook removes those paths from a staged `code-analyzer.yml` too. |
| `npm run orginit`            | Runs `scripts/orginit.sh`: replaces the `TriggerFramework` scratch org and deploys everything.                                                                                                                                                      |
| `npm run prune`              | Deletes local branches whose remote branch is gone.                                                                                                                                                                                                 |
| `npm run prepareApexDox`     | Refreshes `highlight.js` and the documentation pages built from the README, the changelog, DEPLOY.md, and the sample README.                                                                                                                        |

## Update the documentation site

The site in `docs/` is generated from the ApexDoc comments with the ApexDox extension for Visual Studio Code. After a release, on `main`:

1. Run `npm run prepareApexDox`.
2. In Visual Studio Code, run the command `ApexDox: Run`. It reads `apexdox.yml`.
3. Run `npm run prettier`. It formats the generated HTML pages with the other files.
4. Commit the result as `docs(apexdox): regenerate the documentation`.
