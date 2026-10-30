# Security Policy

## Supported Versions

Security fixes go into the latest release only. To get a fix, upgrade to the latest release.

## Report a Vulnerability

Do not report a vulnerability in a public issue, a pull request, or a comment. A public report shows the problem to everyone before a fix is available.

Report it privately with GitHub:

1. Open the [Security tab](https://github.com/dschach/salesforce-trigger-framework/security) of this repository.
2. Click **Report a vulnerability**. The form opens a private security advisory that only you and the maintainer can see.
3. Fill in the form. Include:
   - The release of the framework that you use.
   - The code of the trigger and the handler, or the smallest code that shows the problem.
   - The steps to reproduce the problem.
   - The effect: for example, data that a user can see or change without permission.

You can also go directly to the [report form](https://github.com/dschach/salesforce-trigger-framework/security/advisories/new).

## What Happens Next

The maintainer answers in the advisory, and asks questions there if necessary. When a fix is ready, the fix and the advisory are published together. The advisory gives credit to the reporter, unless the reporter asks for no credit.

## Scope

This policy covers the framework in `force-app/` and the sample in `sample-handler/`. A problem in a dependency of the development tools, such as an npm package, goes to the project of that dependency.
