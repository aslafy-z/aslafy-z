# Renders README.md from $template, the response to activity.graphql, and the
# pages of releases.graphql in $releases.

def ago: (now - fromdate) as $s
  | [[31536000,"year"],[2592000,"month"],[604800,"week"],[86400,"day"],[3600,"hour"],[60,"minute"]]
  | map(select($s >= .[0])) | first // [null,null]
  | if .[0] then (($s / .[0] | floor) as $n | "\($n) \(.[1])\(if $n > 1 then "s" else "" end) ago") else "now" end;
def link: "[\(.nameWithOwner)](\(.url))";
# Titles and descriptions are third-party text, so HTML is escaped.
def text: . // "" | @html;
def listed: (.isPrivate or .nameWithOwner == "\($login)/\($login)") | not;
# Pull requests on my own forks are drafts for upstream.
def own_fork: .isFork and .owner.login == $login;
def lines: join("\n");
# The first stable release containing my most recent commits. When older
# releases exist beyond the fetched ones, a commit must be newer than the oldest
# fetched release, otherwise it may have shipped earlier.
def shipped:
  [.releases.nodes[] | select(.isDraft | not)] as $all
  | ($all | map(.publishedAt) | min) as $oldest
  | (.releases.totalCount > (.releases.nodes | length)) as $truncated
  | [$all[] | select(.isPrerelease | not) | . + {commit: .tagCommit.history.nodes[0]} | select(.commit)]
  | group_by(.commit.oid) | map(min_by(.publishedAt))
  | map(select(($truncated | not) or .commit.committedDate > $oldest))
  | max_by(.publishedAt);

.data.user
| ([.pullRequests.nodes[] | select(.repository | listed and (own_fork | not))][:10]
   | map("- [\(.title | text)](\(.url)) on \(.repository | link) (\(.createdAt | ago))") | lines) as $prs
| ([.contributionsCollection.commitContributionsByRepository[] | select(.repository | listed)
    | .repository + {at: .contributions.nodes[0].occurredAt}] | sort_by(.at) | reverse | .[:10]
   | map("- \(link) - \(.description | text) (\(.at | ago))") | lines) as $contributions
| ([.starredRepositories.edges[] | select(.node | .isPrivate | not)]
   | map("- \(.node | link) - \(.node.description | text) (\(.starredAt | ago))") | lines) as $stars
| ([$releases[0][].data.user.repositoriesContributedTo.nodes[] | select(listed and (own_fork | not))
    | . + {release: shipped} | select(.release)] | sort_by(.release.publishedAt) | reverse | .[:10]
   | map("- \(link) ([\(.release.tagName | text)](\(.release.url)), \(.release.publishedAt | ago))") | lines) as $shipped
| $template
| split("@@PULL_REQUESTS@@") | join($prs)
| split("@@CONTRIBUTIONS@@") | join($contributions)
| split("@@RELEASES@@") | join($shipped)
| split("@@STARS@@") | join($stars)
