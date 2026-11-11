# Contributing

Thank you for your help with the Salesforce Trigger Framework. This guide tells how to set up the project, how to test a change, and how a change is merged.

## Before You Start

Open an issue before you start a change. Then we can agree on the approach, and nobody does the same work twice. Use the bug report form or the feature request form.

A change must not alter an existing public method or its behavior, because that breaks existing handlers. Such a change waits for the next major version. If you think that your change is one of those, say so in the issue.

## Set Up the Project

You need:

- Node.js at the version in the `engines` field of `package.json`
- The [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) and its `code-analyzer` plugin
- A Dev Hub org, for scratch orgs
- A Java runtime, at version 11 or later, for the PMD and graph engines of Code Analyzer

Then run:

```bash
git clone https://github.com/dschach/salesforce-trigger-framework
cd salesforce-trigger-framework
npm ci
sf plugins install code-analyzer
```

`npm ci` installs Prettier and its plugins. It also installs the commit hook, which formats the files that you stage and updates the table of contents of each staged markdown file. When you stage a file of the sample, the hook also copies the sample trigger and handler into `sample-handler/README.md`.

## Project Layout

| Path                   | What it holds                                                                                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `force-app/`           | The framework: `TriggerHandler`, its tests, and the `BypassTriggerHandlers` custom permission. It is the only package directory, so a deploy of the project installs only it. |
| `sample-handler/`      | A sample trigger, handler, and test. It is not a package directory. Deploy it with `--source-dir sample-handler`.                                                             |
| `config/`              | The scratch org definition, and the PMD rulesets in `config/pmd/`.                                                                                                            |
| `code-analyzer.yml`    | The Salesforce Code Analyzer configuration that CI uses.                                                                                                                      |
| `scripts/`             | Helper scripts. The npm scripts below run them.                                                                                                                               |
| `docs/`, `doc-assets/` | The generated documentation site and its assets. Do not edit `docs/` by hand.                                                                                                 |

## Make and Test a Change

1. Create a branch named `<type>/<short-topic>`, for example `fix/bypass-case`.
2. Create a scratch org, and deploy the framework and the sample. `bash scripts/orginit.sh` does all of it, but it first deletes the scratch org with the alias `TriggerFramework`. Or do it step by step:

   ```bash
   sf org create scratch --definition-file config/project-scratch-def.json --alias my-scratch --duration-days 1
   sf project deploy start --source-dir force-app --source-dir sample-handler --target-org my-scratch
   ```

3. Run all Apex tests with coverage:

   ```bash
   sf apex run test --test-level RunLocalTests --code-coverage --result-format human --target-org my-scratch --wait 20
   ```

   The coverage of `TriggerHandler` is 100 percent. A change needs tests that keep it at 100 percent.

4. Check the formatting and the static analysis:

   ```bash
   npm run prettier:verify
   npm run codeanalyzer:run
   node scripts/sync-sample-code.mjs --check
   ```

   The last command checks that `sample-handler/README.md` shows the current sample code. The commit hook keeps it current, so it fails only after a commit without the hook.

   CI fails a pull request on each Code Analyzer violation at severity 1 or 2.

## Code Standards

- Classes and triggers use the API version in `sfdx-project.json`, and each class declares its sharing.
- Each database operation in the sample and in the README states its access mode. The handler examples use system mode, `WITH SYSTEM_MODE` or `AccessLevel.SYSTEM_MODE`. The README section Data Access tells why.
- Code Analyzer reports each system-mode operation with the rule `FlagSystemMode` at severity 2, which fails CI. When system mode is necessary, suppress the rule on the method or the class with `@SuppressWarnings('PMD.FlagSystemMode')`, and give the reason in its ApexDoc. A reviewer accepts or rejects each suppression.
- Each public method has an ApexDoc comment. Write ApexDoc in simplified technical English: short sentences, the active voice, and plain words. Each sentence ends with a period.
- A method that can throw has an `@exception` tag, followed by the same line with a `@throws` tag. The documentation generator reads `@exception`.
- Each `@example` in an ApexDoc comment, and each Apex block in the README, must compile.
- Do not remove a public member. Mark it with a `@deprecated` ApexDoc tag that names its replacement. A later major release removes it. Private and test-visible members can be removed.

## Commits and Pull Requests

