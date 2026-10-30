#!/usr/bin/env node
// Copy the code of the sample files into sample-handler/README.md, so that the README and
// the documentation site always show the real code. Each copy is between 2 markers:
//
//   <!-- START sample-code main/default/classes/AccountSampleTriggerHandler.cls -->
//   <!-- END sample-code -->
//
// The path in the START marker is relative to sample-handler/. The script formats the
// README with Prettier, which changes the tabs in the code to spaces, so that a commit
// and the Prettier check do not change the README again.
//
// The pre-commit hook runs this with --index when a sample file or the sample README is staged, and
// npm run prepareApexDox runs it before it builds the sample page. CI runs it with --check.
//
// Usage: node scripts/sync-sample-code.mjs [--index] [--check]
//   --index  Read the sample files from the git index, not from the working tree.
//   --check  Change nothing. Exit with 1 if the README is not current.

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import * as prettier from 'prettier';

const README = 'sample-handler/README.md';
const MARKERS = /(<!-- START sample-code (\S+) -->\n)[\s\S]*?(<!-- END sample-code -->)/g;

const args = new Set(process.argv.slice(2));
const fromIndex = args.has('--index');
const check = args.has('--check');

function readSample(path) {
	const file = `sample-handler/${path}`;
	return fromIndex ? execFileSync('git', ['show', `:${file}`], { encoding: 'utf8' }) : readFileSync(file, 'utf8');
}

// The fence is longer than the longest run of backticks in the code, so that the code
// cannot close it.
function codeBlock(code) {
	const longestRun = Math.max(0, ...(code.match(/`+/g) ?? []).map((run) => run.length));
	const fence = '`'.repeat(Math.max(3, longestRun + 1));
	return `${fence}apex\n${code.replace(/\n*$/, '\n')}${fence}\n`;
}

const before = readFileSync(README, 'utf8');
let count = 0;
const synced = before.replace(MARKERS, (match, start, path, end) => {
	count++;
	return `${start}\n${codeBlock(readSample(path))}\n${end}`;
});

if (count === 0) {
	console.error(`${README} has no sample-code markers.`);
	process.exit(1);
}
const prettierOptions = await prettier.resolveConfig(README);
const after = await prettier.format(synced, { ...prettierOptions, filepath: README });
if (after === before) {
	process.exit(0);
}
if (check) {
	console.error(`${README} does not show the current sample code. Run: node scripts/sync-sample-code.mjs`);
	process.exit(1);
}
writeFileSync(README, after);
console.log(`Updated the sample code in ${README}.`);
