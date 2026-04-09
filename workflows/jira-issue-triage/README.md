# JIRA Issue Triage

Triage OpenStack Nova JIRA issue reports by validating whether they describe genuine defects or fall into invalid categories.

This workflow helps Nova bug triagers quickly classify JIRA issues against the Nova source code, identifying configuration issues, unsupported features, incomplete reports, issues already fixed in master, and feature requests filed as bugs.

## Skills

| Skill | Description |
|-------|-------------|
| `/triage` | Fetch a JIRA issue, validate against Nova source, classify validity |
| `/reproduce` | Deeper source analysis to assess reproducibility in master |
| `/report` | Generate a persistent triage report artifact |
| `/update-jira` | Generate manual JIRA update instructions with proposed changes |

## Prerequisites

- **Atlassian MCP integration** (required for JIRA access): In ACP, configure via **Workspace Settings**. For Claude Code or Cursor, see [Configuring MCP Servers](../../README.md#atlassian-jira) in the main README. The workflow checks MCP availability at startup and reports the status.
- **Nova source checkout** (auto-managed): The workflow automatically clones the Nova repository to `/workspace/repos/nova/` from `https://opendev.org/openstack/nova.git` if not already present. No manual setup needed.

## Usage

### Ambient Code Platform (ACP)

Load this workflow in ACP as a Custom Workflow:

1. Go to **Custom Workflows** in your ACP session
2. Add the repository: `https://github.com/sbauza/openstack-agentic-workflows.git`
3. Set the branch (e.g., `main`)
4. Set the path: `workflows/jira-issue-triage`

### Claude Code

Run `claude` from the workflow directory to auto-load skills, rules, and personas:

```bash
cd openstack-agentic-workflows/workflows/jira-issue-triage
claude
```

Skills are available as slash commands: `/triage`, `/reproduce`, `/report`, `/update-jira`. Agent personas (`bug-triager`, `openstack-operator`, `nova-coresec`) are loaded automatically via `CLAUDE.md`.

### Cursor

Open the repository root in Cursor. Skills are discovered via symlinks in `.agents/skills/` with the `jira-` prefix:

| Cursor Skill | Maps To |
|--------------|---------|
| `jira-triage` | `/triage` |
| `jira-reproduce` | `/reproduce` |
| `jira-report` | `/report` |
| `jira-update-jira` | `/update-jira` |

Type `/` in the agent chat to invoke a skill. Agent personas are auto-detected from `agents/`.

## What It Does

### /triage

1. Parses issue key from user input (bare key like `OSPRH-1234` or full JIRA URL)
2. Ensures Nova source checkout is available (auto-clones if missing)
3. Fetches issue details from JIRA via the Atlassian MCP integration
4. Displays structured issue summary (summary, reporter, status, priority, resolution, labels, components, description, comments)
5. Analyzes validity against Nova source code
6. Searches for potential duplicate issues
7. Classifies into one of six validity categories with supporting rationale
8. Presents classification for user review

### /reproduce

1. Loads previously triaged issue context
2. Identifies relevant code paths in the Nova checkout
3. Searches for existing test coverage
4. Checks git log for recent changes and fixes
5. Produces reproducibility assessment (Yes / No / Inconclusive / Requires Environment)

### /report

1. Loads all analysis from the current session (triage, reproduction, duplicates)
2. Generates a structured markdown report
3. Saves to `artifacts/jira-issue-triage/triage-{issue_key}.md`

### /update-jira

1. Maps validity category to JIRA status/resolution/priority changes
2. Discovers available status transitions via MCP
3. Drafts a constructive comment for the issue reporter
4. Previews the complete update for user approval
5. Generates a fallback artifact with manual JIRA web UI instructions

**Note**: The Atlassian MCP integration is read-only. The `/update-jira` skill always generates a fallback artifact at `artifacts/jira-issue-triage/update-{issue_key}.md` with step-by-step instructions for manually applying the changes via the JIRA web UI.

## Target Project

The default target JIRA project is **OSPRH**. At startup, the workflow asks you to confirm or change the target project. Issues from other projects trigger a warning but can still be triaged.

## Validity Categories

| Category | Proposed Status | Proposed Resolution | Proposed Priority | When to Use |
|----------|----------------|---------------------|-------------------|-------------|
| Configuration Issue | Closed | Won't Do | (unchanged) | Issue is caused by misconfiguration |
| Unsupported Feature | Closed | Won't Do | (unchanged) | Reported behavior involves an unsupported deployment or feature |
| Incomplete Report | Waiting for Reporter | (unchanged) | (unchanged) | Not enough information to reproduce or understand the issue |
| Not Reproducible in Master | Closed | Cannot Reproduce | (unchanged) | Issue has been fixed in the current master branch |
| RFE | Closed | Won't Do | Lowest | Report requests functionality that was never implemented |
| Likely Valid Bug | Open (Triaged) | (unchanged) | Proposed level | Appears to be a genuine Nova defect |

## Artifact Outputs

| Artifact | Filename Pattern | Description |
|----------|-----------------|-------------|
| Triage Report | `triage-{issue_key}.md` | Full triage analysis with classification, evidence, and recommendations |
| Update Draft | `update-{issue_key}.md` | Fallback artifact with manual JIRA update instructions |

All artifacts are written to `artifacts/jira-issue-triage/`.

## File Structure

```text
workflows/jira-issue-triage/
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
│       └── update-jira/
│           └── SKILL.md
├── AGENTS.md
├── CLAUDE.md
├── rules.md
└── README.md
```
