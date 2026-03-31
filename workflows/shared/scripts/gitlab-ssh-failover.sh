#!/usr/bin/env bash
#
# GitLab SSH Failover Script
# Handles HTTPS→SSH failover for GitLab git operations
#
# Usage: gitlab-ssh-failover.sh <gitlab_url_https> <git_operation> [git_args...]
# Exit codes: 0=success (HTTPS or SSH), 1=both failed, 2=invalid args/cancelled

set -euo pipefail

# Validate arguments
if [ $# -lt 2 ]; then
    echo "ERROR: Usage: gitlab-ssh-failover.sh <gitlab_url_https> <git_operation> [git_args...]" >&2
    echo "  git_operation: clone | fetch | pull | push | ls-remote" >&2
    exit 2
fi

HTTPS_URL="$1"
GIT_OPERATION="$2"
shift 2
GIT_ARGS=("$@")

# Validate git operation
if [[ ! "$GIT_OPERATION" =~ ^(clone|fetch|pull|push|ls-remote)$ ]]; then
    echo "ERROR: Invalid git operation '$GIT_OPERATION'" >&2
    echo "Expected: clone | fetch | pull | push | ls-remote" >&2
    exit 2
fi

# Validate HTTPS URL format
if [[ ! "$HTTPS_URL" =~ ^https:// ]]; then
    echo "ERROR: Invalid HTTPS URL format: $HTTPS_URL" >&2
    echo "Expected: https://... format" >&2
    exit 2
fi

# Attempt HTTPS access first
echo "Attempting git $GIT_OPERATION via HTTPS..." >&2

https_error_file=$(mktemp)
if git "$GIT_OPERATION" "$HTTPS_URL" "${GIT_ARGS[@]}" 2>"$https_error_file"; then
    # HTTPS succeeded - no failover needed
    rm -f "$https_error_file"
    exit 0
fi

# HTTPS failed - capture error and attempt SSH failover
HTTPS_ERROR=$(cat "$https_error_file")
rm -f "$https_error_file"

echo "" >&2
echo "HTTPS access failed. Failing over to SSH..." >&2

# Convert HTTPS URL to SSH format
# Pattern: https://gitlab.example.com/internal/nova.git → git@gitlab.example.com:internal/nova.git
if [[ "$HTTPS_URL" =~ ^https://([^/]+)/(.+)$ ]]; then
    HOSTNAME="${BASH_REMATCH[1]}"
    PATH_PART="${BASH_REMATCH[2]}"
    SSH_URL="git@${HOSTNAME}:${PATH_PART}"
else
    echo "ERROR: Could not parse HTTPS URL for SSH conversion: $HTTPS_URL" >&2
    exit 1
fi

# Prompt for SSH private key
while true; do
    read -p "Enter path to SSH private key (or 'cancel' to abort): " SSH_KEY_PATH

    # Check for cancellation
    if [[ "$SSH_KEY_PATH" == "cancel" ]]; then
        echo "Operation cancelled by user." >&2
        exit 2
    fi

    # Expand tilde
    SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

    # Validate key file exists and is readable
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "ERROR: Key file not found: $SSH_KEY_PATH" >&2
        echo "Try again or type 'cancel' to abort." >&2
        continue
    fi

    if [ ! -r "$SSH_KEY_PATH" ]; then
        echo "ERROR: Key file not readable: $SSH_KEY_PATH" >&2
        echo "Check file permissions. Try again or type 'cancel' to abort." >&2
        continue
    fi

    # Warn if key permissions are too permissive (optional - informational only)
    KEY_PERMS=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || stat -f "%OLp" "$SSH_KEY_PATH" 2>/dev/null || echo "unknown")
    if [[ "$KEY_PERMS" != "600" ]] && [[ "$KEY_PERMS" != "400" ]]; then
        echo "WARNING: SSH key permissions ($KEY_PERMS) may be too permissive. Recommended: 600 or 400" >&2
    fi

    echo "Validating key file... OK" >&2
    break
done

# Attempt SSH access with provided key
echo "Attempting git $GIT_OPERATION via SSH ($SSH_URL)..." >&2

ssh_error_file=$(mktemp)
if GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" \
   git "$GIT_OPERATION" "$SSH_URL" "${GIT_ARGS[@]}" 2>"$ssh_error_file"; then
    # SSH succeeded
    rm -f "$ssh_error_file"
    echo "✓ Failover successful." >&2
    exit 0
fi

# Both HTTPS and SSH failed - capture SSH error and report
SSH_ERROR=$(cat "$ssh_error_file")
rm -f "$ssh_error_file"

echo "" >&2
echo "ERROR: Both HTTPS and SSH access failed." >&2
echo "" >&2
echo "HTTPS error:" >&2
echo "  $HTTPS_ERROR" | head -3 >&2
echo "" >&2
echo "SSH error:" >&2
echo "  $SSH_ERROR" | head -3 >&2
echo "" >&2
echo "Remediation:" >&2
echo "  HTTPS: Verify network access and git credentials (git credential helper)" >&2
echo "  SSH: Verify SSH key has access to repository, check public key is registered in GitLab" >&2
echo "  Network: Check VPN connection, firewall rules, or proxy settings" >&2
echo "" >&2

exit 1
