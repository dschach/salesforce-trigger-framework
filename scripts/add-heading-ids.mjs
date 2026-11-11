// Add an id to each heading of an HTML page, with the same slug that GitHub uses for its
// README anchors, so the links of a table of contents jump to their heading. marked 18
// writes headings without ids, so the anchors of the README table of contents do not work
// on the site until the ids are added. A repeated heading gets a suffix, -1, -2, and so on,
// as GitHub does. A heading that already has an id keeps it.
//
// Usage: node scripts/add-heading-ids.mjs <file>...

import { readFileSync, writeFileSync } from 'node:fs';

const decodeEntities = (text) =>
	text
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&quot;/g, '"')
		.replace(/&#39;/g, "'")
		.replace(/&amp;/g, '&');

// GitHub's slug: lower case, drop every character that is not a letter, a digit, a space,
// a hyphen, or an underscore, then turn each space into a hyphen.
const slugify = (html) =>
	decodeEntities(html.replace(/<[^>]*>/g, ''))
		.trim()
		.toLowerCase()
		.replace(/[^\p{L}\p{N} _-]/gu, '')
		.replace(/ /g, '-');

for (const file of process.argv.slice(2)) {
	const seen = new Map();
	const text = readFileSync(file, 'utf8').replace(/<h([1-6])(\s[^>]*)?>([\s\S]*?)<\/h\1>/g, (whole, level, attributes = '', inner) => {
		if (/\sid="/.test(attributes)) {
			return whole;
		}
		const base = slugify(inner);
		const count = seen.get(base) ?? 0;
		seen.set(base, count + 1);
		const id = count === 0 ? base : `${base}-${count}`;
		return `<h${level} id="${id}"${attributes}>${inner}</h${level}>`;
	});
	writeFileSync(file, text);
}
