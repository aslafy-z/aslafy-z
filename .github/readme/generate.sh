#!/bin/sh
# Generates README.md for $README_USER. Run from the repository root.
set -eu

dir=.github/readme
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gh api graphql -F login="$README_USER" -F query=@"$dir/activity.graphql" > "$tmp/activity.json"
author=$(jq -r .data.user.id "$tmp/activity.json")
since=$(jq -rn 'now - 365 * 86400 | todate')
gh api graphql --paginate --slurp -F login="$README_USER" -f author="$author" -f since="$since" \
  -F query=@"$dir/releases.graphql" > "$tmp/releases.json"

gh api graphql --paginate --slurp -f search="is:pr is:public author:$README_USER user:$README_USER" \
  -F query=@"$dir/forks.graphql" > "$tmp/forks.json"

jq -j --arg login "$README_USER" --rawfile template README.md.tmpl \
  --slurpfile releases "$tmp/releases.json" --slurpfile forks "$tmp/forks.json" \
  -f "$dir/render.jq" "$tmp/activity.json" > "$tmp/README.md"
cp "$tmp/README.md" README.md
