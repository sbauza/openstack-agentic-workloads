---
name: create-mr
description: Push the backport branch to GitLab and create a merge request after explicit user approval. Use after completing a backport to submit the cherry-picked changes for review.
---

# Create Merge Request

Push a prepared backport branch to GitLab and create a merge request. This skill requires a completed `/backport` run and explicit user approval before taking any action.

## Prerequisites

- A completed `/backport` run with a clean cherry-pick (no unresolved conflicts)
- The backport branch exists locally with the augmented commit message(s)

## Input

No direct user input is required. The skill loads context from the most recent backport artifact in `artifacts/gerrit-to-gitlab/`.

If multiple backport artifacts exist for different target branches, ask the user which one to use.

## Process

### 1. Load Backport Context

Read the most recent backport artifact from `artifacts/gerrit-to-gitlab/backport-*.md`.

If no artifact is found, inform the user: "No backport artifact found. Please run `/backport` first to prepare a change for merge request creation."

If the artifact indicates unresolved conflicts, inform the user: "The backport has unresolved conflicts. Please resolve them before creating a merge request."

### 2. Extract MR Details

From the backport artifact, extract:

- **Source branch**: The backport branch name (e.g., `backport/912345-to-stable/2024.2`)
- **Target branch**: The stable branch (e.g., `stable/2024.2`)
- **GitLab project**: The internal project path (e.g., `internal/nova`)

Determine the **number of commits** on the branch:

```bash
git log --oneline <target_branch>..<source_branch> | wc -l
```

Determine the **MR title**:

- **Single-commit MR**: Use the upstream change subject directly (e.g., `Fix scheduler race condition in live migration`)
- **Multi-commit MR**: Use a descriptive title that summarizes the backport session (e.g., `Backport {N} changes to {stable_branch}`). If all commits share a common theme or topic, use that as the title instead.

### 3. Build MR Description

The MR description must include two sections: a list of all backported commit SHA1s on the branch, and the company-specific traceability metadata from each commit.

1. **Collect backported commits** on the source branch relative to the target branch:

   ```bash
   git log --format="%H %s" <target_branch>..<source_branch>
   ```

   This lists all commits (SHA1 + subject) that are being introduced by this MR.

2. **Extract company-specific metadata** from each commit message on the source branch:

   ```bash
   git log --format=%B <target_branch>..<source_branch>
   ```

   For each commit, parse out:
   - The `Upstream-<Release>: <url>` tag
   - The `Resolves: <Jira key>` tag (if present)
   - The `(cherry picked from commit <hash>)` line

3. **Compose the MR description** using this template:

   ```markdown
   ## Backported Commits

   | SHA1 | Subject |
   |------|---------|
   | `{sha1_1}` | {subject_1} |
   | `{sha1_2}` | {subject_2} |

   ## Traceability

   | Upstream Change | Cherry-Picked From | Resolves |
   |----------------|-------------------|----------|
   | Upstream-{Release}: {gerrit_url_1} | {upstream_hash_1} | {jira_key_1 or N/A} |
   | Upstream-{Release}: {gerrit_url_2} | {upstream_hash_2} | {jira_key_2 or N/A} |
   ```

   - The **Backported Commits** table lists every commit SHA1 introduced by the MR, so reviewers can see exactly what landed
   - The **Traceability** table lists the upstream Gerrit change, cherry-pick source, and Jira issue for each commit
   - For single-commit MRs, the table has one row. For multi-commit MRs, one row per commit.
   - Omit the `Resolves` column entirely if no commit has a Jira issue

### 4. Preview MR

Present the exact merge request that will be created:

```text
## Merge Request Preview

**GitLab Project**: {gitlab_project}
**Source Branch**: {source_branch}
**Target Branch**: {target_branch}
**Commits**: {N}

**Title**: {mr_title}

**Description**:
{full composed MR description from step 3}
```

### 5. Get User Approval

**CRITICAL: Never proceed without explicit user approval.**

Ask: "Would you like to create this merge request on GitLab? (yes/no)"

- If the user says **yes**: proceed to step 6
- If the user says **no** or anything else: inform them "No action taken. You can run `/create-mr` again when ready." and stop

### 6. Push Branch

Push the backport branch to the GitLab remote:

```bash
git push origin <source_branch>
```

If the push fails:

- Report the error (likely authentication or permission issue)
- Suggest: "Check your GitLab credentials and permissions for the {gitlab_project} project."
- Save the MR draft as an artifact (see step 8 error handling)
- Do not attempt to create the MR

