#!/usr/bin/env python3
"""
Launchpad REST API Bug Update Script

Posts comments and updates status/importance on Launchpad bugs using OAuth 1.0a.

Usage:
    launchpad-update-bug.py <bug_id> --comment "text"
    launchpad-update-bug.py <bug_id> --status "Triaged" --importance "High"
    launchpad-update-bug.py <bug_id> --comment "text" --status "Invalid"

Environment variables (required for write operations):
    LP_ACCESS_TOKEN   - OAuth 1.0a access token
    LP_ACCESS_SECRET  - OAuth 1.0a access token secret
    LP_CONSUMER_KEY   - OAuth consumer key (default: "acp-nova-triage")

To generate tokens, visit: https://launchpad.net/+authorize-token

Exit codes: 0=success, 1=auth error, 2=invalid args, 3=API error
"""

import argparse
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid


LAUNCHPAD_API = "https://api.launchpad.net/1.0"
VALID_STATUSES = [
    "New", "Incomplete", "Confirmed", "Triaged", "In Progress",
    "Fix Committed", "Fix Released", "Invalid", "Won't Fix", "Opinion",
]
VALID_IMPORTANCES = [
    "Critical", "High", "Medium", "Low", "Wishlist", "Undecided",
]


def oauth_sign(method, url, params, consumer_key, token, token_secret):
    """Generate OAuth 1.0a Authorization header."""
    oauth_params = {
        "oauth_consumer_key": consumer_key,
        "oauth_token": token,
        "oauth_signature_method": "PLAINTEXT",
        "oauth_timestamp": str(int(time.time())),
        "oauth_nonce": uuid.uuid4().hex,
        "oauth_version": "1.0",
    }
    # PLAINTEXT signature: consumer_secret&token_secret
    # Launchpad uses empty consumer secret
    oauth_params["oauth_signature"] = f"&{urllib.parse.quote(token_secret, safe='')}"

    auth_header = "OAuth " + ", ".join(
        f'{k}="{urllib.parse.quote(str(v), safe="")}"'
        for k, v in sorted(oauth_params.items())
    )
    return auth_header


def get_credentials():
    """Read OAuth credentials from environment variables."""
    token = os.environ.get("LP_ACCESS_TOKEN")
    secret = os.environ.get("LP_ACCESS_SECRET")
    consumer = os.environ.get("LP_CONSUMER_KEY", "acp-nova-triage")

    if not token or not secret:
        print(
            "ERROR: LP_ACCESS_TOKEN and LP_ACCESS_SECRET environment variables are required.\n"
            "Generate tokens at: https://launchpad.net/+authorize-token\n"
            "Then set:\n"
            "  export LP_ACCESS_TOKEN=<your-token>\n"
            "  export LP_ACCESS_SECRET=<your-secret>\n"
            "  export LP_CONSUMER_KEY=<your-consumer-key>  # optional, defaults to acp-nova-triage",
            file=sys.stderr,
        )
        sys.exit(1)

    return consumer, token, secret


def api_request(url, method="GET", data=None, consumer_key=None, token=None, token_secret=None):
    """Make an authenticated request to the Launchpad API."""
    headers = {"Accept": "application/json"}

    if consumer_key and token and token_secret:
        headers["Authorization"] = oauth_sign(
            method, url, {}, consumer_key, token, token_secret
        )

    if data is not None:
        encoded_data = urllib.parse.urlencode(data).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    else:
        encoded_data = None

    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, body
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return e.code, body
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach Launchpad API: {e.reason}", file=sys.stderr)
        sys.exit(3)


def post_comment(bug_id, comment_text, consumer_key, token, token_secret):
    """Post a comment to a Launchpad bug."""
    url = f"{LAUNCHPAD_API}/bugs/{bug_id}/newMessage"
    data = {"ws.op": "newMessage", "content": comment_text}

    status, body = api_request(
        url, method="POST", data=data,
        consumer_key=consumer_key, token=token, token_secret=token_secret,
    )

    if status in (200, 201):
        print(f"Comment posted to bug {bug_id}")
        return True
    elif status == 401:
        print(f"ERROR: Authentication failed (HTTP 401). Check your OAuth credentials.", file=sys.stderr)
        sys.exit(1)
    elif status == 403:
        print(f"ERROR: Insufficient permissions (HTTP 403). You may need Bug Supervisor role.", file=sys.stderr)
        sys.exit(1)
    elif status == 404:
        print(f"ERROR: Bug {bug_id} not found (HTTP 404).", file=sys.stderr)
        sys.exit(3)
    else:
        print(f"ERROR: Failed to post comment (HTTP {status}): {body}", file=sys.stderr)
        sys.exit(3)


