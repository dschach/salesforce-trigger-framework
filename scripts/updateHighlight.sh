#!/bin/sh

curl -L "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js" -o "doc-assets/highlight.js"
echo >> "assets/highlight.js"
curl -L "https://cdn.jsdelivr.net/npm/highlightjs-apex/dist/apex.min.js" >> "doc-assets/highlight.js"

npx marked -i README.md -o doc-assets/homePage.html smartypants=true
echo >> "doc-assets/homePage.html"
printf '<link href="assets/styling.css" rel="stylesheet" />' >> "doc-assets/homePage.html"
npx prettier --write "doc-assets/homePage.html"