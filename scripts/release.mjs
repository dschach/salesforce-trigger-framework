#!/usr/bin/env node
// Releases the framework: it creates the beta package version on the release branch,
// commits the ids, waits for the required checks, and merges the release pull request.
// The Release workflow runs it from its button. It also runs on a computer with the gh
// and sf command lines, signed in, and a clean working tree.
//
// The steps, in order:
// 1. Find the 1 open pull request of Release Please, by its "autorelease: pending" label.
// 2. Check out its head commit.
// 3. When sfdx-project.json names a package: create the beta with
//    scripts/package-version.mjs, format the changed files, check the ids, commit them,
//    and push the commit to the release branch. When the branch already has ids that
//    belong to its code, for example after a run that stopped after its push, it skips
//    this step.
// 4. Wait until the required checks pass on the head commit of the pull request.
// 5. Squash-merge the pull request, but only while its head is still that commit. If
//    another merge to main made Release Please rewrite the branch, the merge stops.
// After the merge, CI on main creates the release and the tag, deploys the site, and
// promotes the beta.
//
// With --dry-run, step 3 creates a beta with --skip-validation, which cannot be promoted,
// shows the changes, and stops. Nothing is committed, pushed, or merged.
// With --keep-beta, the version stays a beta after the release: the promote-package job
// in ci.yml reads that choice from package-version.json in the tag.
// --use-current-checkout skips step 2 in a dry run, to test with local changes.
//
// Usage: node scripts/release.mjs [--dry-run] [--keep-beta] [--use-current-checkout] [--target-dev-hub <alias>]

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const RELEASE_LABEL = 'autorelease: pending';
const RELEASE_BRANCH = 'release-please--branches--main';
const REQUIRED_CHECKS = ['format-lint', 'sfca-analysis', 'package-ids'];
const ID_FILES = ['sfdx-project.json', 'package-version.json', 'README.md', 'doc-assets/homePage.html', 'docs/index.html'];
const CHECK_WAIT_MINUTES = 40;
const POLL_SECONDS = 20;

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const keepBeta = args.includes('--keep-beta');
const useCurrentCheckout = args.includes('--use-current-checkout');
const devHubIndex = args.indexOf('--target-dev-hub');
const devHub = devHubIndex === -1 ? undefined : args[devHubIndex + 1];

// After the checkout, every exit goes back to the starting branch with a clean tree.
let needsRestore = false;

function fail(message) {
	if (needsRestore) {
		needsRestore = false;
		try {
			restore();
		} catch (error) {
			console.error(`The checkout was not restored: ${error.message}`);
		}
	}
	console.error(message);
	process.exit(1);
}

process.on('uncaughtException', (error) => fail(error.message));

function run(command, commandArgs) {
	return execFileSync(command, commandArgs, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }).trim();
}

function show(command, commandArgs) {
	execFileSync(command, commandArgs, { stdio: 'inherit' });
}

// The promote choice in package-version.json. A file without the field means promote.
function recordedPromote() {
	return JSON.parse(readFileSync('package-version.json', 'utf8')).promote !== false;
}

// Runs a command quietly and tells whether it passed.
function succeeds(command, commandArgs) {
	try {
		execFileSync(command, commandArgs, { stdio: 'ignore' });
		return true;
	} catch {
		return false;
	}
}

function sleep(seconds) {
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, seconds * 1000);
}

if (useCurrentCheckout && !dryRun) {
	fail('--use-current-checkout works only with --dry-run.');
}

const repo = process.env.GITHUB_REPOSITORY ?? run('gh', ['repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner']);

// 1. The release pull request.
const pulls = JSON.parse(
	run('gh', ['pr', 'list', '--repo', repo, '--state', 'open', '--label', RELEASE_LABEL, '--json', 'number,title,body,headRefName,headRefOid,baseRefName,isCrossRepository'])
);
if (pulls.length !== 1) {
	fail(`Expected 1 open pull request with the label "${RELEASE_LABEL}", but found ${pulls.length}.`);
}
const pull = pulls[0];
if (pull.baseRefName !== 'main' || pull.headRefName !== RELEASE_BRANCH || pull.isCrossRepository) {
	fail(`Pull request #${pull.number} is not the release pull request of Release Please for main.`);
}
console.log(`Release pull request: #${pull.number} ${pull.title}, head ${pull.headRefOid}.`);

// 2. Its head commit.
if (run('git', ['status', '--porcelain'])) {
	fail('The working tree has changes. Commit or stash them first.');
}
const startRef = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
if (useCurrentCheckout) {
	console.log('Dry run on the current checkout, not on the release branch.');
} else {
	run('git', ['fetch', '--no-tags', 'origin', `refs/heads/${RELEASE_BRANCH}`]);
	if (run('git', ['rev-parse', 'FETCH_HEAD']) !== pull.headRefOid) {
		fail(`The release branch moved while the script ran. Run it again.`);
	}
	run('git', ['switch', '--quiet', '--detach', pull.headRefOid]);
}
needsRestore = true;