- Write commit messages and pull request titles as [Conventional Commits](https://www.conventionalcommits.org/) with a scope, and start them with a lower-case verb: `fix(handler): guard null arguments`.
- Pull requests merge by squash only. The pull request title becomes the commit message on `main`, and the description becomes its body. So fill in each section of the pull request template.
- Do not put version numbers in titles or descriptions. Release Please sets the version and writes the changelog from the commit messages. After a push to `main`, it runs only when `format-lint` and `sfca-analysis` pass, so a failing push gets no release pull request update until a fix lands.
- 3 checks must pass before a merge: `format-lint` (Prettier and the sample code check), `sfca-analysis` (Code Analyzer), and `package-ids`. `package-ids` runs only on the release pull request, and the release pull request skips `sfca-analysis`, because it changes no Apex. A skipped check counts as passed. The `scratch-org-test` check runs the Apex tests when a file in `force-app/` or `sample-handler/` changes, except a markdown file. It needs the Dev Hub secret of the project, so it does not run on a pull request from a fork.

## npm Scripts

| Script                       | What it does                                                                                                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run prettier`           | Formats all files that Prettier can parse.                                                                                                                                                                                      |
| `npm run prettier:verify`    | Checks the formatting, as CI does.                                                                                                                                                                                              |
| `npm run prettier:docs`      | Formats only the HTML pages in `docs/` and `doc-assets/`. `npm run prettier` formats them too.                                                                                                                                  |
| `npm run codeanalyzer:run`   | Runs Code Analyzer with the Recommended and Custom rules, as CI does, and writes the results to `sfca/`.                                                                                                                        |
| `npm run codeanalyzer:setup` | Writes `code-analyzer.yml` again with all rules and their settings, removes the paths of your computer from its comments, and formats the file. The pre-commit hook also removes those paths from a staged `code-analyzer.yml`. |
| `npm run orginit`            | Runs `scripts/orginit.sh`: replaces the `TriggerFramework` scratch org and deploys everything.                                                                                                                                  |
| `npm run prune`              | Deletes the local branches whose remote branch is gone.                                                                                                                                                                         |
| `npm run prepareApexDox`     | Updates `highlight.js` and the documentation pages that come from the README, the changelog, DEPLOY.md, and the sample README. It draws the Mermaid diagrams of the README as SVG for the site.                                 |

## Update the Documentation Site

ApexDox, an extension for Visual Studio Code, generates the site in `docs/` from the ApexDoc comments. Update the site in its own pull request before a release pull request merges:

1. Create a branch from `main`.
2. Run `npm run prepareApexDox`. It draws the Mermaid diagrams of the README with the Mermaid command line, which `npx` downloads on the first run. The command line needs Google Chrome, or the path of another Chrome in `PUPPETEER_EXECUTABLE_PATH`.
3. In Visual Studio Code, run the command `ApexDox: Run`. It reads `apexdox.yml`.
4. Run `npm run prettier`. It formats the generated HTML pages with the other files.
5. Commit the result as `docs(site): regenerate the documentation site`, and open a pull request.

The live site changes only with a release. When Release Please creates a release, the `deploy-site` job in `ci.yml` deploys `docs/` from the release tag to GitHub Pages. So a site update on `main` goes live with the next release.

Release Please writes the release entry into `CHANGELOG.md` only when the release pull request merges, so `docs/` does not have it yet. The deploy rebuilds the changelog page from the `CHANGELOG.md` of the tag, so the live page shows the release.

To deploy again without a release, for example after a fix to the site, run the Deploy site workflow with the Run workflow button. Name a tag, or leave the tag empty to deploy the latest release. The site is still deployed from a release tag, so a fix on `main` goes live only with the next release.

## Release

Do not merge the release pull request by hand. Run the Release workflow with its Run workflow button instead. It runs `scripts/release.mjs`, which does each step in order:

1. It finds the release pull request of Release Please by its `autorelease: pending` label.
2. It creates 1 beta version of the unlocked package from the release branch, with code coverage. It commits the ids to the branch: the alias in `sfdx-project.json`, `package-version.json`, and the install links in the README and the home page of the site. This takes several minutes.
3. It waits until `format-lint` and `package-ids` pass on that commit. `sfca-analysis` is skipped there, and a skipped check counts as passed.
4. It squash-merges the release pull request, but only while its head is still that commit.

After the merge, CI on `main` creates the release and the tag, deploys the site from the tag, and promotes the beta. The `promote-package` job also adds the install links to the release notes. The release tag and the release zip file have the ids, because they are in the merged commit.

Before a release, update the documentation site, as the section above tells, so that the home page of the site has the package version markers of the README.

The promote box is checked by default. Clear it to keep the version a beta after the release: the `promote-package` job then does not promote it, and the install links in the README, the site, and the release notes offer only a sandbox, because a beta cannot be installed in production. The choice is in `package-version.json` of the tag. A beta can be promoted later by hand with `sf package version promote`.

After a change to the text of the install links in `scripts/package-version.mjs`, run `node scripts/package-version.mjs links`. It writes the links of the current version again from `package-version.json` into the README and the site home page, and it changes no id.

The log of the Release run shows the progress of the package build: a line when its status changes, and at least every 2 minutes. The build can take up to 60 minutes.

With the dry run box, the workflow creates a beta that skips validation, shows the changes, and stops. It commits, pushes, and merges nothing, and such a beta cannot be promoted. The GitHub API can start the workflow too: `gh workflow run release.yml -f dry_run=true`. The script also runs on a computer that has the `gh` and `sf` command lines signed in and a clean working tree: `node scripts/release.mjs --dry-run`.

While `sfdx-project.json` names no package, the workflow does not log in to the Dev Hub, and a release only waits for the checks and merges.

The `package-ids` check runs only on the release pull request. It fails while the ids do not belong to the code, for example when the release pull request was not released with the workflow, or when another merge changed `force-app/` after the beta. Release Please also rewrites the release branch after each merge to `main`, and that removes the commit with the ids. In each case, run the Release workflow again.

If the workflow stops after it pushed the ids, run it again. It finds ids on the branch that still belong to the code, so it builds no new beta and goes on to the checks and the merge.

A beta from `main` between releases needs a higher version number than the last release, because Salesforce refuses a new beta of a version number that has a promoted version. Give the number with `--version-number`, for example `sf package version create --package "<package name>" --version-number 2.2.1.NEXT`.
