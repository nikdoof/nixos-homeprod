#!/usr/bin/env bash
# Delete all mirrored repositories owned by a Gitea user.
# Defaults to dry-run; pass --execute to actually delete.
set -euo pipefail

GITEA_URL="https://git.doofnet.uk"
GITEA_USER="nikdoof"
DRY_RUN=true

usage() {
  echo "Usage: GITEA_TOKEN=<token> $0 [--execute]"
  echo "  --execute   Actually delete (default is dry-run)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --execute) DRY_RUN=false; shift ;;
    *) usage ;;
  esac
done

if [[ -z "${GITEA_TOKEN:-}" ]]; then
  echo "Error: GITEA_TOKEN must be set" >&2
  exit 1
fi

echo "Mode:   $([ "$DRY_RUN" = true ] && echo 'DRY RUN (pass --execute to delete)' || echo 'EXECUTE')"
echo "Target: ${GITEA_URL} / user ${GITEA_USER}"
echo

page=1
limit=50
count=0

while true; do
  response=$(curl -sf \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/user/repos?limit=${limit}&page=${page}")

  page_count=$(echo "$response" | jq '. | length')

  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    count=$((count + 1))
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] ${GITEA_USER}/${repo}"
    else
      echo "Deleting ${GITEA_USER}/${repo}"
      curl -sf -X DELETE \
        -H "Authorization: token ${GITEA_TOKEN}" \
        "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${repo}"
    fi
  done < <(echo "$response" | jq -r \
    --arg user "$GITEA_USER" \
    '.[] | select(.mirror == true and .owner.login == $user) | .name')

  [[ "$page_count" -lt "$limit" ]] && break
  page=$((page + 1))
done

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "Found ${count} mirrored repo(s) — rerun with --execute to delete"
else
  echo "Deleted ${count} mirrored repo(s)"
fi