### 7. Create Merge Request

**Check for `glab` CLI availability**:

```bash
which glab && glab auth status
```

#### 7a. If `glab` CLI is Available

Use the `glab` CLI to create the merge request:

```bash
glab mr create \
  --source-branch <source_branch> \
  --target-branch <target_branch> \
  --title "<mr_title>" \
  --description "<mr_description>"
```

On success, proceed to step 8 (success reporting).

On failure, proceed to step 7b (manual MR template generation).

#### 7b. If `glab` CLI is Unavailable or MR Creation Fails

Generate a manual MR template and provide creation instructions:

Write `artifacts/gerrit-to-gitlab/mr-template-{branch_identifier}.md`:

```markdown
# Merge Request Template: {mr_title}

**GitLab Project**: {gitlab_project}
**Source Branch**: {source_branch}
**Target Branch**: {target_branch}
**Commits**: {N}

## Title

{mr_title}

## Description

{full composed MR description from step 3 — backported commits table + traceability table}

## Manual Creation Instructions

1. Open your GitLab instance in a browser
2. Navigate to the project: https://{gitlab_instance}/{gitlab_project}
3. Click "Merge requests" in the left sidebar
4. Click "New merge request"
5. Select source branch: `{source_branch}`
6. Select target branch: `{target_branch}`
7. Click "Compare branches and continue"
8. Enter the title above in the "Title" field
9. Copy the description above (everything under "## Description") into the "Description" field
10. Review and click "Create merge request"

## Git Push Command (if not already pushed)

\`\`\`bash
git push origin {source_branch}
\`\`\`
```

Inform the user: "\`glab\` CLI is unavailable. An MR template has been saved to \`artifacts/gerrit-to-gitlab/mr-template-{branch_identifier}.md\` with manual creation instructions."

Proceed to step 8 (report result with manual instructions).

### 8. Report Result

#### 8a. On Success (`glab` CLI)

Report the MR URL and status:

```text
Merge request created successfully!

**URL**: {mr_url}
**Title**: {mr_title}
**Source**: {source_branch} -> {target_branch}
**Project**: {gitlab_project}
**Commits**: {N}
```

#### 8b. On Manual Template Generation (`glab` Unavailable)

Report the template location and provide guidance:

```text
`glab` CLI unavailable — MR template generated.

**Template**: artifacts/gerrit-to-gitlab/mr-template-{branch_identifier}.md
**Source**: {source_branch} -> {target_branch}
**Project**: {gitlab_project}
**Commits**: {N}

The template contains:
- Complete MR title and description
- Manual creation instructions for GitLab UI
- Git push command (if needed)

Open the template file to view the full instructions.
```

#### 8c. On Failure (`glab` Error)

Report the error and save the MR draft for manual creation:

Write `artifacts/gerrit-to-gitlab/mr-draft-{branch_identifier}.md`:

```markdown
# Merge Request Draft: {mr_title}

**GitLab Project**: {gitlab_project}
**Source Branch**: {source_branch}
**Target Branch**: {stable_branch}
**Commits**: {N}
**Status**: Failed to create (see error below)

## Title

{mr_title}

## Description

{full composed MR description from step 3 — backported commits table + traceability table}

## Error

{error details}

## Manual Steps

1. Push the branch: `git push origin {source_branch}`
2. Create the MR manually in GitLab with the title and description above
```

Inform the user: "Failed to create the merge request. The MR draft has been saved with manual creation instructions."

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| No backport artifact found | Tell user to run `/backport` first |
| Unresolved conflicts in backport | Tell user to resolve conflicts before creating MR |
| `glab` CLI unavailable | Generate manual MR template with creation instructions |
| Push fails (auth/permissions) | Report error, save draft, suggest checking credentials |
| MR creation fails (`glab` error) | Save draft to artifact with error details |
| User declines approval | Do not proceed; inform user they can re-run when ready |

## Output

- **On success (`glab` CLI)**: No artifact file needed — MR is on GitLab. Report MR URL.
- **On `glab` unavailable**: `artifacts/gerrit-to-gitlab/mr-template-{branch_identifier}.md`
- **On failure**: `artifacts/gerrit-to-gitlab/mr-draft-{branch_identifier}.md`

### Writing Style

Follow the rules in `rules.md`. In particular:

- The MR preview must show exactly what will be created — no surprises
- Error messages must include actionable next steps
- Never attempt to create the MR if the push failed
- Distinguish between "`glab` unavailable" (expected, use manual template) and "MR creation failed" (unexpected error)
