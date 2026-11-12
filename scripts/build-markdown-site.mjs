#!/usr/bin/env node
// Adds the markdown side of the documentation site: a markdown copy of each page, an
// llms.txt that lists them, and a toolbar on each page with Copy as Markdown, View as
// Markdown, Copy URL to Markdown, View llms.txt, and Copy URL to llms.txt.
//
// The deploy-site workflow runs it on docs/ of the release tag, after the changelog page
// is rebuilt, so the copies match the released site and nothing is committed.
//
// - A page that comes from a markdown file gets a copy of that file, with its links to
//   other files changed to the markdown copies: index.md from README.md, deploy.md from
//   DEPLOY.md, changelog.md from CHANGELOG.md, and sampletriggerhandlerhome.md from the
//   sample README.
// - A class page gets its content cell converted to markdown with turndown.
// - llms.txt follows https://llmstxt.org/: a title, a summary, the install line of the
//   current package version, and link lists to the markdown copies.
// - Each page gets links to its markdown copy and to llms.txt in its head, and the toolbar
//   at the top of its content cell. The toolbar files come from doc-assets/markdown-tools.
// - Each link in llms.txt must point to a file in the site, or the script fails.
// A page that has the toolbar already is not changed again.
//
// Usage: node scripts/build-markdown-site.mjs <site folder>

import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import TurndownService from 'turndown';
import turndownPluginGfm from 'turndown-plugin-gfm';

const SITE_URL = 'https://davidschach.com/salesforce-trigger-framework/';
const REPO_URL = 'https://github.com/dschach/salesforce-trigger-framework';
const TITLE = 'Trigger Handler Framework';
const SUMMARY = 'A small base class for Apex trigger handlers. It runs the method of each trigger operation, and it controls bypasses, loop limits, and debug lines.';
const TOOLS_FOLDER = 'doc-assets/markdown-tools';
const TOOLS_FILES = ['markdown-tools.js', 'markdown-tools.css'];
const CONTENT_START = '<td class="doc-page">';
const TOOLBAR_CLASS = 'markdown-tools';

// The pages that come from a markdown file, by page name.
const MARKDOWN_SOURCES = {
	index: 'README.md',
	deploy: 'DEPLOY.md',
	changelog: 'CHANGELOG.md',
	sampletriggerhandlerhome: 'sample-handler/README.md'
};

// The main links of llms.txt, in order. Each other page goes to the Optional section.
const MAIN_PAGES = [
	['index', 'Overview and usage', 'what the framework does, how run() works, bypasses, loop limits, debug lines, and a table of the whole API'],
	['TriggerHandler', 'TriggerHandler class reference', 'every public and protected member of the base class, with its ApexDoc and examples'],
	['sampletriggerhandlerhome', 'Sample trigger handler', 'a complete sample handler and trigger on Account, and what each part shows'],
	['deploy', 'Deploy', 'how to deploy the framework to a scratch org or to another org']
];
const OPTIONAL_PAGES = {
	changelog: ['Changelog', 'every release, with an upgrade note for each breaking change'],
	AccountSampleTriggerHandler: ['AccountSampleTriggerHandler class reference', 'the sample handler'],
	AccountSampleTriggerHandlerTest: ['AccountSampleTriggerHandlerTest class reference', 'the tests of the sample handler'],
	TriggerHandlerTest: ['TriggerHandlerTest class reference', 'the tests of the base class'],
	TriggerHandlerBypassPermissionTest: ['TriggerHandlerBypassPermissionTest class reference', 'the test of the bypass permission']
};

const site = process.argv[2];
if (!site) {
	console.error('Usage: node scripts/build-markdown-site.mjs <site folder>');
	process.exit(1);
}

function fail(message) {
	console.error(message);
	process.exit(1);
}

// Changes the links of a markdown file to other files of the repository: to the markdown
// copy of a page, or else to the file on GitHub. The same files as in prepareApexDox.sh.
function rewriteMarkdownLinks(markdown) {
	return markdown.replace(/\]\(([^)\s]+)\)/g, (whole, target) => {
		if (/^(https?:|mailto:|#)/.test(target)) {
			return whole;
		}
		const [path, anchor] = target.split('#');
		const replacements = {
			'DEPLOY.md': 'deploy.md',
			'./DEPLOY.md': 'deploy.md',
			'CHANGELOG.md': 'changelog.md',
			'sample-handler/README.md': 'sampletriggerhandlerhome.md',
			'../README.md': 'index.md'
		};
		const replaced = replacements[path] ?? `${REPO_URL}/tree/main/${path.replace(/^\.\//, '')}`;
		return `](${replaced}${anchor ? `#${anchor}` : ''})`;
	});
}

