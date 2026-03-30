# Gerrit to GitLab

An ACP workflow for backporting merged upstream OpenStack Gerrit changes to internal GitLab repository stable branches.

## Skills

| Skill | Description |
|-------|-------------|
| `/backport` | Fetch a merged Gerrit change, analyze dependencies, cherry-pick it to an internal GitLab stable branch, and prepare a merge request summary. Supports multi-commit sessions — run multiple times to accumulate cherry-picks on the same branch. |
| `/test` | Run unit tests or pep8 checks against the backport branch in a Docker container using openstack-tox-docker. Reuses images across runs. |
| `/create-mr` | Push the backport branch to GitLab and create a merge request after explicit user approval. Handles both single-commit and multi-commit MRs. |

## Prerequisites

This workflow requires the following MCP server integrations in your ACP session:

- **Gerrit MCP server** — for fetching upstream change metadata and patches from `review.opendev.org`
- **GitLab MCP server** — for listing branches and creating merge requests on the internal GitLab instance

The internal GitLab repository should be a fork or mirror of the upstream OpenStack project, sharing common git history.

## Setup

To test this workflow via ACP's "Custom Workflow" feature:

| Field | Value |
|-------|-------|
| **URL** | `https://github.com/sbauza/openstack-agentic-workloads.git` |
| **Branch** | The branch with your changes |
| **Path** | `workflows/gerrit-to-gitlab` |

## What It Does

### Backport (`/backport`)

1. Fetches change metadata from upstream Gerrit (subject, author, status, commit message)
2. Validates the change is merged
3. Checks for upstream reverts of the change
4. Analyzes dependency chain (parent commits, topic-related changes)
5. Detects existing backport branches — offers to add commits to an existing session or create a new branch
6. Prompts for target GitLab project, stable branch, upstream release name, and optional Jira issue (skipped when adding to an existing branch)
7. Cherry-picks the change using `git cherry-pick -x` (preserves authorship)
8. Handles merge conflicts with clear reporting and resolution guidance
9. Augments the commit message with `Upstream-<Release>:` and optional `Resolves:` tags
10. Presents the MR summary (single-commit or accumulated multi-commit view)

### Test (`/test`)

1. Detects the active backport branch and loads context
2. Prompts for tox environment (py3, pep8, or custom)
3. Prompts for openstack-tox-docker build script (first run only — cached for subsequent runs)
4. Builds the Docker image if not already built
5. Runs tox non-interactively in the container with SELinux and user permission flags
6. Reports pass/fail results with failure details (test names or pep8 violations)
7. Saves test results as an artifact

### Create MR (`/create-mr`)

1. Loads the backport artifact from a completed `/backport` run
2. Previews the exact merge request that will be created
3. Requires explicit user approval before proceeding
4. Pushes the backport branch and creates the GitLab merge request
5. Reports the MR URL or saves a draft artifact on failure

## Artifact Outputs

All artifacts are written to `artifacts/gerrit-to-gitlab/`:

| Artifact | Filename Pattern | Description |
|----------|-----------------|-------------|
| Backport summary | `backport-{change_id}.md` | Change metadata, cherry-pick result, MR draft |
| Conflict report | `conflict-{change_id}.md` | Conflicting files, regions, and resolution guidance |
| Dependency analysis | `deps-{change_id}.md` | Missing prerequisite changes with Gerrit links |
| MR draft (fallback) | `mr-draft-{change_id}.md` | Formatted MR for manual creation when automation fails |
| Test results | `test-{branch_id}-{tox_env}.md` | Tox test results (pass/fail, failures, output) |

## File Structure

```text
workflows/gerrit-to-gitlab/
├── .ambient/
│   └── ambient.json       # Workflow configuration
├── .claude/
│   └── skills/
│       ├── backport/
│       │   └── SKILL.md   # Core backport skill
│       ├── create-mr/
│       │   └── SKILL.md   # MR creation skill
│       └── test/
│           └── SKILL.md   # Test execution skill
├── AGENTS.md              # Backport domain reference
├── CLAUDE.md              # Pointer to AGENTS.md + rules
├── rules.md               # Workflow-specific behavioral rules
└── README.md              # This file
```
