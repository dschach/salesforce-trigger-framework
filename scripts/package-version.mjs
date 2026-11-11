#!/usr/bin/env node
// Creates a beta version of the unlocked package and writes its ids into the repository,
// checks that the ids in the repository belong to the code, and promotes the beta.
//
// The Release workflow runs scripts/release.mjs, which runs "create" on the release
// branch before it merges the release pull request. The release tag then holds the ids,
// so the tag, the release zip file, and the site all show the install links of that
// release. After the release, the promote-package job in ci.yml runs "promote".
//
// "create" runs sf package version create with code coverage, so the version can be
// promoted after the release. With --skip-validation, for a dry run, the beta is faster
// and uses a separate daily limit, but it cannot be promoted. The CLI adds the alias of
// the version to packageAliases in sfdx-project.json. The script then writes
// package-version.json and the install links between the package-version markers of the
// README and the site home page.
//
// "check" fails when the ids do not belong to the code: the version number differs from
// sfdx-project.json, the force-app folder changed after the beta was built, or a file
// shows another version. It passes with a notice while sfdx-project.json names no package.
// A site page that has no markers yet is not checked; the README must have them.
//
// "promote" promotes the beta in package-version.json, unless it is promoted already.
// "notes" writes the install links as markdown, for the release notes. "has-package"
// writes true or false: whether sfdx-project.json names a package.
//
// Usage:
//   node scripts/package-version.mjs create [--target-dev-hub <alias>] [--skip-validation]
//   node scripts/package-version.mjs check
//   node scripts/package-version.mjs promote [--target-dev-hub <alias>]
//   node scripts/package-version.mjs notes
//   node scripts/package-version.mjs has-package

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { marked } from 'marked';

const PROJECT_FILE = 'sfdx-project.json';
const VERSION_FILE = 'package-version.json';
const PACKAGE_FOLDER = 'force-app';
const MARKDOWN_FILES = ['README.md'];
const HTML_FILES = ['doc-assets/homePage.html', 'docs/index.html'];
const START = '<!-- package-version-start -->';
const END = '<!-- package-version-end -->';
const INSTALL_URL = 'packaging/installPackage.apexp?p0=';
const AGAIN = 'Run the Release workflow again, so that it builds a new beta.';

function fail(message) {
	console.error(message);
	process.exit(1);
}

function readJson(file) {
	return JSON.parse(readFileSync(file, 'utf8'));
}

// The package directory of the framework, with its package name and version number.
function packageDirectory(project) {
	const directory = project.packageDirectories.find((entry) => entry.path === PACKAGE_FOLDER);
	if (!directory) {
		fail(`${PROJECT_FILE} has no package directory ${PACKAGE_FOLDER}.`);
	}
	return directory;
}

// "2.2.0.NEXT" or "2.2.0.3" becomes "2.2.0".
function releaseNumber(versionNumber) {
	return versionNumber.split('.').slice(0, 3).join('.');
}

// The git tree id of the package folder. It changes when any file in the folder changes.
function folderTree() {
	return execFileSync('git', ['rev-parse', `HEAD:${PACKAGE_FOLDER}`], { encoding: 'utf8' }).trim();
}

