#!/usr/bin/env node
// Builds a local copy of the documentation site as the deploy-site workflow builds it, and
// serves it, so you can see the site before a release. It copies docs/ to a folder in the
// temporary folder of your computer, runs scripts/build-site.mjs on the copy, and serves
// the copy at http://localhost:4000/salesforce-trigger-framework/, the same path as the
// live site. docs/ does not change.
//
// The toolbar loads the markdown copy of the page with fetch, which does not work for a
// page opened as a file. So open the preview from the server, not from the folder.
//
// Usage: npm run site:preview
//        PORT=4001 npm run site:preview to use another port.
//        npm run site:preview -- --build-only to build the copy and not serve it.

import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, readFileSync, rmSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { extname, join, normalize, resolve, sep } from 'node:path';

const SITE_PATH = '/salesforce-trigger-framework/';
const PORT = Number(process.env.PORT) || 4000;
const PREVIEW_FOLDER = join(tmpdir(), 'salesforce-trigger-framework-site');
const BUILD_ONLY = process.argv.includes('--build-only');

// The media types of the files of the site. GitHub Pages sends text/markdown for .md.
const MEDIA_TYPES = {
	'.html': 'text/html; charset=utf-8',
	'.css': 'text/css; charset=utf-8',
	'.js': 'text/javascript; charset=utf-8',
	'.md': 'text/markdown; charset=utf-8',
	'.txt': 'text/plain; charset=utf-8',
	'.json': 'application/json; charset=utf-8',
	'.svg': 'image/svg+xml',
	'.png': 'image/png',
	'.jpg': 'image/jpeg',
	'.gif': 'image/gif',
	'.ico': 'image/x-icon',
	'.woff': 'font/woff',
	'.woff2': 'font/woff2'
};

if (!existsSync('docs/changelog.html')) {
	console.error('Run this from the root of the repository, which has docs/.');
	process.exit(1);
}

rmSync(PREVIEW_FOLDER, { recursive: true, force: true });
cpSync('docs', PREVIEW_FOLDER, { recursive: true });
execFileSync(process.execPath, ['scripts/build-site.mjs', PREVIEW_FOLDER], { stdio: 'inherit' });
console.log(`The preview of the site is in ${PREVIEW_FOLDER}.`);
if (BUILD_ONLY) {
	process.exit(0);
}

const root = resolve(PREVIEW_FOLDER);

// Returns the file for a URL path in the site, or null if the path is outside the site.
function fileFor(urlPath) {
	let path = decodeURIComponent(urlPath.slice(SITE_PATH.length));
	if (path === '' || path.endsWith('/')) {
		path += 'index.html';
	}
	const file = resolve(root, normalize(path));
	return file === root || file.startsWith(root + sep) ? file : null;
}

const server = createServer((request, response) => {
	const urlPath = new URL(request.url, 'http://localhost').pathname;
	if (!urlPath.startsWith(SITE_PATH)) {
		response.writeHead(302, { Location: SITE_PATH });
		response.end();
		return;
	}
	let file;
	try {
		file = fileFor(urlPath);
	} catch {
		file = null;
	}
	if (!file || !existsSync(file) || !statSync(file).isFile()) {
		response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
		response.end(`Not found: ${urlPath}\n`);
		return;
	}
	response.writeHead(200, { 'Content-Type': MEDIA_TYPES[extname(file).toLowerCase()] ?? 'application/octet-stream' });
	response.end(readFileSync(file));
});

server.on('error', (error) => {
	console.error(error.code === 'EADDRINUSE' ? `Port ${PORT} is in use. Use another port, for example PORT=4001 npm run site:preview.` : error.message);
	process.exit(1);
});
server.listen(PORT, 'localhost', () => {
	console.log(`Open http://localhost:${PORT}${SITE_PATH} to see the site. Press Control+C to stop the server.`);
});
