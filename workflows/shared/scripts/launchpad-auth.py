#!/usr/bin/env python3
"""
Launchpad OAuth Token Generator

Walks through the Launchpad OAuth 1.0a flow to generate access tokens.
These tokens can then be set as environment variables for use with
launchpad-update-bug.py.

Usage:
    python3 launchpad-auth.py
    python3 launchpad-auth.py --consumer-key my-app-name

The script will:
1. Request a temporary token from Launchpad
2. Print a URL for you to visit and authorize in your browser
3. Wait for you to confirm authorization
4. Exchange the temporary token for permanent access credentials
5. Print the environment variables to set
"""

import argparse
import sys
import urllib.parse
import urllib.request


LAUNCHPAD_ROOT = "https://launchpad.net"
REQUEST_TOKEN_URL = f"{LAUNCHPAD_ROOT}/+request-token"
ACCESS_TOKEN_URL = f"{LAUNCHPAD_ROOT}/+access-token"
AUTHORIZE_TOKEN_URL = f"{LAUNCHPAD_ROOT}/+authorize-token"


def request_token(consumer_key):
    """Request a temporary OAuth token from Launchpad."""
    data = urllib.parse.urlencode({
        "oauth_consumer_key": consumer_key,
        "oauth_signature_method": "PLAINTEXT",
        "oauth_signature": "&",
    }).encode("utf-8")

    req = urllib.request.Request(REQUEST_TOKEN_URL, data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode("utf-8")
            params = dict(urllib.parse.parse_qsl(body))
            return params["oauth_token"], params["oauth_token_secret"]
    except urllib.error.HTTPError as e:
        print(f"ERROR: Failed to request token (HTTP {e.code}): {e.read().decode()}", file=sys.stderr)
        sys.exit(1)
    except (KeyError, urllib.error.URLError) as e:
        print(f"ERROR: Failed to request token: {e}", file=sys.stderr)
        sys.exit(1)


def exchange_token(consumer_key, request_token_val, request_token_secret):
    """Exchange the authorized request token for an access token."""
    data = urllib.parse.urlencode({
        "oauth_consumer_key": consumer_key,
        "oauth_token": request_token_val,
        "oauth_signature_method": "PLAINTEXT",
        "oauth_signature": f"&{request_token_secret}",
    }).encode("utf-8")

    req = urllib.request.Request(ACCESS_TOKEN_URL, data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode("utf-8")
            params = dict(urllib.parse.parse_qsl(body))
            return params["oauth_token"], params["oauth_token_secret"]
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        if e.code == 401:
            print("ERROR: Token not yet authorized. Did you complete the authorization in your browser?", file=sys.stderr)
        else:
            print(f"ERROR: Failed to exchange token (HTTP {e.code}): {body}", file=sys.stderr)
        sys.exit(1)
    except (KeyError, urllib.error.URLError) as e:
        print(f"ERROR: Failed to exchange token: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Generate Launchpad OAuth tokens")
    parser.add_argument(
        "--consumer-key",
        default="acp-nova-triage",
        help="OAuth consumer key / application name (default: acp-nova-triage)",
    )
    args = parser.parse_args()

    consumer_key = args.consumer_key

    print(f"Requesting temporary token from Launchpad (consumer: {consumer_key})...")
    req_token, req_secret = request_token(consumer_key)

    authorize_url = f"{AUTHORIZE_TOKEN_URL}?oauth_token={urllib.parse.quote(req_token)}&allow_permission=DESKTOP_INTEGRATION"

    print()
    print("=" * 60)
    print("Open this URL in your browser to authorize the application:")
    print()
    print(f"  {authorize_url}")
    print()
    print("On that page:")
    print("  1. Log in to Launchpad if needed")
    print('  2. Select the access level (recommended: "Change Anything")')
    print('  3. Click "Authorize"')
    print("=" * 60)
    print()

    input("Press Enter after you have authorized the application in your browser...")

    print()
    print("Exchanging for access token...")
    access_token, access_secret = exchange_token(consumer_key, req_token, req_secret)

    print()
    print("=" * 60)
    print("Authorization successful! Set these environment variables:")
    print()
    print(f"  export LP_CONSUMER_KEY='{consumer_key}'")
    print(f"  export LP_ACCESS_TOKEN='{access_token}'")
    print(f"  export LP_ACCESS_SECRET='{access_secret}'")
    print()
    print("To make them permanent, add the lines above to your shell")
    print("profile (~/.bashrc, ~/.zshrc) or your ACP session config.")
    print("=" * 60)


if __name__ == "__main__":
    main()
