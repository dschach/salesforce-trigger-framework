#!/usr/bin/env bash
# Delete the local branches whose remote branch is gone.
#
# A pull request merged with --delete-branch deletes its remote branch. This project
# merges by squash, so git branch -d cannot tell that such a branch is merged; the
# deleted remote branch is the sign instead. A branch that was never pushed has no
# remote branch and is never deleted, and neither is the branch that is checked out.
#
# Run from the repository: npm run prune

set -euo pipefail

git fetch --prune --quiet

current=$(git branch --show-current)
deleted=0
while read -r branch track; do
  if [ "$track" != "[gone]" ]; then
    continue
  fi
  if [ "$branch" = "$current" ]; then
    echo "Skipping $branch: it is checked out."
    continue
  fi
  git branch -D "$branch"
  deleted=$((deleted + 1))
done < <(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads)

echo "Deleted $deleted local branch(es) whose remote branch is gone."