// Returns the HTML inside the content cell. It counts nested cells, because a class page
// has tables in its content.
function contentCell(html) {
	const start = html.indexOf(CONTENT_START);
	if (start === -1) {
		return null;
	}
	const tag = /<td[\s>]|<\/td>/g;
	tag.lastIndex = start + CONTENT_START.length;
	let depth = 1;
	for (let match = tag.exec(html); match; match = tag.exec(html)) {
		depth += match[0] === '</td>' ? -1 : 1;
		if (depth === 0) {
			return html.slice(start + CONTENT_START.length, match.index);
		}
	}
	return null;
}

function hasClass(node, ...names) {
	return node.nodeType === 1 && names.some((name) => (node.getAttribute('class') ?? '').split(/\s+/).includes(name));
}

function insideCell(node) {
	for (let parent = node.parentNode; parent; parent = parent.parentNode) {
		if (parent.nodeName === 'TD' || parent.nodeName === 'TH') {
			return true;
		}
	}
	return false;
}

// true when no element comes before the cell in its row. Text between the cells is only
// the white space of the formatted HTML.
function firstCell(node) {
	for (let sibling = node.previousSibling; sibling; sibling = sibling.previousSibling) {
		if (sibling.nodeType === 1) {
			return false;
		}
	}
	return true;
}

function turndownService() {
	const service = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-', emDelimiter: '_' });
	service.use(turndownPluginGfm.gfm);
	service.remove(['script', 'style', 'link']);
	// The list of methods at the top of a class repeats each method description.
	service.remove((node) => hasClass(node, 'methods-toc', TOOLBAR_CLASS));
	service.addRule('subtitle', {
		filter: (node) => hasClass(node, 'class-subtitle', 'method-subtitle'),
		replacement: (content) => `\n\n**${content.trim()}**\n\n`
	});
	// A signature is a code block, but inline code inside a table cell, where a block would
	// break the row.
	service.addRule('signature', {
		filter: (node) => hasClass(node, 'class-signature', 'method-signature', 'attribute-signature'),
		replacement: (content, node) => {
			const signature = node.textContent.trim().replace(/\s+/g, ' ');
			return insideCell(node) ? `\`${signature}\`` : `\n\n\`\`\`apex\n${signature}\n\`\`\`\n\n`;
		}
	});
	// A parameter is 3 divs: name, type, and description. Together they make 1 list item.
	service.addRule('paramName', {
		filter: (node) => hasClass(node, 'param-name'),
		replacement: (content, node) => `\n\n- \`${node.textContent.trim()}\``
	});
	service.addRule('paramType', {
		filter: (node) => hasClass(node, 'param-type'),
		replacement: (content) => ` (${content.trim()})`
	});
	service.addRule('paramDescription', {
		filter: (node) => hasClass(node, 'param-description'),
		replacement: (content) => `: ${content.trim()}\n\n`
	});
	// A table cell keeps its content on 1 line, so the row stays 1 markdown table row.
	service.addRule('tableCell', {
		filter: ['th', 'td'],
		replacement: (content, node) => {
			const text = content
				.replace(/\s*\n+\s*/g, ' ')
				.replace(/\|/g, '\\|')
				.trim();
			return `${firstCell(node) ? '| ' : ' '}${text} |`;
		}
	});
	service.addRule('example', {
		filter: (node) => node.nodeName === 'PRE' && hasClass(node, 'code-example'),
		replacement: (content, node) => {
			const lines = node.textContent.split('\n').map((line) => line.trim());
			return `\n\n\`\`\`apex\n${lines.join('\n').trim()}\n\`\`\`\n\n`;
		}
	});
	// ApexDox links to other pages with goToLocation('Page.html#anchor'). A link to a page
	// goes to its markdown copy. A link to an anchor goes to the HTML page, because only the
	// HTML page has the ids of the members.
	service.addRule('pageLink', {
		filter: (node) => node.nodeName === 'A' && /goToLocation\('/.test(node.getAttribute('onclick') ?? ''),
		replacement: (content, node) => {
			const location = /goToLocation\('([^']+)'\)/.exec(node.getAttribute('onclick'))[1];
			const target = location.includes('#') ? `${SITE_URL}${location}` : location.replace(/\.html$/, '.md');
			return `[${content.trim()}](${target})`;
		}
	});
	return service;
}

