# Renders README.md from $template and the response to query.graphql.

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

.data.user
| ([.pullRequests.nodes[] | select(.repository | listed and (own_fork | not))][:10]
   | map("- [\(.title | text)](\(.url)) on \(.repository | link) (\(.createdAt | ago))") | lines) as $prs
| ([.contributionsCollection.commitContributionsByRepository[] | select(.repository | listed)
    | .repository + {at: .contributions.nodes[0].occurredAt}] | sort_by(.at) | reverse | .[:10]
   | map("- \(link) - \(.description | text) (\(.at | ago))") | lines) as $contributions
| ([.starredRepositories.edges[] | select(.node | .isPrivate | not)]
   | map("- \(.node | link) - \(.node.description | text) (\(.starredAt | ago))") | lines) as $stars
| $template
| split("@@PULL_REQUESTS@@") | join($prs)
| split("@@CONTRIBUTIONS@@") | join($contributions)
| split("@@STARS@@") | join($stars)
