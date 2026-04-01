---
name: triage
description: Fetch a JIRA issue, validate against Nova source code, and classify its validity. Use when triaging a JIRA issue report to determine if it is a genuine defect, configuration issue, or feature request.
---

# Triage a JIRA Issue

Fetch issue details from JIRA, display a structured summary, analyze the report against the Nova source checkout, and classify whether the issue is valid or falls into an invalid category.

**Agent Collaboration**: Invoke shared agent personas for specialized triage analysis:

- **@bug-triager.md** — Invoke for every triage to apply systematic validity classification
- **@openstack-operator.md** — Invoke when the issue report suggests a configuration or deployment issue (misconfiguration signals, operator-provided logs, upgrade-related symptoms)
- **@nova-coresec.md** — Invoke when the issue has a security level set or describes potential security vulnerabilities

## Input

A JIRA issue key (PROJECT-NUMBER) or full URL.

Examples:
- `/triage OSPRH-1234`
- `/triage https://issues.redhat.com/browse/OSPRH-1234`

## Process

### Step 1. Parse Input

Extract the JIRA issue key from the user's input:
- If a bare issue key (e.g., `OSPRH-1234`), use it directly
- If a JIRA URL (e.g., `https://{instance}/browse/OSPRH-1234`), extract the issue key from the path
- If the format is unrecognized, report an error with the expected formats: `PROJECT-NUMBER` or full JIRA URL

### Step 2. Ensure Nova Source Checkout

Check that the Nova source checkout exists at `/workspace/repos/nova/`.

If missing, **automatically clone it**:

```bash
git clone https://opendev.org/openstack/nova.git /workspace/repos/nova
```

Inform the user that cloning is in progress — this may take a few minutes.

### Step 3. Fetch Issue from JIRA

Use the `jira_get_issue` MCP tool with the issue key and parse the response.

Handle errors:
- **Issue not found**: report "Issue {key} not found in JIRA. Verify the issue key is correct (format: PROJECT-NUMBER)."
- **Permission denied**: report "You do not have permission to view {key}. Check your JIRA access permissions."
- **MCP unavailable**: report "JIRA MCP integration is not configured. Go to Workspace Settings in Ambient to set up the Atlassian integration."
- **Security level set**: warn "This issue has restricted visibility (security level: {level}). Triage details should not be shared publicly." Ask user whether to proceed.
- **Different project**: If the issue's project key differs from the configured target project (default: OSPRH), warn "This issue is from project {project}, not the configured target {target}." Ask user whether to proceed.

### Step 4. Display Structured Summary

Present the issue details in a readable format:

**Issue {key}: {summary}**
- **URL**: {JIRA web URL}
- **Reporter**: {reporter}
- **Assignee**: {assignee or "Unassigned"}
- **Created**: {created date}
- **Last Updated**: {updated date}
- **Status**: {status}
- **Priority**: {priority}
- **Resolution**: {resolution or "Unresolved"}
- **Labels**: {labels}
- **Components**: {components}
- **Fix Versions**: {fix versions or "None"}

**Description**:
> {description — truncate to first 2000 characters if very long, note if truncated}

**Recent Comments** ({comment count} total):
> Show the last 5 comments summarized (author, date, first ~200 characters of content)

### Step 5. Analyze Validity Against Nova Source

For each validity category, check the relevant indicators using the Nova source checkout at `/workspace/repos/nova/`:

**Configuration Issue**:
- Search `nova/conf/` for config options mentioned in the issue report (option names, section names, error messages referencing config)
- Check if the described behavior matches a known misconfiguration pattern
- Look for `oslo.config` option registrations (`cfg.StrOpt`, `cfg.IntOpt`, etc.) related to the issue
- Check `nova/conf/` files for deprecated options that may have changed behavior

**Unsupported Feature**:
- Check if the described deployment, driver, or feature is in Nova's supported set
- Search for capability flags in virt drivers (`nova/virt/`)
- Check API extension registrations and microversion boundaries
- Look for feature gates or config options that enable/disable the feature

**Incomplete Report**:
- Check if the issue includes: Nova version, steps to reproduce, logs or tracebacks, configuration details, deployment topology
- For each missing element, prepare a specific question for the reporter
- Common missing info: "What Nova version?", "What hypervisor/virt driver?", "Can you provide nova-compute logs?", "What's in your nova.conf for [section]?"

**Not Reproducible in Master**:
- Search `git log` in the Nova checkout for commits mentioning the issue keywords, related code changes, or affecting the code path
- Check if the referenced code paths have been significantly changed or refactored
- Look for `Closes-Bug` or `Related-Bug` references in recent commits
- Compare the reported behavior against the current master code

**RFE (Request for Enhancement)**:
- Check if the functionality the reporter expects actually exists in the codebase
- If the reporter assumes a feature exists but the code path is not implemented, this is an RFE
- Example: expecting flavor extra specs for image properties that have no corresponding handler in Nova
- Verify by searching for the expected implementation (API endpoints, object attributes, config options) and confirming they don't exist

**Likely Valid Bug**:
- If none of the above categories apply, the issue appears to be a genuine defect
- Identify the affected Nova subsystem (compute, scheduler, API, conductor, libvirt, cells, etc.)
- Propose a priority level based on impact:
  - Blocker: data loss, regression, blocks upgrades
  - Critical: crashes, deadlocks, security implications
  - Major: incorrect behavior with workaround
  - Minor: edge case, cosmetic, trivial workaround
  - Lowest: very minor, documentation-level

### Step 5b. Check for Duplicates

1. Extract key terms from the issue summary and description (3-5 distinctive keywords)
2. Search JIRA for similar issues using the `jira_search` MCP tool with a JQL query:
   `project = {target_project} AND text ~ "{keywords}" AND status != Closed ORDER BY updated DESC`
3. For each candidate (max 5), assess similarity:
   - Summary similarity
   - Matching labels or components
   - Affected subsystem overlap
4. Present ranked candidates with: issue key, summary, status, JIRA URL, brief explanation of match
5. If no strong candidates found, report: "No duplicate candidates identified."

### Step 6. Present Classification

Present the triage result clearly:

**Validity Assessment**: {category}

**Rationale**: {1-3 sentences citing specific evidence from the issue report AND the Nova source checkout}

**Proposed JIRA Changes**:
- Status: {current} → {proposed} (per validity category mapping)
- Resolution: {current} → {proposed}
- Priority: {current} → {proposed}

**Affected Subsystem**: {subsystem name}

**Confidence**: {High/Medium/Low}

**Duplicate Candidates**: {list or "None identified"}

**Source References**: {file paths and line numbers examined in the Nova checkout}

If Incomplete Report: also show **Questions for Reporter** with the specific information needed.

If RFE: also note **Recommendation**: "Consider filing a nova-spec or RFE for this feature request."

### Step 7. Await User Review

Present the classification for the triager's review. Do not proceed to any external action.

Offer next steps:
- `/reproduce` — deeper source analysis to verify reproducibility
- `/report` — generate a persistent triage report artifact
- `/update-jira` — generate manual JIRA update instructions

## Output

The triage classification is held in session memory for use by `/reproduce`, `/report`, and `/update-jira`.

No artifact is written by this skill — use `/report` to generate a persistent artifact.

### Writing Style

Follow the rules in `rules.md`. In particular:

- Lead with the classification and a one-sentence rationale
- Cite specific file paths and line numbers from the Nova checkout
- Be constructive — suggest fixes for configuration issues, list specific questions for incomplete reports
- Keep the summary scannable — busy triagers should understand the verdict in seconds
