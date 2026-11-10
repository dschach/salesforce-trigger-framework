#!/usr/bin/env node
// Replace each Mermaid code block in an HTML page with an inline SVG of the diagram.
// GitHub draws the Mermaid blocks of the README, but the documentation site gets its home
// page from marked, which shows them only as code. npm run prepareApexDox runs this on the
// home page after marked builds it.
//
// The script runs the Mermaid command line with npx, at a pinned version, so it is not a
// devDependency and CI does not install it. The command line needs Chrome. It uses the
// browser in PUPPETEER_EXECUTABLE_PATH, or else Google Chrome in /Applications on macOS.
// Each diagram gets its own SVG id, so that the styles of 2 diagrams on 1 page do not mix.
//
// Usage: node scripts/render-mermaid.mjs <html file>

import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const MERMAID_CLI = '@mermaid-js/mermaid-cli@11.17.0';
const MAC_CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BLOCKS = /<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g;

// Plain text labels and a plain system font keep each SVG small: a web font is embedded
// in each SVG. For the same reason, the README draws start and end steps as rounded boxes,
// not as stadium shapes, which Mermaid draws as very long paths.
const MERMAID_CONFIG = { theme: 'neutral', fontFamily: 'arial, sans-serif', flowchart: { htmlLabels: false } };

const page = process.argv[2];
if (!page) {
	console.error('Usage: node scripts/render-mermaid.mjs <html file>');
	process.exit(1);
}

function decodeEntities(text) {
	return text
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&quot;/g, '"')
		.replace(/&#39;/g, "'")
		.replace(/&amp;/g, '&');
}

const html = readFileSync(page, 'utf8');
const sources = [...html.matchAll(BLOCKS)].map((match) => decodeEntities(match[1]));
if (sources.length === 0) {
	console.log(`${page} has no Mermaid diagram.`);
	process.exit(0);
}

const work = mkdtempSync(join(tmpdir(), 'mermaid-'));
try {
	const browser = process.env.PUPPETEER_EXECUTABLE_PATH ?? (existsSync(MAC_CHROME) ? MAC_CHROME : undefined);
	const puppeteerConfig = join(work, 'puppeteer.json');
	writeFileSync(puppeteerConfig, JSON.stringify(browser ? { executablePath: browser, headless: 'shell' } : { headless: 'shell' }));
	const mermaidConfig = join(work, 'mermaid.json');
	writeFileSync(mermaidConfig, JSON.stringify(MERMAID_CONFIG));

	const svgs = sources.map((source, index) => {
		const input = join(work, `diagram-${index + 1}.mmd`);
		const output = join(work, `diagram-${index + 1}.svg`);
		writeFileSync(input, source);
		execFileSync(
			'npx',
			[
				'--yes',
				'--package',
				MERMAID_CLI,
				'mmdc',
				'--quiet',
				'-p',
				puppeteerConfig,
				'-c',
				mermaidConfig,
				'-I',
				`mermaid-diagram-${index + 1}`,
				'-b',
				'transparent',
				'-i',
				input,
				'-o',
				output
			],
			{ stdio: ['ignore', 'ignore', 'inherit'] }
		);
		return readFileSync(output, 'utf8');
	});

	let index = 0;
	const updated = html.replace(BLOCKS, () => `<div class="mermaid-diagram">${svgs[index++]}</div>`);
	writeFileSync(page, updated);
	console.log(`Replaced ${svgs.length} Mermaid diagrams in ${page}.`);
} finally {
	rmSync(work, { recursive: true, force: true });
}