function toolbar(markdownFile) {
	return [
		`<nav class="${TOOLBAR_CLASS}" aria-label="Markdown versions" data-markdown="${markdownFile}" data-llms="llms.txt">`,
		'<button type="button" class="markdown-tools__action" data-action="copy-markdown">Copy as Markdown</button>',
		`<a class="markdown-tools__action" href="${markdownFile}" target="_blank" rel="noopener">View as Markdown</a>`,
		'<a class="markdown-tools__action" href="llms.txt" target="_blank" rel="noopener">View llms.txt</a>',
		'<div class="markdown-tools__more">',
		'<button type="button" class="markdown-tools__toggle" aria-expanded="false" aria-controls="markdown-tools-menu" aria-label="More Markdown actions">&hellip;</button>',
		'<div class="markdown-tools__menu" id="markdown-tools-menu" hidden>',
		'<p class="markdown-tools__heading">This page</p>',
		'<button type="button" data-action="copy-markdown">Copy as Markdown</button>',
		`<a href="${markdownFile}" target="_blank" rel="noopener">View as Markdown</a>`,
		'<button type="button" data-action="copy-markdown-url">Copy URL to Markdown</button>',
		'<p class="markdown-tools__heading">All documentation</p>',
		'<a href="llms.txt" target="_blank" rel="noopener">View llms.txt</a>',
		'<button type="button" data-action="copy-llms-url">Copy URL to llms.txt</button>',
		'</div>',
		'</div>',
		'<span class="markdown-tools__status" role="status" aria-live="polite"></span>',
		'</nav>'
	].join('\n');
}

function headLinks(markdownFile) {
	return [
		`<link rel="alternate" type="text/markdown" href="${markdownFile}" />`,
		'<link rel="describedby" href="llms.txt" />',
		'<link href="./assets/markdown-tools.css" rel="stylesheet" />',
		'<script src="./assets/markdown-tools.js" defer></script>'
	].join('\n');
}

function installLine() {
	if (!existsSync('package-version.json')) {
		return '';
	}
	return execFileSync('node', ['scripts/package-version.mjs', 'notes'], { encoding: 'utf8' }).trim();
}

function linkList(entries) {
	return entries.map(([page, name, note]) => `- [${name}](${SITE_URL}${page}.md): ${note}`).join('\n');
}

// 1. A markdown copy of each page.
const service = turndownService();
const pages = readdirSync(site)
	.filter((file) => file.endsWith('.html'))
	.map((file) => file.slice(0, -'.html'.length))
	.sort();
for (const page of pages) {
	const markdownFile = `${page}.md`;
	let markdown;
	if (MARKDOWN_SOURCES[page]) {
		markdown = rewriteMarkdownLinks(readFileSync(MARKDOWN_SOURCES[page], 'utf8'));
	} else {
		const cell = contentCell(readFileSync(join(site, `${page}.html`), 'utf8'));
		if (cell === null) {
			fail(`${page}.html has no content cell (${CONTENT_START}).`);
		}
		// The ids of the members are only in the HTML page, so a link to 1 of them goes there.
		markdown = service.turndown(cell).replace(/\]\(#/g, `](${SITE_URL}${page}.html#`);
	}
	writeFileSync(join(site, markdownFile), `${markdown.trim()}\n`);
}

// 2. llms.txt.
// The Optional section lists the pages of OPTIONAL_PAGES in its order, and then any other page.
const optional = [
	...Object.keys(OPTIONAL_PAGES).filter((page) => pages.includes(page)),
	...pages.filter((page) => !OPTIONAL_PAGES[page] && !MAIN_PAGES.some(([main]) => main === page))
].map((page) => [page, ...(OPTIONAL_PAGES[page] ?? [page, 'a page of the documentation site'])]);
const install = installLine();
const llms = [
	`# ${TITLE}`,
	'',
	`> ${SUMMARY}`,
	'',
	'The framework is 1 Apex class, `TriggerHandler`. Each trigger handler extends it, and each trigger calls `run()` on its handler.',
	`The source code is on GitHub at ${REPO_URL}, under the BSD 3-Clause license.`,
	...(install ? ['', install] : []),
	'',
	'## Docs',
	'',
	linkList(MAIN_PAGES),
	'',
	'## Optional',
	'',
	linkList(optional),
	''
].join('\n');
writeFileSync(join(site, 'llms.txt'), llms);

// 3. The toolbar and the head links of each page.
for (const file of TOOLS_FILES) {
	copyFileSync(join(TOOLS_FOLDER, file), join(site, 'assets', file));
}
for (const page of pages) {
	const path = join(site, `${page}.html`);
	let html = readFileSync(path, 'utf8');
	if (html.includes(`class="${TOOLBAR_CLASS}"`)) {
		continue;
	}
	const markdownFile = `${page}.md`;
	html = html.replace('</head>', `${headLinks(markdownFile)}\n</head>`).replace(CONTENT_START, `${CONTENT_START}\n${toolbar(markdownFile)}`);
	writeFileSync(path, html);
}

// 4. Each link of llms.txt points to a file of the site.
for (const [, url] of llms.matchAll(/\]\((https:[^)]+)\)/g)) {
	if (url.startsWith(SITE_URL) && !existsSync(join(site, url.slice(SITE_URL.length)))) {
		fail(`llms.txt links to ${url}, but the site has no such file.`);
	}
}
console.log(`Wrote ${pages.length} markdown pages, llms.txt, and the toolbar of each page.`);
