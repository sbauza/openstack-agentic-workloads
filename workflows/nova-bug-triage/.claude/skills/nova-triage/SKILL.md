---
name: nova-triage
description: Fetch a Nova Launchpad bug, validate against source code, and classify its validity. Use when triaging a Launchpad bug report to determine if it is a genuine defect, configuration issue, or feature request.
---

# Triage a Nova Launchpad Bug

Fetch bug details from Launchpad, display a structured summary, analyze the report against the Nova source checkout, and classify whether the bug is valid or falls into an invalid category.

**Agent Collaboration**: Invoke shared agent personas for specialized triage analysis:

- **@bug-triager.md** — Invoke for every triage to apply systematic validity classification and Launchpad lifecycle knowledge
- **@openstack-operator.md** — Invoke when the bug report suggests a configuration or deployment issue (misconfiguration signals, operator-provided logs, upgrade-related symptoms)
- **@nova-coresec.md** — Invoke when the bug has `"security_related": true` or describes potential security vulnerabilities

## Input

A Launchpad bug ID (integer) or full URL.

Examples:
- `/nova-triage 2112373`
- `/nova-triage https://bugs.launchpad.net/nova/+bug/2112373`

## Process

### Step 1. Parse Input

Extract the numeric bug ID from the user's input:
- If a bare integer, use it directly
- If a Launchpad URL (e.g., `https://bugs.launchpad.net/nova/+bug/2112373`), extract the numeric ID
- If the format is unrecognized, report an error with the expected formats

### Step 2. Ensure Nova Source Checkout

Check that the Nova source checkout exists at `/workspace/repos/nova/`.

If missing, **automatically clone it**:

```bash
git clone https://opendev.org/openstack/nova.git /workspace/repos/nova
```

Inform the user that cloning is in progress — this may take a few minutes.

### Step 3. Fetch Bug from Launchpad

Run `workflows/shared/scripts/launchpad-fetch-bug.sh {bug_id}` and parse the JSON output.

Handle errors:
- **Bug not found** (exit code 1): report "Bug {id} not found on Launchpad"
- **Private bug** (`"private": true`): warn "This bug is private. Triage details should not be shared publicly." Ask user whether to proceed.
- **Not a Nova bug** (`"is_nova": false`): warn "This bug is not filed against Nova. It targets: {projects}." Ask user whether to proceed anyway.

### Step 4. Display Structured Summary

Present the bug details in a readable format:

**Bug #{id}: {title}**
- **URL**: {web_link}
- **Reporter**: {reporter}
- **Filed**: {date_created}
- **Last Updated**: {date_updated}
- **Status**: {status}
- **Importance**: {importance}
- **Tags**: {tags}
- **Private**: {yes/no}

**Description**:
> {description — truncate to first 2000 characters if very long, note if truncated}

**Recent Comments** ({message_count} total):
> Show the last 5 comments summarized (author, date, first ~200 characters of content)

### Step 5. Analyze Validity Against Nova Source

For each validity category, check the relevant indicators using the Nova source checkout at `/workspace/repos/nova/`:

**Configuration Issue**:
- Search `nova/conf/` for config options mentioned in the bug report (option names, section names, error messages referencing config)
- Check if the described behavior matches a known misconfiguration pattern
- Look for `oslo.config` option registrations (`cfg.StrOpt`, `cfg.IntOpt`, etc.) related to the issue
- Check `nova/conf/` files for deprecated options that may have changed behavior

**Unsupported Feature**:
- Check if the described deployment, driver, or feature is in Nova's supported set
- Search for capability flags in virt drivers (`nova/virt/`)
- Check API extension registrations and microversion boundaries
- Look for feature gates or config options that enable/disable the feature

**Incomplete Report**:
- Check if the bug includes: Nova version, steps to reproduce, logs or tracebacks, configuration details, deployment topology
- For each missing element, prepare a specific question for the reporter
- Common missing info: "What Nova version?", "What hypervisor/virt driver?", "Can you provide nova-compute logs?", "What's in your nova.conf for [section]?"

**Not Reproducible in Master**:
- Search `git log` in the Nova checkout for commits mentioning the bug ID, related keywords, or affecting the code path
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
- Propose an importance level based on impact:
  - Critical: data loss, regression, blocks upgrades
  - High: crashes, deadlocks, security implications
  - Medium: incorrect behavior with workaround
  - Low: edge case, cosmetic, trivial workaround

### Step 5b. Check for Duplicates

1. Extract key terms from the bug title and description (3-5 distinctive keywords)
2. Search Launchpad for Nova bugs with similar characteristics using `curl` against `https://api.launchpad.net/1.0/nova?ws.op=searchTasks&search_text={keywords}&status=New&status=Confirmed&status=Triaged&status=In+Progress&omit_duplicates=true`
3. For each candidate (max 5), assess similarity:
   - Title similarity
   - Matching tags
   - Affected subsystem overlap
4. Present ranked candidates with: bug ID, title, status, Launchpad URL, brief explanation of match
5. If no strong candidates found, report: "No duplicate candidates identified."

### Step 6. Present Classification

Present the triage result clearly:

**Validity Assessment**: {category}

**Rationale**: {1-3 sentences citing specific evidence from the bug report AND the Nova source checkout}

**Proposed Launchpad Changes**:
- Status: {current} → {proposed} (mapping: Configuration Issue → Invalid, Unsupported Feature → Won't Fix, Incomplete Report → Incomplete, Not Reproducible in Master → Invalid, RFE → Invalid, Likely Valid Bug → Triaged/Confirmed)
- Importance: {current} → {proposed} (for RFE: Wishlist; for Likely Valid Bug: proposed level; others: unchanged)

**Affected Subsystem**: {subsystem name}

**Confidence**: {High/Medium/Low}

**Duplicate Candidates**: {list or "None identified"}

**Source References**: {file paths and line numbers examined in the Nova checkout}

If Incomplete Report: also show **Questions for Reporter** with the specific information needed.

If RFE: also note **Recommendation**: "Consider filing a nova-spec or RFE for this feature request."

### Step 7. Await User Review

Present the classification for the triager's review. Do not proceed to any external action.

Offer next steps:
- `/nova-reproduce` — deeper source analysis to verify reproducibility
- `/nova-report` — generate a persistent triage report artifact
- `/nova-update-launchpad` — post the triage findings to Launchpad

## Output

The triage classification is held in session memory for use by `/nova-reproduce`, `/nova-report`, and `/nova-update-launchpad`.

No artifact is written by this skill — use `/nova-report` to generate a persistent artifact.

### Writing Style

Follow the rules in `rules.md`. In particular:

- Lead with the classification and a one-sentence rationale
- Cite specific file paths and line numbers from the Nova checkout
- Be constructive — suggest fixes for configuration issues, list specific questions for incomplete reports
- Keep the summary scannable — busy triagers should understand the verdict in seconds
