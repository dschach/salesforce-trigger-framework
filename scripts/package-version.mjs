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
// and uses a separate daily limit, but it cannot be promoted. The build starts with
// --wait 0, and the script then reads its status every 30 seconds, for up to 60 minutes,
// so the log shows its progress. The script adds the alias of the version to
// packageAliases in sfdx-project.json, in the form that the CLI uses, and it writes
// package-version.json and the install links
// between the package-version markers of the README and the site home page.
// With --keep-beta, package-version.json says that the version stays a beta, and the
// install links offer only a sandbox, because a beta cannot be installed in production.
//
// "check" fails when the ids do not belong to the code: the version number differs from
// sfdx-project.json, the force-app folder changed after the beta was built, or a file
// shows another version. It passes with a notice while sfdx-project.json names no package.
// A site page that has no markers yet is not checked; the README must have them.
//
// "promote" promotes the beta in package-version.json, unless it is promoted already, or
// unless package-version.json says that it stays a beta. "links" writes the install links
// again from package-version.json, for example after a change to their text.
// "notes" writes the install links as markdown, for the release notes. "has-package"
// writes true or false: whether sfdx-project.json names a package.
//
// Usage:
//   node scripts/package-version.mjs create [--target-dev-hub <alias>] [--skip-validation] [--keep-beta]
//   node scripts/package-version.mjs check
//   node scripts/package-version.mjs promote [--target-dev-hub <alias>]
//   node scripts/package-version.mjs links
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
const BUILD_WAIT_MINUTES = 60;
const POLL_SECONDS = 30;
const PROGRESS_MINUTES = 2;

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

// "less than 1 minute", "about 1 minute", or "about 5 minutes".
function minutesText(milliseconds) {
	const minutes = Math.round(milliseconds / 60000);
	if (minutes === 0) {
		return 'less than 1 minute';
	}
	return `about ${minutes} minute${minutes === 1 ? '' : 's'}`;
}

function sleep(seconds) {
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, seconds * 1000);
}

