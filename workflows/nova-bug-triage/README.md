# Nova Bug Triage

Triage OpenStack Nova Launchpad bug reports by validating whether they describe genuine defects or fall into invalid categories.

This workflow helps Nova bug triagers quickly classify bug reports against the Nova source code, identifying configuration issues, unsupported features, incomplete reports, issues already fixed in master, and feature requests filed as bugs.

## Skills

| Skill | Description |
|-------|-------------|
| `/nova-triage` | Fetch a Launchpad bug, validate against Nova source, classify validity |
| `/nova-reproduce` | Deeper source analysis to assess reproducibility in master |
| `/nova-report` | Generate a persistent triage report artifact |
| `/nova-update-launchpad` | Post triage results to Launchpad with user approval |

## Prerequisites

- **Nova source checkout** (auto-managed): The workflow automatically clones the Nova repository to `/workspace/repos/nova/` from `https://opendev.org/openstack/nova.git` if not already present. No manual setup needed.
- **Launchpad OAuth credentials** (optional, for write operations): Set `LP_ACCESS_TOKEN` and `LP_ACCESS_SECRET` environment variables to enable posting comments and updating bug status via `/nova-update-launchpad`. Without these, the workflow operates in read-only mode and generates fallback artifacts for manual posting. See **Generating Launchpad OAuth Tokens** below.

## Usage

### Ambient Code Platform (ACP)

Load this workflow in ACP as a Custom Workflow:

1. Go to **Custom Workflows** in your ACP session
2. Add the repository: `https://github.com/sbauza/openstack-agentic-workflows.git`
3. Set the branch (e.g., `main`)
4. Set the path: `workflows/nova-bug-triage`

### Claude Code

Run `claude` from the workflow directory to auto-load skills, rules, and personas:

```bash
cd openstack-agentic-workflows/workflows/nova-bug-triage
claude
```

Skills are available as slash commands: `/nova-triage`, `/nova-reproduce`, `/nova-report`, `/nova-update-launchpad`. Agent personas (`bug-triager`, `openstack-operator`, `nova-coresec`) are loaded automatically via `CLAUDE.md`.

### Cursor

Open the repository root in Cursor. Skills are discovered via symlinks in `.agents/skills/`:

| Cursor Skill | Maps To |
|--------------|---------|
| `nova-triage` | `/nova-triage` |
| `nova-reproduce` | `/nova-reproduce` |
| `nova-report` | `/nova-report` |
| `nova-update-launchpad` | `/nova-update-launchpad` |

Type `/` in the agent chat to invoke a skill. Agent personas are auto-detected from `agents/`.

## Generating Launchpad OAuth Tokens

To enable `/nova-update-launchpad` (posting comments and changing bug status), you need OAuth 1.0a tokens. Run the included helper script:

```bash
python3 workflows/shared/scripts/launchpad-auth.py
```

The script will:

1. Request a temporary token from Launchpad
2. Print a URL for you to open in your browser
3. On the Launchpad page, log in and select "Change Anything" access level, then click "Authorize"
4. Press Enter in the terminal to complete the exchange
5. Print the `export` commands to set in your environment

Then configure the env vars in your ACP session or shell profile:

```bash
export LP_CONSUMER_KEY='acp-nova-triage'
export LP_ACCESS_TOKEN='<your-token>'
export LP_ACCESS_SECRET='<your-secret>'
```

These tokens are permanent and do not expire unless you revoke them at `https://launchpad.net/~/+oauth-tokens`.

## What It Does

### /nova-triage

1. Parses bug ID from user input (bare ID or Launchpad URL)
2. Ensures Nova source checkout is available (auto-clones if missing)
3. Fetches bug details from Launchpad via REST API
4. Displays structured bug summary (title, reporter, status, importance, tags, description, comments)
5. Analyzes validity against Nova source code
6. Searches for potential duplicate bugs
7. Classifies into one of six validity categories with supporting rationale
8. Presents classification for user review

### /nova-reproduce

1. Loads previously triaged bug context
2. Identifies relevant code paths in the Nova checkout
3. Searches for existing test coverage
4. Checks git log for recent changes and fixes
5. Produces reproducibility assessment (Yes / No / Inconclusive / Requires Environment)

### /nova-report

1. Loads all analysis from the current session (triage, reproduction, duplicates)
2. Generates a structured markdown report
3. Saves to `artifacts/nova-bug-triage/triage-{bug_id}.md`

### /nova-update-launchpad

1. Maps validity category to Launchpad status/importance changes
2. Drafts a constructive comment for the bug reporter
3. Previews the complete update for user approval
4. Posts to Launchpad via OAuth REST API (or generates manual fallback artifact)
5. Falls back to a manual artifact if posting fails

## Validity Categories

| Category | Launchpad Status | Importance | When to Use |
|----------|-----------------|------------|-------------|
| Configuration Issue | Invalid | (unchanged) | Bug is caused by misconfiguration |
| Unsupported Feature | Won't Fix | (unchanged) | Reported behavior involves an unsupported deployment or feature |
| Incomplete Report | Incomplete | (unchanged) | Not enough information to reproduce or understand the issue |
| Not Reproducible in Master | Invalid | (unchanged) | Issue has been fixed in the current master branch |
| RFE | Invalid | Wishlist | Report requests functionality that was never implemented |
| Likely Valid Bug | Triaged/Confirmed | Proposed | Appears to be a genuine Nova defect |

## Fallback Mechanisms

- **Launchpad credentials not configured**: Read operations (fetching bugs, searching duplicates) work without authentication. For write operations, the workflow generates a fallback artifact at `artifacts/nova-bug-triage/update-{bug_id}.md` with the comment and status changes ready for manual posting via the Launchpad web UI.
- **Nova repo not present**: Automatically cloned from upstream on first use. If cloning fails (e.g., network issues), triage is blocked until the repo is available.

## Artifact Outputs

| Artifact | Filename Pattern | Description |
|----------|-----------------|-------------|
| Triage Report | `triage-{bug_id}.md` | Full triage analysis with classification, evidence, and recommendations |
| Update Draft | `update-{bug_id}.md` | Fallback artifact for manual Launchpad posting |

All artifacts are written to `artifacts/nova-bug-triage/`.

## File Structure

```text
workflows/nova-bug-triage/
├── .ambient/
│   └── ambient.json
├── .claude/
│   └── skills/
│       ├── nova-triage/
│       │   └── SKILL.md
│       ├── nova-reproduce/
│       │   └── SKILL.md
│       ├── nova-report/
│       │   └── SKILL.md
│       └── nova-update-launchpad/
│           └── SKILL.md
├── AGENTS.md
├── CLAUDE.md
├── rules.md
└── README.md
```
