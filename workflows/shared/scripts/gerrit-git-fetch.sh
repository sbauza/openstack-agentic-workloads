#!/usr/bin/env bash
#
# Gerrit Git Fetch Script
# Fetches Gerrit change patch using git without MCP
#
# Usage: gerrit-git-fetch.sh <change_id> [patchset]
# Exit codes: 0=success (patch in FETCH_HEAD), 1=failed, 2=invalid args

set -euo pipefail

# Constants
GERRIT_BASE_URL="https://review.opendev.org"
DEFAULT_PATCHSET="1"

# Validate arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "ERROR: Usage: gerrit-git-fetch.sh <change_id> [patchset]" >&2
    exit 2
fi

CHANGE_ID="$1"
PATCHSET="${2:-$DEFAULT_PATCHSET}"

# Validate change ID is numeric
if [[ ! "$CHANGE_ID" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid change ID format: $CHANGE_ID" >&2
    echo "Expected: numeric ID (e.g., 912345)" >&2
    exit 2
fi

# Validate patchset is numeric
if [[ ! "$PATCHSET" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid patchset format: $PATCHSET" >&2
    echo "Expected: numeric patchset number (e.g., 3)" >&2
    exit 2
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: Not a git repository" >&2
    echo "Run this command from within a git repository directory" >&2
    exit 1
fi

# Detect project from git remote
PROJECT=""
if git remote get-url origin >/dev/null 2>&1; then
    ORIGIN_URL=$(git remote get-url origin)

    # Extract project from various URL formats
    if [[ "$ORIGIN_URL" =~ review\.opendev\.org/([^/]+/[^/]+) ]]; then
        PROJECT="${BASH_REMATCH[1]}"
    elif [[ "$ORIGIN_URL" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
        # Handle GitHub URLs (convert to opendev project)
        REPO="${BASH_REMATCH[1]}"
        REPO="${REPO%.git}"
        PROJECT="openstack/${REPO#*/}"
    elif [[ "$ORIGIN_URL" =~ ([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)(\.git)?$ ]]; then
        # Generic project/repo pattern
        REPO="${BASH_REMATCH[1]}"
        REPO="${REPO%.git}"
        PROJECT="$REPO"
    fi
fi

# If project detection failed, prompt user
if [ -z "$PROJECT" ]; then
    echo "Could not detect project from git remote." >&2
    echo "Example: openstack/nova, starlingx/tools" >&2
    read -p "Enter Gerrit project name: " PROJECT

    if [ -z "$PROJECT" ]; then
        echo "ERROR: Project name is required" >&2
        exit 1
    fi
fi

# Calculate suffix (last 2 digits of change ID)
SUFFIX="${CHANGE_ID: -2}"

# Construct refspec
REFSPEC="refs/changes/${SUFFIX}/${CHANGE_ID}/${PATCHSET}"

# Fetch the change
echo "Fetching change $CHANGE_ID (patchset $PATCHSET) from ${GERRIT_BASE_URL}/${PROJECT}..." >&2

if git fetch "${GERRIT_BASE_URL}/${PROJECT}" "$REFSPEC" 2>&1; then
    echo "✓ Fetch successful. Commit available in FETCH_HEAD." >&2
    echo "To apply: git cherry-pick FETCH_HEAD" >&2
    exit 0
else
    echo "ERROR: Failed to fetch change $CHANGE_ID" >&2
    echo "Refspec: $REFSPEC" >&2
    echo "URL: ${GERRIT_BASE_URL}/${PROJECT}" >&2
    exit 1
fi