def find_nova_task_url(bug_id, consumer_key, token, token_secret):
    """Find the Nova bug task URL for a given bug."""
    url = f"{LAUNCHPAD_API}/bugs/{bug_id}/bug_tasks"
    status, body = api_request(
        url, consumer_key=consumer_key, token=token, token_secret=token_secret,
    )

    if status != 200:
        print(f"ERROR: Failed to fetch bug tasks (HTTP {status})", file=sys.stderr)
        sys.exit(3)

    try:
        tasks = json.loads(body)
        for entry in tasks.get("entries", []):
            if entry.get("bug_target_name") == "nova":
                return entry.get("self_link")
    except json.JSONDecodeError:
        pass

    print(f"ERROR: No Nova task found for bug {bug_id}", file=sys.stderr)
    sys.exit(3)


def update_task(task_url, status_val=None, importance_val=None,
                consumer_key=None, token=None, token_secret=None):
    """Update the status and/or importance of a bug task."""
    data = {}
    if status_val:
        data["status"] = status_val
    if importance_val:
        data["importance"] = importance_val

    if not data:
        return True

    headers_extra = {"Content-Type": "application/json"}
    auth_header = oauth_sign(
        "PATCH", task_url, {}, consumer_key, token, token_secret
    )

    req = urllib.request.Request(
        task_url,
        data=json.dumps(data).encode("utf-8"),
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="PATCH",
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            code = resp.status
    except urllib.error.HTTPError as e:
        code = e.code
        body = e.read().decode("utf-8", errors="replace")
        if code == 401:
            print(f"ERROR: Authentication failed (HTTP 401).", file=sys.stderr)
            sys.exit(1)
        elif code == 403:
            print(
                f"ERROR: Insufficient permissions (HTTP 403). "
                f"Setting status to 'Triaged' or 'Won't Fix' requires Bug Supervisor role.",
                file=sys.stderr,
            )
            sys.exit(1)
        else:
            print(f"ERROR: Failed to update task (HTTP {code}): {body}", file=sys.stderr)
            sys.exit(3)
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach Launchpad API: {e.reason}", file=sys.stderr)
        sys.exit(3)

    changes = []
    if status_val:
        changes.append(f"status={status_val}")
    if importance_val:
        changes.append(f"importance={importance_val}")
    print(f"Updated Nova task: {', '.join(changes)}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Update a Launchpad bug (comment, status, importance)"
    )
    parser.add_argument("bug_id", help="Launchpad bug ID")
    parser.add_argument("--comment", help="Comment text to post")
    parser.add_argument("--status", choices=VALID_STATUSES, help="New bug status")
    parser.add_argument("--importance", choices=VALID_IMPORTANCES, help="New importance level")

    args = parser.parse_args()

    if not args.comment and not args.status and not args.importance:
        parser.error("At least one of --comment, --status, or --importance is required")

    # Validate bug ID
    bug_id = args.bug_id.strip()
    if not bug_id.isdigit():
        print(f"ERROR: Bug ID must be numeric, got: {bug_id}", file=sys.stderr)
        sys.exit(2)

    consumer_key, token, token_secret = get_credentials()

    # Post comment if provided
    if args.comment:
        post_comment(bug_id, args.comment, consumer_key, token, token_secret)

    # Update status/importance if provided
    if args.status or args.importance:
        task_url = find_nova_task_url(bug_id, consumer_key, token, token_secret)
        update_task(
            task_url, args.status, args.importance,
            consumer_key, token, token_secret,
        )

    print(f"\nDone. View bug at: https://bugs.launchpad.net/nova/+bug/{bug_id}")


if __name__ == "__main__":
    main()
