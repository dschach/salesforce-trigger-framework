#!/usr/bin/env node
// Rebuild the content of the changelog page of the documentation site from CHANGELOG.md.
// The site is generated before a release, so its changelog page does not have that
// release yet. The deploy workflow runs this on the release tag, so the deployed page
// shows the release. Only the content cell of the ApexDox page changes; the frame of the
// page stays as ApexDox wrote it.
//
// Usage: node scripts/rebuild-changelog-page.mjs <changelog page> <CHANGELOG.md>

import { readFileSync, writeFileSync } from 'node:fs';
import { marked } from 'marked';

const [page, changelog] = process.argv.slice(2);
if (!page || !changelog) {
	console.error('Usage: node scripts/rebuild-changelog-page.mjs <changelog page> <CHANGELOG.md>');
	process.exit(1);
}

const START = '<td class="doc-page">';
const END = '</td>';

const html = readFileSync(page, 'utf8');
const start = html.indexOf(START);
const end = start === -1 ? -1 : html.indexOf(END, start);
if (start === -1 || end === -1) {
	console.error(`${page} has no content cell (${START}).`);
	process.exit(1);
}

// The same stylesheet link that npm run prepareApexDox puts at the start of the page.
const content = '<link href="assets/styling.css" rel="stylesheet" />\n' + marked.parse(readFileSync(changelog, 'utf8'), { gfm: true });
writeFileSync(page, html.slice(0, start + START.length) + '\n' + content + html.slice(end));
console.log(`Rebuilt the content of ${page} from ${changelog}.`);
