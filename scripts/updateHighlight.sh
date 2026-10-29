#!/bin/sh
# Refresh the highlight.js bundle and the HTML pages that the ApexDox site builds from
# the README, the changelog, and the deploy instructions.
#
# Run from the repository root: npm run updateHighlight

set -eu

# Replace text in a file. The .bak suffix makes sed -i work with both the BSD sed of
# macOS and GNU sed; the backup is removed right away.
replace_in_file() {
  sed -i.bak "$1" "$2"
  rm -f "$2.bak"
}

# update highlight.js version
curl -fsSL "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js" -o "doc-assets/highlight.js"
echo >> "doc-assets/highlight.js"
curl -fsSL "https://cdn.jsdelivr.net/npm/highlightjs-apex/dist/apex.min.js" >> "doc-assets/highlight.js"

# README to docs homepage
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/homePage.html"
echo >> "doc-assets/homePage.html"
npx marked -i README.md --gfm >> "doc-assets/homePage.html"
replace_in_file 's|DEPLOY.md|deploy.html|g' "doc-assets/homePage.html"

# Changelog to web page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/changelog.html"
echo >> "doc-assets/files/changelog.html"
npx marked -i CHANGELOG.md --gfm >> "doc-assets/files/changelog.html"
replace_in_file 's|CHANGELOG.md|changelog.html|g' "doc-assets/homePage.html"

# Deploy instructions to docs page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/deploy.html"
echo >> "doc-assets/files/deploy.html"
npx marked -i DEPLOY.md --gfm >> "doc-assets/files/deploy.html"
replace_in_file 's|href="./|target="_blank" href="https://github.com/dschach/salesforce-trigger-framework/tree/main/|g' "doc-assets/files/deploy.html"
