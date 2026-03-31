#!/usr/bin/env bash
#
# MCP Server Detection Script
# Detects availability of Gerrit or GitLab MCP servers with timeout
#
# Usage: detect-mcp.sh <server_type>
# Exit codes: 0=available, 1=unavailable, 2=invalid args

set -euo pipefail

# Validate arguments
if [ $# -ne 1 ]; then
    echo "ERROR: Usage: detect-mcp.sh <server_type>" >&2
    echo "  server_type: gerrit | gitlab" >&2
    exit 2
fi

SERVER_TYPE="$1"

# Validate server type
if [[ ! "$SERVER_TYPE" =~ ^(gerrit|gitlab)$ ]]; then
    echo "ERROR: Invalid server type '$SERVER_TYPE'. Expected: gerrit|gitlab" >&2
    exit 2
fi

# Record start time
START_MS=$(date +%s%3N 2>/dev/null || echo "0")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Function to output JSON result
output_json() {
    local available="$1"
    local error_msg="$2"
    local end_ms=$(date +%s%3N 2>/dev/null || echo "$START_MS")
    local duration_ms=$((end_ms - START_MS))

    # Construct JSON output using jq for proper escaping
    jq -n \
        --arg available "$available" \
        --arg server_type "$SERVER_TYPE" \
        --arg method "test_call_timeout_2s" \
        --arg timestamp "$TIMESTAMP" \
        --arg duration "$duration_ms" \
        --arg error "$error_msg" \
        '{
            available: ($available == "true"),
            server_type: $server_type,
            detection_method: $method,
            timestamp: $timestamp,
            test_duration_ms: ($duration | tonumber),
            error_message: (if $error == "" then null else $error end)
        }'
}

# Test MCP availability with timeout
test_mcp_available() {
    local server="$1"
    local test_command

    # Determine which MCP command to test
    case "$server" in
        gerrit)
            # Try to call a lightweight Gerrit MCP operation
            # Using 'type' command to check if the MCP tool exists
            if ! type mcp__gerrit__list_projects &>/dev/null; then
                return 1
            fi
            test_command="mcp__gerrit__list_projects --help"
            ;;
        gitlab)
            # Try to call a lightweight GitLab MCP operation
            if ! type mcp__gitlab__list_projects &>/dev/null; then
                return 1
            fi
            test_command="mcp__gitlab__list_projects --help"
            ;;
        *)
            return 1
            ;;
    esac

    # Execute test command with 2-second timeout
    # Redirect all output to /dev/null, we only care about exit code
    if timeout 2s bash -c "$test_command" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Main detection logic
if test_mcp_available "$SERVER_TYPE"; then
    # MCP server is available
    output_json "true" ""
    exit 0
else
    # MCP server is unavailable
    ERROR_MSG="MCP server not available or connection timeout after 2000ms"
    output_json "false" "$ERROR_MSG"
    exit 1
fi
