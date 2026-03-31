# Nova Bug Triage

Triage OpenStack Nova Launchpad bug reports by validating whether they describe genuine defects or fall into invalid categories.

This workflow helps Nova bug triagers quickly classify bug reports against the Nova source code, identifying configuration issues, unsupported features, incomplete reports, issues already fixed in master, and feature requests filed as bugs.

## Skills

| Skill | Description |
|-------|-------------|
| `/triage` | Fetch a Launchpad bug, validate against Nova source, classify validity |
| `/reproduce` | Deeper source analysis to assess reproducibility in master |
| `/report` | Generate a persistent triage report artifact |
| `/update-launchpad` | Post triage results to Launchpad with user approval |

## Prerequisites

- **Nova source checkout** (required): The Nova repository must be available at `/workspace/repos/nova/`. Add it to your ACP session or clone it manually.
- **Launchpad MCP** (optional): If available, enables direct API integration. Falls back to REST API automatically.

## Setup

Load this workflow in ACP as a Custom Workflow:

1. Go to **Custom Workflows** in your ACP session
2. Add the repository: `https://github.com/sbauza/openstack-agentic-workloads.git`
3. Set the branch (e.g., `main`)
4. Set the path: `workflows/nova-bug-triage`

## What It Does

### /triage

1. Parses bug ID from user input (bare ID or Launchpad URL)
2. Verifies Nova source checkout is available
3. Fetches bug details from Launchpad (MCP or REST API)
4. Displays structured bug summary (title, reporter, status, importance, tags, description, comments)
5. Analyzes validity against Nova source code
6. Searches for potential duplicate bugs
7. Classifies into one of six validity categories with supporting rationale
8. Presents classification for user review

### /reproduce

1. Loads previously triaged bug context
2. Identifies relevant code paths in the Nova checkout
3. Searches for existing test coverage
4. Checks git log for recent changes and fixes
5. Produces reproducibility assessment (Yes / No / Inconclusive / Requires Environment)

### /report

1. Loads all analysis from the current session (triage, reproduction, duplicates)
2. Generates a structured markdown report
3. Saves to `artifacts/nova-bug-triage/triage-{bug_id}.md`

### /update-launchpad

1. Maps validity category to Launchpad status/importance changes
2. Drafts a constructive comment for the bug reporter
3. Previews the complete update for user approval
4. Posts to Launchpad (MCP or OAuth REST API)
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

- **Launchpad MCP unavailable**: Automatically falls back to REST API via `launchpad-fetch-bug.sh` for reads. OAuth authentication prompted for writes.
- **Posting fails**: Generates a fallback artifact at `artifacts/nova-bug-triage/update-{bug_id}.md` with the comment and status changes ready for manual posting via the Launchpad web UI.

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
│       ├── triage/
│       │   └── SKILL.md
│       ├── reproduce/
│       │   └── SKILL.md
│       ├── report/
│       │   └── SKILL.md
│       └── update-launchpad/
│           └── SKILL.md
├── AGENTS.md
├── CLAUDE.md
├── rules.md
└── README.md
```
