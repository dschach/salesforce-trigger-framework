#!/bin/sh
# Prepare the input of the ApexDox site: refresh the highlight.js bundle, and build the
# HTML pages that the site uses from the README, the changelog, the deploy instructions,
# and the sample handler README. It also copies the current sample code into
# sample-handler/README.md, so that file can change in the working tree. On the home
# page, it replaces each Mermaid diagram of the README with an SVG, which needs Google
# Chrome or a browser in PUPPETEER_EXECUTABLE_PATH (see scripts/render-mermaid.mjs).
#
# Run from the repository root: npm run prepareApexDox

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
# marked 18 writes no heading ids, so the table of contents links need them (see scripts/add-heading-ids.mjs).
node scripts/add-heading-ids.mjs "doc-assets/homePage.html"
replace_in_file 's|DEPLOY.md|deploy.html|g' "doc-assets/homePage.html"
replace_in_file 's|sample-handler/README.md|sampletriggerhandlerhome.html|g' "doc-assets/homePage.html"
# The site shows the Mermaid diagrams of the README as SVG, because marked shows them as code.
node scripts/render-mermaid.mjs "doc-assets/homePage.html"

# Changelog to web page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/changelog.html"
echo >> "doc-assets/files/changelog.html"
npx marked -i CHANGELOG.md --gfm >> "doc-assets/files/changelog.html"
node scripts/add-heading-ids.mjs "doc-assets/files/changelog.html"
replace_in_file 's|CHANGELOG.md|changelog.html|g' "doc-assets/homePage.html"

# Deploy instructions to docs page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/deploy.html"
echo >> "doc-assets/files/deploy.html"
npx marked -i DEPLOY.md --gfm >> "doc-assets/files/deploy.html"
node scripts/add-heading-ids.mjs "doc-assets/files/deploy.html"
replace_in_file 's|href="./|target="_blank" href="https://github.com/dschach/salesforce-trigger-framework/tree/main/|g' "doc-assets/files/deploy.html"

# Sample handler README to the page of the sample group, which the @group-content tag of
# AccountSampleTriggerHandler names. The README links to the main README, which is the
# site's index page. First copy the current sample code into the README.
node scripts/sync-sample-code.mjs
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/sampletriggerhandlerhome.html"
echo >> "doc-assets/files/sampletriggerhandlerhome.html"
npx marked -i sample-handler/README.md --gfm >> "doc-assets/files/sampletriggerhandlerhome.html"
node scripts/add-heading-ids.mjs "doc-assets/files/sampletriggerhandlerhome.html"
replace_in_file 's|\.\./README\.md|index.html|g' "doc-assets/files/sampletriggerhandlerhome.html"
