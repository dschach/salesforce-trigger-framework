#!/usr/bin/env node
// Builds the deployed documentation site from a copy of docs/. The deploy-site workflow
// runs it on docs/ of the release tag, and npm run site:preview runs it on a copy of
// docs/, so the preview shows what the live site shows. It runs these steps in order:
//
// 1. Rebuild the changelog page from CHANGELOG.md (scripts/rebuild-changelog-page.mjs).
// 2. Add ids to the headings of the changelog page (scripts/add-heading-ids.mjs).
// 3. Add the markdown pages, llms.txt, and the toolbar (scripts/build-markdown-site.mjs).
//
// Run it from the root of the repository, because it reads CHANGELOG.md and the other
// source files there.
//
// Usage: node scripts/build-site.mjs <site folder>

import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const [site] = process.argv.slice(2);
if (!site) {
	console.error('Usage: node scripts/build-site.mjs <site folder>');
	process.exit(1);
}
const changelogPage = join(site, 'changelog.html');
if (!existsSync(changelogPage)) {
	console.error(`${site} is not a copy of docs/: it has no changelog.html.`);
	process.exit(1);
}

const steps = [
	['Rebuild the changelog page from CHANGELOG.md', ['scripts/rebuild-changelog-page.mjs', changelogPage, 'CHANGELOG.md']],
	['Add ids to the headings of the changelog page', ['scripts/add-heading-ids.mjs', changelogPage]],
	['Add the markdown pages, llms.txt, and the toolbar', ['scripts/build-markdown-site.mjs', site]]
];
for (const [name, args] of steps) {
	console.log(`${name}:`);
	execFileSync(process.execPath, args, { stdio: 'inherit' });
}
