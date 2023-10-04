#!/bin/sh

# update highlight.js version
curl -L "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js" -o "doc-assets/highlight.js"
echo >> "assets/highlight.js"
curl -L "https://cdn.jsdelivr.net/npm/highlightjs-apex/dist/apex.min.js" >> "doc-assets/highlight.js"

# README to docs homepage
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/homePage.html"
echo >> "doc-assets/homePage.html"
npx marked -i README.md --gfm >> "doc-assets/homePage.html"
sed -i '' 's|DEPLOY.md|deploy.html|g' doc-assets/homePage.html

# Changelog to web page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/changelog.html"
echo >> "doc-assets/changelog.html"
npx marked -i CHANGELOG.md --gfm >> "doc-assets/files/changelog.html"
sed -i '' 's|CHANGELOG.md|changelog.html|g' doc-assets/homePage.html

# Deploy instructions to docs page
printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/deploy.html"
echo >> "doc-assets/files/deploy.html"
npx marked -i DEPLOY.md --gfm >> "doc-assets/files/deploy.html"
sed -i '' 's|href="./|target="_blank" href="https://github.com/dschach/salesforce-trigger-framework/tree/main/|g' doc-assets/files/deploy.html
