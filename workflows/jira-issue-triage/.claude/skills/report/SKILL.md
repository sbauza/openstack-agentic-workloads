---
name: report
description: Generate a persistent triage report artifact from the current session analysis. Use after triage to save findings as a structured markdown report.
---

# Generate Triage Report

Create a structured markdown report consolidating all triage analysis performed in the current session. The report is saved as a persistent artifact.

## Input

Optional JIRA issue key. If omitted, uses the previously triaged issue from the current session.

Examples:
- `/report` (uses last triaged issue)
- `/report OSPRH-1234`

## Process

### Step 1. Load Context

1. Load triage classification from the current session (required — error if no prior `/triage` was run)
2. Load reproducibility assessment if `/reproduce` was run (optional — section marked "Not yet performed" if absent)
3. Load duplicate candidates if identified during triage (optional)

### Step 2. Generate Report

Create a structured markdown report with the following sections:

```markdown
# Triage Report: {issue_key}

**Generated**: {date}
**Triaged by**: AI-assisted triage (human-reviewed)
**JIRA**: {issue web URL}

## Issue Summary

- **Summary**: {summary}
- **Reporter**: {reporter}
- **Assignee**: {assignee or "Unassigned"}
- **Created**: {created date}
- **Status**: {current status}
- **Priority**: {current priority}
- **Resolution**: {current resolution or "Unresolved"}
- **Labels**: {labels}
- **Components**: {components}

### Description

> {description excerpt — first 2000 characters}

## Validity Assessment

**Classification**: {category}
**Confidence**: {High/Medium/Low}
**Affected Subsystem**: {subsystem}

### Rationale

{Detailed rationale citing evidence from the issue report and Nova source code}

### Source Code References

{List of file paths and line numbers examined}

## Reproducibility Findings

{If /reproduce was run: full assessment}
{If not run: "Reproducibility analysis not yet performed. Run `/reproduce` for deeper source analysis."}

## Duplicate Analysis

{If duplicates were checked: ranked list or "No duplicates identified"}
{If not checked: "Duplicate analysis not yet performed."}

## Recommended Actions

### Proposed JIRA Changes

- **Status**: {current} → {proposed}
- **Resolution**: {current} → {proposed}
- **Priority**: {current} → {proposed}

### Next Steps

{Category-specific recommendations:
- Configuration Issue: explain correct configuration
- Incomplete Report: list questions for reporter
- RFE: suggest filing nova-spec
- Likely Valid Bug: suggest assignment, tagging, priority}

## Proposed JIRA Comment

{Draft comment text formatted for posting to JIRA. This is used by /update-jira.}
```

### Step 3. Write Artifact

1. Create the `artifacts/jira-issue-triage/` directory if it doesn't exist
2. Save the report to `artifacts/jira-issue-triage/triage-{issue_key}.md`
3. If a report for this issue key already exists, overwrite it (latest triage takes precedence)

### Step 4. Confirm

Report the file path to the user:

> Triage report saved to `artifacts/jira-issue-triage/triage-{issue_key}.md`

Offer next steps:
- `/update-jira` — generate manual JIRA update instructions

## Output

Artifact written to `artifacts/jira-issue-triage/triage-{issue_key}.md`.

### Writing Style

Follow the rules in `rules.md`. In particular:

- The report should be self-contained — a reader should understand the triage decision without additional context
- Use clear section headers for easy scanning
- The Proposed JIRA Comment section should be ready for direct posting — write it in the tone of a helpful Nova community member
