#!/usr/bin/env bash
#
# Launchpad REST API Bug Fetch Script
# Fetches bug details from Launchpad via REST API without MCP
#
# Usage: launchpad-fetch-bug.sh <bug_id>
# Exit codes: 0=success, 1=not found, 2=invalid args, 3=API error

set -euo pipefail

# Constants
LAUNCHPAD_API_URL="https://api.launchpad.net/1.0"
CURL_TIMEOUT=10
MAX_MESSAGES=10

# Validate arguments
if [ $# -ne 1 ]; then
    echo "ERROR: Usage: launchpad-fetch-bug.sh <bug_id>" >&2
    exit 2
fi

BUG_INPUT="$1"

# Extract numeric bug ID from URL if needed
if [[ "$BUG_INPUT" =~ bugs\.launchpad\.net/.*/\+bug/([0-9]+) ]]; then
    BUG_ID="${BASH_REMATCH[1]}"
elif [[ "$BUG_INPUT" =~ ^[0-9]+$ ]]; then
    BUG_ID="$BUG_INPUT"
else
    echo "ERROR: Invalid bug ID format: $BUG_INPUT" >&2
    echo "Expected: numeric ID or Launchpad URL (e.g., https://bugs.launchpad.net/nova/+bug/123456)" >&2
    exit 2
fi

# --- Fetch bug details ---
bug_file=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$bug_file" \
    --max-time "$CURL_TIMEOUT" \
    "${LAUNCHPAD_API_URL}/bugs/${BUG_ID}" \
    2>/dev/null || echo "000")

case "$http_code" in
    200)
        ;;
    404)
        echo "ERROR: Bug $BUG_ID not found (HTTP 404)" >&2
        rm -f "$bug_file"
        exit 1
        ;;
    401)
        echo "ERROR: Bug $BUG_ID is private and requires authentication (HTTP 401)" >&2
        rm -f "$bug_file"
        exit 1
        ;;
    000)
        echo "ERROR: Failed to connect to Launchpad API (connection timeout)" >&2
        rm -f "$bug_file"
        exit 3
        ;;
    *)
        echo "ERROR: HTTP $http_code from Launchpad API" >&2
        rm -f "$bug_file"
        exit 3
        ;;
esac

bug_json=$(cat "$bug_file")
rm -f "$bug_file"

if ! echo "$bug_json" | jq empty 2>/dev/null; then
    echo "ERROR: Failed to parse Launchpad response (invalid JSON)" >&2
    exit 3
fi

# --- Fetch bug tasks (project-specific status/importance) ---
tasks_file=$(mktemp)
tasks_url=$(echo "$bug_json" | jq -r '.bug_tasks_collection_link // empty')

if [ -n "$tasks_url" ]; then
    tasks_http=$(curl -s -w "%{http_code}" -o "$tasks_file" \
        --max-time "$CURL_TIMEOUT" \
        "$tasks_url" \
        2>/dev/null || echo "000")

    if [ "$tasks_http" = "200" ]; then
        tasks_json=$(cat "$tasks_file")
    else
        tasks_json='{"entries":[]}'
    fi
else
    tasks_json='{"entries":[]}'
fi
rm -f "$tasks_file"

# --- Fetch recent messages ---
messages_file=$(mktemp)
messages_url=$(echo "$bug_json" | jq -r '.messages_collection_link // empty')

if [ -n "$messages_url" ]; then
    messages_http=$(curl -s -w "%{http_code}" -o "$messages_file" \
        --max-time "$CURL_TIMEOUT" \
        "$messages_url" \
        2>/dev/null || echo "000")

    if [ "$messages_http" = "200" ]; then
        messages_json=$(cat "$messages_file")
    else
        messages_json='{"entries":[]}'
    fi
else
    messages_json='{"entries":[]}'
fi
rm -f "$messages_file"

# --- Extract fields and build output ---
TITLE=$(echo "$bug_json" | jq -r '.title // empty')
DESCRIPTION=$(echo "$bug_json" | jq -r '.description // empty')
OWNER_LINK=$(echo "$bug_json" | jq -r '.owner_link // empty')
REPORTER=$(echo "$OWNER_LINK" | sed 's|.*/~||')
DATE_CREATED=$(echo "$bug_json" | jq -r '.date_created // empty')
DATE_UPDATED=$(echo "$bug_json" | jq -r '.date_last_updated // empty')
TAGS=$(echo "$bug_json" | jq -c '.tags // []')
PRIVATE=$(echo "$bug_json" | jq -r '.private // false')
SECURITY=$(echo "$bug_json" | jq -r '.security_related // false')
WEB_LINK=$(echo "$bug_json" | jq -r '.web_link // empty')

# Extract Nova-specific task info (find the nova task)
NOVA_STATUS=$(echo "$tasks_json" | jq -r '[.entries[] | select(.bug_target_name == "nova")] | first | .status // "Unknown"')
NOVA_IMPORTANCE=$(echo "$tasks_json" | jq -r '[.entries[] | select(.bug_target_name == "nova")] | first | .importance // "Unknown"')
NOVA_ASSIGNEE=$(echo "$tasks_json" | jq -r '[.entries[] | select(.bug_target_name == "nova")] | first | .assignee_link // empty' | sed 's|.*/~||')

# Check if this bug targets Nova
IS_NOVA=$(echo "$tasks_json" | jq '[.entries[] | select(.bug_target_name == "nova")] | length > 0')
ALL_PROJECTS=$(echo "$tasks_json" | jq -c '[.entries[].bug_target_name]')

# Extract recent messages (skip first — it's the description)
RECENT_MESSAGES=$(echo "$messages_json" | jq -c --argjson max "$MAX_MESSAGES" '
    [.entries[1:($max + 1)][] | {
        author: (.owner_link | split("/~") | last),
        date: .date_created,
        content: (.content | if length > 500 then (.[0:500] + "...") else . end)
    }]')
MESSAGE_COUNT=$(echo "$messages_json" | jq '.total_size // (.entries | length)')

# Output structured JSON
jq -n \
    --arg bug_id "$BUG_ID" \
    --arg title "$TITLE" \
    --arg description "$DESCRIPTION" \
    --arg reporter "$REPORTER" \
    --arg date_created "$DATE_CREATED" \
    --arg date_updated "$DATE_UPDATED" \
    --arg status "$NOVA_STATUS" \
    --arg importance "$NOVA_IMPORTANCE" \
    --arg assignee "$NOVA_ASSIGNEE" \
    --argjson tags "$TAGS" \
    --argjson private "$PRIVATE" \
    --argjson security_related "$SECURITY" \
    --arg web_link "$WEB_LINK" \
    --argjson is_nova "$IS_NOVA" \
    --argjson all_projects "$ALL_PROJECTS" \
    --argjson message_count "$MESSAGE_COUNT" \
    --argjson recent_messages "$RECENT_MESSAGES" \
    '{
        bug_id: $bug_id,
        title: $title,
        description: $description,
        reporter: $reporter,
        date_created: $date_created,
        date_updated: $date_updated,
        status: $status,
        importance: $importance,
        assignee: $assignee,
        tags: $tags,
        private: $private,
        security_related: $security_related,
        web_link: $web_link,
        is_nova: $is_nova,
        all_projects: $all_projects,
        message_count: $message_count,
        recent_messages: $recent_messages
    }'

exit 0