// true unless package-version.json says that the version stays a beta. A file from before
// the choice existed has no promote field, and its version is promoted.
function willPromote(recorded) {
	return recorded.promote !== false;
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

function installMarkdown(release, versionId, promoted) {
	const cli = `With the Salesforce CLI, run \`sf package install --package ${versionId} --target-org <alias> --wait 10\`.`;
	if (!promoted) {
		return [
			`**Install beta version ${release} of the unlocked package** [in a sandbox](https://test.salesforce.com/${INSTALL_URL}${versionId}) or in a scratch org. A beta cannot be installed in production.`,
			cli
		].join(' ');
	}
	return [
		`**Install version ${release} as an unlocked package:** [in production or a Developer Edition org](https://login.salesforce.com/${INSTALL_URL}${versionId}), or [in a sandbox](https://test.salesforce.com/${INSTALL_URL}${versionId}).`,
		cli
	].join(' ');
}

// The words that start the install line, so the check can tell a release from a beta.
function installPhrase(release, promoted) {
	return promoted ? `Install version ${release} ` : `Install beta version ${release} `;
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
function showsVersion(block, release, versionId, promoted) {
	const text = block.replace(/\s+/g, ' ');
	const ids = text.match(/04t[A-Za-z0-9]{12,15}/g) ?? [];
	return text.includes(installPhrase(release, promoted)) && ids.length > 0 && ids.every((id) => id === versionId);
}

// Starts the build with --wait 0, then reads its status until it ends, and writes a line
// when the status changes, and at least every few minutes, so the log shows progress.
function buildVersion(args, devHub) {
	const request = sf([...args, '--wait', '0'], devHub, 'The package version create');
	console.log(`Build request ${request.Id} is ${request.Status}.`);
	const started = Date.now();
	let lastStatus = request.Status;
	let lastLine = started;
	for (;;) {
		sleep(POLL_SECONDS);
		const report = sf(['package', 'version', 'create', 'report', '--package-create-request-id', request.Id], devHub, 'The package version create report');
		const result = Array.isArray(report) ? report[0] : report;
		if (result.Status === 'Success') {
			console.log(`Build finished after ${minutesText(Date.now() - started)}.`);
			return result;
		}
		if (result.Status === 'Error') {
			fail(`The package version was not created: ${[].concat(result.Error ?? []).join(' ') || 'no error text'}`);
		}
		if (result.Status !== lastStatus || Date.now() - lastLine >= PROGRESS_MINUTES * 60000) {
			console.log(`After ${minutesText(Date.now() - started)}, the build is ${result.Status}.`);
			lastStatus = result.Status;
			lastLine = Date.now();
		}
		if (Date.now() - started > BUILD_WAIT_MINUTES * 60000) {
			fail(`The build did not finish in ${BUILD_WAIT_MINUTES} minutes. Read its status with: sf package version create report --package-create-request-id ${request.Id}`);
		}
	}
}

// Writes the install links between the package-version markers of each file.
function writeLinks(release, versionId, promoted) {
	const markdown = installMarkdown(release, versionId, promoted);
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
}

function create(devHub, skipValidation, keepBeta) {
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
	const result = buildVersion(['package', 'version', 'create', '--package', directory.package, validation, '--installation-key-bypass'], devHub);

	const versionId = result.SubscriberPackageVersionId;
	const release = releaseNumber(result.VersionNumber);
	// The CLI writes the alias of the version only when it waits for the build itself, so
	// after a build that started with --wait 0, the script writes it, in the CLI's form.
	const project = readJson(PROJECT_FILE);
	project.packageAliases = { ...project.packageAliases, [`${directory.package}@${release}-${result.VersionNumber.split('.')[3]}`]: versionId };
	writeFileSync(PROJECT_FILE, JSON.stringify(project, null, 2) + '\n');
	const promoted = !keepBeta;
	writeFileSync(
		VERSION_FILE,
		JSON.stringify({ version: result.VersionNumber, subscriberPackageVersionId: versionId, packageFolderTree: folderTree(), promote: promoted }, null, '\t') + '\n'
	);

	writeLinks(release, versionId, promoted);
	console.log(`Created ${result.VersionNumber} (${versionId}) and wrote its ids.${promoted ? '' : ' It stays a beta after the release.'}`);
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
		if (!showsVersion(block, releaseNumber(recorded.version), recorded.subscriberPackageVersionId, willPromote(recorded))) {
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
	if (!willPromote(recorded)) {
		console.log(`${recorded.version} (${recorded.subscriberPackageVersionId}) stays a beta, as the Release run chose.`);
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

// Writes the install links again from package-version.json, for example after a change to
// their text. It changes no id.
function links() {
	const recorded = recordedBeta();
	if (recorded) {
		writeLinks(releaseNumber(recorded.version), recorded.subscriberPackageVersionId, willPromote(recorded));
		console.log(`Wrote the install links of ${recorded.version} again.`);
	}
}

function notes() {
	const recorded = recordedBeta();
	if (recorded) {
		console.log(installMarkdown(releaseNumber(recorded.version), recorded.subscriberPackageVersionId, willPromote(recorded)));
	}
}

const [command, ...options] = process.argv.slice(2);
const devHubIndex = options.indexOf('--target-dev-hub');
const devHub = devHubIndex === -1 ? undefined : options[devHubIndex + 1];

if (command === 'create') {
	create(devHub, options.includes('--skip-validation'), options.includes('--keep-beta'));
} else if (command === 'check') {
	check();
} else if (command === 'promote') {
	promote(devHub);
} else if (command === 'links') {
	links();
} else if (command === 'notes') {
	notes();
} else if (command === 'has-package') {
	console.log(Boolean(packageDirectory(readJson(PROJECT_FILE)).package));
} else {
	fail(
		'Usage: node scripts/package-version.mjs create [--target-dev-hub <alias>] [--skip-validation] [--keep-beta] | check | promote [--target-dev-hub <alias>] | links | notes | has-package'
	);
}
