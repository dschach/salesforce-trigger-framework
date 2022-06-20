#!/bin/sh

curl -L "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js" -o "doc-assets/highlight.js"
echo >> "assets/highlight.js"
curl -L "https://cdn.jsdelivr.net/npm/highlightjs-apex/dist/apex.min.js" >> "doc-assets/highlight.js"

printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/homePage.html"
echo >> "doc-assets/homePage.html"
npx marked -i README.md --gfm >> "doc-assets/homePage.html"

sed -i '' 's|href="./|target="_blank" href="https://github.com/dschach/salesforce-trigger-framework/tree/main/|g' doc-assets/homePage.html

npx prettier --write "doc-assets/homePage.html"