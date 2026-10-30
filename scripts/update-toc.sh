#!/bin/sh
# Regenerate the table of contents between the <!-- toc --> and <!-- tocstop --> markers
# of each markdown file given. markdown-toc takes only 1 file per call, and lint-staged
# passes every staged markdown file at once, so this script calls it once for each file.
# A file without the markers is left unchanged.
#
# lint-staged runs this on every staged markdown file in each commit.
#
# Usage: sh scripts/update-toc.sh <file>...

set -eu

# The deepest heading level that each file's table of contents lists, as "path depth",
# 1 file per line. The path is from the repository root. A file that is not listed gets
# the default of markdown-toc, which lists every heading level.
MAX_DEPTHS='
README.md 2
'

# The binary that npm installs, so that npx cannot read the -i flag as its own
markdown_toc="$(dirname "$0")/../node_modules/.bin/markdown-toc"
repo_root="$(git rev-parse --show-toplevel)"

for file in "$@"; do
  # lint-staged passes absolute paths; the map uses paths from the repository root
  case "$file" in
    "$repo_root"/*) path="${file#"$repo_root"/}" ;;
    ./*) path="${file#./}" ;;
    *) path="$file" ;;
  esac
  depth="$(printf '%s\n' "$MAX_DEPTHS" | awk -v path="$path" '$1 == path { print $2 }')"
  if [ -n "$depth" ]; then
    "$markdown_toc" -i --bullets '-' --maxdepth "$depth" "$file"
  else
    "$markdown_toc" -i --bullets '-' "$file"
  fi
done
