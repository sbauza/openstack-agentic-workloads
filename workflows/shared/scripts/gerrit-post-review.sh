#!/usr/bin/env bash
#
# Gerrit REST API Review Posting Script
# Posts review comments and labels to Gerrit via REST API without MCP
#
# Usage: gerrit-post-review.sh <change_id> <review_json_file>
# Exit codes: 0=posted, 1=failed, 2=invalid args, 3=cancelled

set -euo pipefail

# Constants
MAX_RETRIES=3
GERRIT_BASE_URL="https://review.opendev.org"

# Validate arguments
if [ $# -ne 2 ]; then
    echo "ERROR: Usage: gerrit-post-review.sh <change_id> <review_json_file>" >&2
    exit 2
fi

CHANGE_ID="$1"
REVIEW_JSON_FILE="$2"

# Extract numeric change ID from URL if needed
if [[ "$CHANGE_ID" =~ \+/([0-9]+) ]]; then
    CHANGE_ID="${BASH_REMATCH[1]}"
elif [[ ! "$CHANGE_ID" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid change ID format: $CHANGE_ID" >&2
    echo "Expected: numeric ID or Gerrit URL" >&2
    exit 2
fi

# Validate JSON file exists
if [ ! -f "$REVIEW_JSON_FILE" ]; then
    echo "ERROR: Review JSON file not found: $REVIEW_JSON_FILE" >&2
    exit 2
fi

# Validate JSON file is valid JSON
if ! jq empty "$REVIEW_JSON_FILE" 2>/dev/null; then
    echo "ERROR: Failed to parse JSON file: $REVIEW_JSON_FILE" >&2
    jq empty "$REVIEW_JSON_FILE" 2>&1 | head -3 >&2
    exit 2
fi

# Validate required fields in JSON
if ! jq -e '.message' "$REVIEW_JSON_FILE" >/dev/null 2>&1; then
    echo "ERROR: Missing required field 'message' in JSON file" >&2
    exit 2
fi

# Function to clean up credentials
cleanup_credentials() {
    unset GERRIT_USER GERRIT_PASS AUTH_HEADER
}

# Ensure cleanup on exit
trap cleanup_credentials EXIT

# Function to prompt for credentials
prompt_credentials() {
    read -p "Gerrit username: " GERRIT_USER
    read -sp "Gerrit password: " GERRIT_PASS
    echo  # New line after hidden input

    # Check for cancellation
    if [ -z "$GERRIT_USER" ] || [ -z "$GERRIT_PASS" ]; then
        echo "ERROR: Username and password are required" >&2
        return 1
    fi

    # Encode credentials for HTTP basic auth
    AUTH_HEADER="Authorization: Basic $(echo -n "${GERRIT_USER}:${GERRIT_PASS}" | base64)"
}

# Function to post review to Gerrit
post_review() {
    local response_file=$(mktemp)
    local http_code

    # Make POST request to Gerrit REST API
    http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d @"$REVIEW_JSON_FILE" \
        "${GERRIT_BASE_URL}/changes/${CHANGE_ID}/revisions/current/review" \
        2>/dev/null || echo "000")

    local exit_code=$?

    # Handle response
    case "$http_code" in
        200)
            # Success
            echo "✓ Review posted successfully"
            echo "URL: ${GERRIT_BASE_URL}/c/${CHANGE_ID}"
            rm -f "$response_file"
            return 0
            ;;
        401)
            # Authentication failed
            echo "ERROR: Authentication failed (HTTP 401)" >&2
            echo "Invalid username or password." >&2
            rm -f "$response_file"
            return 1
            ;;
        403)
            # Insufficient permissions
            echo "ERROR: Insufficient permissions (HTTP 403)" >&2
            echo "User '${GERRIT_USER}' does not have permission to post reviews on this change." >&2
            echo "" >&2
            echo "Possible causes:" >&2
            echo "- User is not in a reviewer group" >&2
            echo "- Change is in a restricted project" >&2
            echo "- User account is not verified" >&2
            rm -f "$response_file"
            return 2
            ;;
        404)
            # Change not found
            echo "ERROR: Change not found (HTTP 404)" >&2
            echo "Change ID ${CHANGE_ID} does not exist on ${GERRIT_BASE_URL}" >&2
            rm -f "$response_file"
            return 2
            ;;
        000)
            # Network error
            echo "ERROR: Failed to connect to ${GERRIT_BASE_URL}" >&2
            echo "Network error or connection timeout" >&2
            rm -f "$response_file"
            return 2
            ;;
        *)
            # Other HTTP error
            echo "ERROR: HTTP $http_code" >&2
            if [ -f "$response_file" ] && [ -s "$response_file" ]; then
                cat "$response_file" | head -5 >&2
            fi
            rm -f "$response_file"
            return 2
            ;;
    esac
}

# Main execution with retry logic
echo "Posting review to change ${CHANGE_ID}..."

retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    # Prompt for credentials
    if ! prompt_credentials; then
        echo "Operation cancelled by user." >&2
        exit 3
    fi

    # Attempt to post review
    if post_review; then
        # Success - credentials will be cleaned up by trap
        exit 0
    fi

    post_exit_code=$?

    # If error is not authentication (exit code 1), don't retry
    if [ $post_exit_code -ne 1 ]; then
        exit 1
    fi

    # Authentication failed, ask to retry
    retry_count=$((retry_count + 1))

    if [ $retry_count -lt $MAX_RETRIES ]; then
        echo "" >&2
        read -p "Retry with different credentials? (y/n): " retry_choice
        if [[ ! "$retry_choice" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled by user." >&2
            exit 3
        fi
        # Clear old credentials before retry
        cleanup_credentials
    else
        echo "" >&2
        echo "ERROR: Maximum authentication attempts ($MAX_RETRIES) exceeded" >&2
        exit 1
    fi
done

# Should not reach here, but just in case
exit 1
