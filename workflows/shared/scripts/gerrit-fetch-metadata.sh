#!/usr/bin/env bash
#
# Gerrit REST API Metadata Fetch Script
# Fetches change metadata from Gerrit via REST API without MCP
#
# Usage: gerrit-fetch-metadata.sh <change_id>
# Exit codes: 0=success, 1=failed, 2=invalid args

set -euo pipefail

# Constants
GERRIT_BASE_URL="https://review.opendev.org"
CURL_TIMEOUT=10

# Validate arguments
if [ $# -ne 1 ]; then
    echo "ERROR: Usage: gerrit-fetch-metadata.sh <change_id>" >&2
    exit 2
fi

CHANGE_INPUT="$1"

# Extract numeric change ID from URL if needed
if [[ "$CHANGE_INPUT" =~ \+/([0-9]+) ]]; then
    CHANGE_ID="${BASH_REMATCH[1]}"
elif [[ "$CHANGE_INPUT" =~ ^[0-9]+$ ]]; then
    CHANGE_ID="$CHANGE_INPUT"
else
    echo "ERROR: Invalid change ID format: $CHANGE_INPUT" >&2
    echo "Expected: numeric ID or Gerrit URL" >&2
    exit 2
fi

# Fetch change metadata via REST API (with CURRENT_REVISION option)
response_file=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
    --max-time "$CURL_TIMEOUT" \
    "${GERRIT_BASE_URL}/changes/${CHANGE_ID}/detail?o=CURRENT_REVISION" \
    2>/dev/null || echo "000")

# Handle HTTP errors
case "$http_code" in
    200)
        # Success - continue processing
        ;;
    404)
        echo "ERROR: Change $CHANGE_ID not found (HTTP 404)" >&2
        rm -f "$response_file"
        exit 1
        ;;
    000)
        echo "ERROR: Failed to connect to ${GERRIT_BASE_URL} (Connection timeout)" >&2
        rm -f "$response_file"
        exit 1
        ;;
    *)
        echo "ERROR: HTTP $http_code from Gerrit" >&2
        if [ -f "$response_file" ] && [ -s "$response_file" ]; then
            head -3 "$response_file" >&2
        fi
        rm -f "$response_file"
        exit 1
        ;;
esac

# Remove anti-XSSI prefix (first line: )]}'  )
raw_json=$(tail -n +2 "$response_file")
rm -f "$response_file"

# Validate JSON is parseable
if ! echo "$raw_json" | jq empty 2>/dev/null; then
    echo "ERROR: Failed to parse Gerrit response (invalid JSON)" >&2
    exit 1
fi

# Extract required fields
SUBJECT=$(echo "$raw_json" | jq -r '.subject // empty')
AUTHOR_NAME=$(echo "$raw_json" | jq -r '.owner.name // empty')
AUTHOR_EMAIL=$(echo "$raw_json" | jq -r '.owner.email // empty')
COMMIT_HASH=$(echo "$raw_json" | jq -r '.current_revision // empty')
STATUS=$(echo "$raw_json" | jq -r '.status // empty')
PROJECT=$(echo "$raw_json" | jq -r '.project // empty')
BRANCH=$(echo "$raw_json" | jq -r '.branch // empty')
TOPIC=$(echo "$raw_json" | jq -r '.topic // empty')
CREATED=$(echo "$raw_json" | jq -r '.created // empty')
UPDATED=$(echo "$raw_json" | jq -r '.updated // empty')

# Validate required fields are present
if [ -z "$SUBJECT" ] || [ -z "$AUTHOR_NAME" ] || [ -z "$COMMIT_HASH" ] || [ -z "$STATUS" ] || [ -z "$PROJECT" ] || [ -z "$BRANCH" ]; then
    echo "ERROR: Missing required fields in Gerrit response" >&2
    echo "subject: $SUBJECT" >&2
    echo "owner.name: $AUTHOR_NAME" >&2
    echo "current_revision: $COMMIT_HASH" >&2
    echo "status: $STATUS" >&2
    echo "project: $PROJECT" >&2
    echo "branch: $BRANCH" >&2
    exit 1
fi

# Construct author field
AUTHOR="${AUTHOR_NAME} <${AUTHOR_EMAIL}>"

# Output JSON result using jq for proper escaping
jq -n \
    --arg change_id "$CHANGE_ID" \
    --arg subject "$SUBJECT" \
    --arg author "$AUTHOR" \
    --arg commit_hash "$COMMIT_HASH" \
    --arg status "$STATUS" \
    --arg project "$PROJECT" \
    --arg branch "$BRANCH" \
    --arg topic "$TOPIC" \
    --arg current_revision "$COMMIT_HASH" \
    --arg created "$CREATED" \
    --arg updated "$UPDATED" \
    '{
        change_id: $change_id,
        subject: $subject,
        author: $author,
        commit_hash: $commit_hash,
        status: $status,
        project: $project,
        branch: $branch,
        topic: $topic,
        current_revision: $current_revision,
        created: $created,
        updated: $updated
    }'

exit 0