// Runs a Salesforce CLI command with --json and returns its result, or stops with its error.
function sf(args, devHub, what) {
	const fullArgs = [...args, '--json'];
	if (devHub) {
		fullArgs.push('--target-dev-hub', devHub);
	}
	let output;
	try {
		output = execFileSync('sf', fullArgs, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
	} catch (error) {
		output = error.stdout;
	}
	const response = JSON.parse(output);
	if (response.status !== 0) {
		fail(`${what} failed: ${response.message}`);
	}
	return response.result ?? {};
}

function installMarkdown(release, versionId) {
	return [
		`Install version ${release} as an unlocked package: [in production or a Developer Edition org](https://login.salesforce.com/${INSTALL_URL}${versionId}), or [in a sandbox](https://test.salesforce.com/${INSTALL_URL}${versionId}).`,
		`With the Salesforce CLI, run \`sf package install --package ${versionId} --target-org <alias> --wait 10\`.`
	].join(' ');
}

function blockContent(file, markdown) {
	return file.endsWith('.html') ? marked.parse(markdown, { gfm: true }).trim() : markdown;
}

// Replaces the text between the markers. Returns null when the file has no markers.
function replaceBlock(text, content) {
	const start = text.indexOf(START);
	const end = text.indexOf(END);
	if (start === -1 || end === -1 || end < start) {
		return null;
	}
	return text.slice(0, start + START.length) + '\n\n' + content + '\n\n' + text.slice(end);
}

function readBlock(text) {
	const start = text.indexOf(START);
	const end = text.indexOf(END);
	if (start === -1 || end === -1 || end < start) {
		return null;
	}
	return text.slice(start + START.length, end).trim();
}

// Prettier can wrap the block of an HTML page, so the check reads only what matters: the
// version number, and that every package version id in the block is the expected one.
function showsVersion(block, release, versionId) {
	const text = block.replace(/\s+/g, ' ');
	const ids = text.match(/04t[A-Za-z0-9]{12,15}/g) ?? [];
	return text.includes(`version ${release} `) && ids.length > 0 && ids.every((id) => id === versionId);
}

function create(devHub, skipValidation) {
	const changes = execFileSync('git', ['status', '--porcelain', PACKAGE_FOLDER], { encoding: 'utf8' }).trim();
	if (changes) {
		fail(`${PACKAGE_FOLDER} has changes that are not committed. A beta must match a commit.`);
	}
	const directory = packageDirectory(readJson(PROJECT_FILE));
	if (!directory.package) {
		fail(`${PROJECT_FILE} names no package for ${PACKAGE_FOLDER}.`);
	}

	const validation = skipValidation ? '--skip-validation' : '--code-coverage';
	console.log(`Creating a beta of ${directory.package} ${directory.versionNumber} with ${validation}. This takes several minutes.`);
	const result = sf(
		['package', 'version', 'create', '--package', directory.package, validation, '--installation-key-bypass', '--wait', '60'],
		devHub,
		'The package version create'
	);
	if (result.Status !== 'Success') {
		fail(`The package version was not created: ${result.Error ?? result.Status}`);
	}

	const versionId = result.SubscriberPackageVersionId;
	const release = releaseNumber(result.VersionNumber);
	writeFileSync(VERSION_FILE, JSON.stringify({ version: result.VersionNumber, subscriberPackageVersionId: versionId, packageFolderTree: folderTree() }, null, '\t') + '\n');

	const markdown = installMarkdown(release, versionId);
	for (const file of [...MARKDOWN_FILES, ...HTML_FILES]) {
		if (!existsSync(file)) {
			continue;
		}
		const updated = replaceBlock(readFileSync(file, 'utf8'), blockContent(file, markdown));
		if (updated === null) {
			if (MARKDOWN_FILES.includes(file)) {
				fail(`${file} has no package-version markers.`);
			}
			console.log(`${file} has no package-version markers yet, so it keeps its text.`);
			continue;
		}
		writeFileSync(file, updated);
	}
	console.log(`Created ${result.VersionNumber} (${versionId}) and wrote its ids.`);
}

function check() {
	const project = readJson(PROJECT_FILE);
	const directory = packageDirectory(project);
	if (!directory.package) {
		console.log(`${PROJECT_FILE} names no package yet, so there are no package ids to check.`);
		return;
	}
	if (!existsSync(VERSION_FILE)) {
		fail(`${VERSION_FILE} is missing. ${AGAIN}`);
	}
	const recorded = readJson(VERSION_FILE);
	const problems = [];

	const release = releaseNumber(directory.versionNumber);
	if (releaseNumber(recorded.version) !== release) {
		problems.push(`${VERSION_FILE} has version ${recorded.version}, but ${PROJECT_FILE} has ${directory.versionNumber}.`);
	}
	if (recorded.packageFolderTree !== folderTree()) {
		problems.push(`${PACKAGE_FOLDER} changed after the beta ${recorded.version} was built.`);
	}
	const alias = `${directory.package}@${release}-${recorded.version.split('.')[3]}`;
	if (project.packageAliases?.[alias] !== recorded.subscriberPackageVersionId) {
		problems.push(`${PROJECT_FILE} has no alias ${alias} for ${recorded.subscriberPackageVersionId}.`);
	}

	for (const file of [...MARKDOWN_FILES, ...HTML_FILES]) {
		if (!existsSync(file)) {
			continue;
		}
		const block = readBlock(readFileSync(file, 'utf8'));
		if (block === null) {
			if (MARKDOWN_FILES.includes(file)) {
				problems.push(`${file} has no package-version markers.`);
			}
			continue;
		}
		if (!showsVersion(block, releaseNumber(recorded.version), recorded.subscriberPackageVersionId)) {
			problems.push(`${file} does not show the install links of ${recorded.version}.`);
		}
	}

	if (problems.length > 0) {
		fail(['The package ids do not belong to this code:', ...problems.map((problem) => `- ${problem}`), AGAIN].join('\n'));
	}
	console.log(`The package ids of ${recorded.version} (${recorded.subscriberPackageVersionId}) belong to this code.`);
}

// The recorded beta, or null with a notice when the project has no package or no beta yet.
function recordedBeta() {
	const directory = packageDirectory(readJson(PROJECT_FILE));
	if (!directory.package || !existsSync(VERSION_FILE)) {
		console.error(`${PROJECT_FILE} names no package, or ${VERSION_FILE} is missing, so there is no beta.`);
		return null;
	}
	return readJson(VERSION_FILE);
}

function promote(devHub) {
	const recorded = recordedBeta();
	if (!recorded) {
		return;
	}
	const report = sf(['package', 'version', 'report', '--package', recorded.subscriberPackageVersionId], devHub, 'The package version report');
	if (report.IsReleased) {
		console.log(`${recorded.version} (${recorded.subscriberPackageVersionId}) is promoted already.`);
		return;
	}
	sf(['package', 'version', 'promote', '--package', recorded.subscriberPackageVersionId, '--no-prompt'], devHub, 'The package version promote');
	console.log(`Promoted ${recorded.version} (${recorded.subscriberPackageVersionId}).`);
}

function notes() {
	const recorded = recordedBeta();
	if (recorded) {
		console.log(installMarkdown(releaseNumber(recorded.version), recorded.subscriberPackageVersionId));
	}
}

const [command, ...options] = process.argv.slice(2);
const devHubIndex = options.indexOf('--target-dev-hub');
const devHub = devHubIndex === -1 ? undefined : options[devHubIndex + 1];

if (command === 'create') {
	create(devHub, options.includes('--skip-validation'));
} else if (command === 'check') {
	check();
} else if (command === 'promote') {
	promote(devHub);
} else if (command === 'notes') {
	notes();
} else if (command === 'has-package') {
	console.log(Boolean(packageDirectory(readJson(PROJECT_FILE)).package));
} else {
	fail('Usage: node scripts/package-version.mjs create [--target-dev-hub <alias>] [--skip-validation] | check | promote [--target-dev-hub <alias>] | notes | has-package');
}
