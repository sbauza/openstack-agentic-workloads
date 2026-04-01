# Gerrit to GitLab

An ACP workflow for backporting merged upstream OpenStack Gerrit changes to internal GitLab repository stable branches.

## Skills

| Skill | Description |
|-------|-------------|
| `/backport` | Fetch a merged Gerrit change, analyze dependencies, cherry-pick it to an internal GitLab stable branch, and prepare a merge request summary. Supports multi-commit sessions — run multiple times to accumulate cherry-picks on the same branch. |
| `/test` | Run unit tests or pep8 checks against the backport branch in a Docker container using openstack-tox-docker. Reuses images across runs. |
| `/create-mr` | Push the backport branch to GitLab and create a merge request after explicit user approval. Handles both single-commit and multi-commit MRs. |

## Prerequisites

### Required

- Internal GitLab repository that is a fork or mirror of the upstream OpenStack project (sharing common git history)
- Git credentials configured for GitLab repository access

### Optional MCP Integrations

The workflow supports MCP server integrations for enhanced automation, but can operate without them:

**Gerrit MCP** (optional):
- **With MCP**: Automated metadata fetching and change details
- **Without MCP**: Uses Gerrit REST API for metadata, standard git for patches
  - Automatic metadata fetch via `GET /changes/{id}/detail`
  - User can confirm/edit fetched metadata
  - Falls back to manual entry on API failure

**GitLab MCP** (optional):
- **With MCP**: Automated branch listing and MR creation
- **Without MCP**: Uses git operations with HTTPS→SSH failover
  - Repository access via git (clone, fetch, ls-remote)
  - Prompts for SSH private key on HTTPS failure
  - MR draft artifact generated for manual creation in GitLab UI

The workflow automatically detects MCP availability at startup and uses the appropriate method.

## Setup

To test this workflow via ACP's "Custom Workflow" feature:

| Field | Value |
|-------|-------|
| **URL** | `https://github.com/sbauza/openstack-agentic-workflows.git` |
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

## Fallback Mechanisms

### Gerrit REST API Fallback

When Gerrit MCP is unavailable, the `/backport` skill uses REST API for metadata fetching:

1. **Automatic Metadata Fetch**:
   - Calls `GET https://review.opendev.org/changes/{id}/detail`
   - Extracts subject, author, status, commit hash, project, branch
   - Handles anti-XSSI prefix (`)]}'\n`)
   - No authentication required (public instance)

2. **User Confirmation Flow**:
   - Displays fetched metadata to user
   - User can: confirm, edit specific fields, or cancel
   - Edited values override fetched values

3. **Fallback to Manual Entry**:
   - If REST API fails (network error, change not found)
   - Prompts user to manually enter metadata fields
   - Ensures workflow can proceed even without API access

4. **Patch Fetching via Git**:
   - Uses standard git fetch with Gerrit's `refs/changes` refspec
   - Example: `git fetch https://review.opendev.org/openstack/nova refs/changes/45/912345/3`
   - No authentication required for merged public changes

### GitLab Git Fallback

When GitLab MCP is unavailable, git operations use HTTPS→SSH failover:

1. **HTTPS First**:
   - Attempts git operation (clone, fetch, ls-remote) via HTTPS
   - Uses configured git credential helper
   - If succeeds, workflow continues normally

2. **SSH Failover on HTTPS Failure**:
   - Notifies user of HTTPS failure
   - Prompts for SSH private key path
   - Validates key file exists and is readable
   - Warns if key permissions are too permissive (not 600/400)
   - Converts HTTPS URL to SSH format
   - Retries operation with `GIT_SSH_COMMAND="ssh -i <key> -o StrictHostKeyChecking=no"`

3. **MR Draft Artifact**:
   - If GitLab MCP unavailable for MR creation
   - Generates Markdown artifact with:
     - Git push command (exact branch and remote)
     - MR title and description (ready to copy-paste)
     - Source and target branch information
     - Manual steps for creating MR in GitLab UI
   - Saved to `artifacts/gerrit-to-gitlab/mr-template-{feature}.md`

4. **Error Reporting**:
   - Both HTTPS and SSH failed: Shows both error messages
   - Provides remediation steps for each failure type
   - Suggests checking credentials, network, SSH key registration

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
