// The markdown toolbar at the top of each page of the documentation site.
// scripts/build-markdown-site.mjs adds the toolbar HTML to each page and copies this file
// to assets/. The toolbar names the markdown copy of the page in data-markdown, and
// llms.txt in data-llms.
(function () {
	'use strict';

	var STATUS_SECONDS = 3;

	function absoluteUrl(path) {
		return new URL(path, window.location.href).href;
	}

	function showStatus(toolbar, message) {
		var status = toolbar.querySelector('.markdown-tools__status');
		status.textContent = message;
		window.clearTimeout(status.timer);
		status.timer = window.setTimeout(function () {
			status.textContent = '';
		}, STATUS_SECONDS * 1000);
	}

	// The old copy command needs no clipboard permission. It must run inside the click.
	function copyWithCommand(text) {
		var area = document.createElement('textarea');
		area.value = text;
		area.setAttribute('readonly', '');
		area.style.position = 'fixed';
		area.style.opacity = '0';
		document.body.appendChild(area);
		area.select();
		var copied = false;
		try {
			copied = document.execCommand('copy');
		} catch (error) {
			copied = false;
		}
		document.body.removeChild(area);
		return copied;
	}

	// Copies the text at once, inside the click, because some browsers allow a clipboard
	// write only there. The old copy command comes first, because it runs inside the click;
	// the Clipboard API is the second try.
	function copyText(toolbar, text, done) {
		var failed = 'Could not copy. Use View as Markdown instead.';
		if (text === null) {
			showStatus(toolbar, 'The markdown is still loading. Try again in a moment.');
			return;
		}
		if (copyWithCommand(text)) {
			showStatus(toolbar, done);
			return;
		}
		if (!navigator.clipboard) {
			showStatus(toolbar, failed);
			return;
		}
		navigator.clipboard.writeText(text).then(
			function () {
				showStatus(toolbar, done);
			},
			function () {
				showStatus(toolbar, failed);
			}
		);
	}

	function setUp(toolbar) {
		var toggle = toolbar.querySelector('.markdown-tools__toggle');
		var menu = toolbar.querySelector('.markdown-tools__menu');
		// The markdown loads with the page, so that Copy as Markdown can copy inside the click.
		var markdown = null;
		fetch(toolbar.dataset.markdown)
			.then(function (response) {
				return response.ok ? response.text() : null;
			})
			.then(function (text) {
				markdown = text;
			})
			.catch(function () {
				markdown = null;
			});

		function setMenu(open) {
			menu.hidden = !open;
			toggle.setAttribute('aria-expanded', String(open));
		}

		toggle.addEventListener('click', function () {
			setMenu(menu.hidden);
		});
		document.addEventListener('click', function (event) {
			if (!menu.hidden && !toolbar.contains(event.target)) {
				setMenu(false);
			}
		});
		toolbar.addEventListener('keydown', function (event) {
			if (event.key === 'Escape' && !menu.hidden) {
				setMenu(false);
				toggle.focus();
			}
		});
		menu.addEventListener('click', function (event) {
			if (event.target.closest('a, button')) {
				setMenu(false);
			}
		});

		toolbar.addEventListener('click', function (event) {
			var button = event.target.closest('[data-action]');
			if (!button) {
				return;
			}
			var action = button.dataset.action;
			if (action === 'copy-markdown') {
				copyText(toolbar, markdown, 'Copied the markdown of this page.');
			} else if (action === 'copy-markdown-url') {
				copyText(toolbar, absoluteUrl(toolbar.dataset.markdown), 'Copied the URL of the markdown.');
			} else if (action === 'copy-llms-url') {
				copyText(toolbar, absoluteUrl(toolbar.dataset.llms), 'Copied the URL of llms.txt.');
			}
		});
	}

	document.addEventListener('DOMContentLoaded', function () {
		document.querySelectorAll('.markdown-tools').forEach(setUp);
	});
})();