// The tree was clean at the start, so a hard reset removes only what this script wrote.
function restore() {
	run('git', ['reset', '--quiet', '--hard']);
	run('git', ['clean', '--quiet', '--force', '--', 'package-version.json']);
	if (!useCurrentCheckout && startRef !== 'HEAD') {
		run('git', ['switch', '--quiet', startRef]);
	}
}

// 3. The beta and its ids.
let headSha = pull.headRefOid;
const hasPackage = run('node', ['scripts/package-version.mjs', 'has-package']) === 'true';
if (!hasPackage) {
	console.log('sfdx-project.json names no package, so the release has no package version.');
} else if (!useCurrentCheckout && succeeds('node', ['scripts/package-version.mjs', 'check']) && recordedPromote() === !keepBeta) {
	// A run that stopped after its push left valid ids on the branch. They still belong to
	// the code, and they have the promote choice of this run, so this run uses them and
	// builds no extra beta.
	console.log('The release branch already has the ids of a beta that belongs to its code, so no new beta is built.');
} else {
	const createArgs = ['scripts/package-version.mjs', 'create'];
	if (devHub) {
		createArgs.push('--target-dev-hub', devHub);
	}
	if (dryRun) {
		createArgs.push('--skip-validation');
	}
	if (keepBeta) {
		createArgs.push('--keep-beta');
	}
	show('node', createArgs);
	show('npx', ['prettier', '--write', ...ID_FILES]);
	show('node', ['scripts/package-version.mjs', 'check']);
	if (!dryRun) {
		run('git', ['add', ...ID_FILES]);
		show('git', ['commit', '--quiet', '-m', 'build(package): add the ids of the beta package version']);
		run('git', ['push', '--quiet', 'origin', `HEAD:refs/heads/${RELEASE_BRANCH}`]);
		headSha = run('git', ['rev-parse', 'HEAD']);
		console.log(`Pushed ${headSha} to ${RELEASE_BRANCH}.`);
	}
}

if (dryRun) {
	console.log('Dry run: these files would be committed to the release branch.');
	show('git', ['status', '--short']);
	show('git', ['--no-pager', 'diff', '--stat']);
	restore();
	needsRestore = false;
	console.log(`Dry run: nothing was committed, pushed, or merged. Pull request #${pull.number} stays open.`);
	process.exit(0);
}

// 4. The required checks of the head commit.
console.log(`Waiting for ${REQUIRED_CHECKS.join(', ')} on ${headSha}.`);
const deadline = Date.now() + CHECK_WAIT_MINUTES * 60 * 1000;
for (;;) {
	const state = JSON.parse(run('gh', ['pr', 'view', String(pull.number), '--repo', repo, '--json', 'headRefOid,statusCheckRollup']));
	// For some seconds after the push, GitHub can still report the old head. Wait for it.
	if (state.headRefOid !== headSha && state.headRefOid === pull.headRefOid) {
		if (Date.now() > deadline) {
			fail(`GitHub did not show the pushed commit ${headSha} in ${CHECK_WAIT_MINUTES} minutes. Pull request #${pull.number} stays open.`);
		}
		sleep(POLL_SECONDS);
		continue;
	}
	if (state.headRefOid !== headSha) {
		fail(`The release branch changed to ${state.headRefOid} before the merge. Run the Release workflow again.`);
	}
	// The newest run of each check counts, so that a check that was run again counts once.
	const latest = new Map();
	for (const check of state.statusCheckRollup) {
		latest.set(check.name, check);
	}
	const failed = REQUIRED_CHECKS.filter((name) => ['FAILURE', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED'].includes(latest.get(name)?.conclusion));
	if (failed.length > 0) {
		fail(`These required checks failed: ${failed.join(', ')}. Pull request #${pull.number} stays open.`);
	}
	// A skipped job counts as passed, as GitHub counts it for a required check. The release
	// pull request skips sfca-analysis, because it changes no Apex.
	if (REQUIRED_CHECKS.every((name) => ['SUCCESS', 'SKIPPED'].includes(latest.get(name)?.conclusion))) {
		break;
	}
	if (Date.now() > deadline) {
		fail(`The required checks did not finish in ${CHECK_WAIT_MINUTES} minutes. Pull request #${pull.number} stays open.`);
	}
	sleep(POLL_SECONDS);
}

// 5. The merge, only while the head is the checked commit.
const work = mkdtempSync(join(tmpdir(), 'release-'));
try {
	const bodyFile = join(work, 'body.md');
	writeFileSync(bodyFile, pull.body);
	show('gh', [
		'pr',
		'merge',
		String(pull.number),
		'--repo',
		repo,
		'--squash',
		'--match-head-commit',
		headSha,
		'--subject',
		`${pull.title} (#${pull.number})`,
		'--body-file',
		bodyFile
	]);
} finally {
	rmSync(work, { recursive: true, force: true });
}
restore();
needsRestore = false;
console.log(
	`Merged #${pull.number}. CI on main now creates the release, deploys the site, and ${keepBeta ? 'leaves the package version a beta' : 'promotes the package version'}.`
);
