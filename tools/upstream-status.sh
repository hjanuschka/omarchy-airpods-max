#!/usr/bin/env bash
# Print the live state of everything sent upstream, and what is still carried here.
set -euo pipefail

PRS=(
  "thisisgm/omarchy-pods 73"
  "thisisgm/omarchy-pods 74"
)
# Not ours, but this work sits on top of it, so its state matters.
WATCH=("kavishdevar/librepods 655")

row() {
  local repo=$1 num=$2 tag=$3
  gh pr view "$num" --repo "$repo" \
     --json number,title,state,isDraft,mergeable,updatedAt \
     --template "  {{.number}}  {{.state}}{{if .isDraft}} (draft){{end}}  {{.title}}
      $tag, updated {{timeago .updatedAt}}
" 2>/dev/null || echo "  $num  (could not read $repo)"
}

echo "Sent upstream:"
for entry in "${PRS[@]}"; do row ${entry} "ours"; done
echo "Depends on:"
for entry in "${WATCH[@]}"; do row ${entry} "not ours; this work ports it"; done
echo "Carried here, not sent:"
echo "  patches/*.patch applies onto the pinned base in install.sh"
