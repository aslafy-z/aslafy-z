#!/bin/sh
# Generates README.md for $LOGIN. Run from the repository root.
set -eu

dir=.github/readme
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gh api graphql -F login="$LOGIN" -F query=@"$dir/activity.graphql" > "$tmp/activity.json"
author=$(jq -r .data.user.id "$tmp/activity.json")
since=$(jq -rn 'now - 365 * 86400 | todate')
gh api graphql --paginate --slurp -F login="$LOGIN" -f author="$author" -f since="$since" \
  -F query=@"$dir/releases.graphql" > "$tmp/releases.json"

jq -j --arg login "$LOGIN" --rawfile template README.md.tmpl --slurpfile releases "$tmp/releases.json" \
  -f "$dir/render.jq" "$tmp/activity.json" > "$tmp/README.md"
cp "$tmp/README.md" README.md
