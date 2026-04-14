---
name: nova-report
description: Generate a persistent triage report artifact from the current session analysis. Use after triage to save findings as a structured markdown report.
---

# Generate Triage Report

Create a structured markdown report consolidating all triage analysis performed in the current session. The report is saved as a persistent artifact.

## Input

Optional bug ID. If omitted, uses the previously triaged bug from the current session.

Examples:
- `/nova-report` (uses last triaged bug)
- `/nova-report 2112373`

## Process

### Step 1. Load Context

1. Load triage classification from the current session (required — error if no prior `/nova-triage` was run)
2. Load reproducibility assessment if `/nova-reproduce` was run (optional — section marked "Not yet performed" if absent)
3. Load duplicate candidates if identified during triage (optional)

### Step 2. Generate Report

Create a structured markdown report with the following sections:

```markdown
# Triage Report: Bug #{bug_id}

**Generated**: {date}
**Triaged by**: AI-assisted triage (human-reviewed)
**Launchpad**: {web_link}

## Bug Summary

- **Title**: {title}
- **Reporter**: {reporter}
- **Filed**: {date_created}
- **Status**: {current_status}
- **Importance**: {current_importance}
- **Tags**: {tags}
- **Private**: {yes/no}

### Description

> {description excerpt — first 2000 characters}

## Validity Assessment

**Classification**: {category}
**Confidence**: {High/Medium/Low}
**Affected Subsystem**: {subsystem}

### Rationale

{Detailed rationale citing evidence from the bug report and Nova source code}

### Source Code References

{List of file paths and line numbers examined}

## Reproducibility Findings

{If /nova-reproduce was run: full assessment}
{If not run: "Reproducibility analysis not yet performed. Run `/nova-reproduce` for deeper source analysis."}

## Duplicate Analysis

{If duplicates were checked: ranked list or "No duplicates identified"}
{If not checked: "Duplicate analysis not yet performed."}

## Recommended Actions

### Proposed Launchpad Changes

- **Status**: {current} → {proposed}
- **Importance**: {current} → {proposed}

### Next Steps

{Category-specific recommendations:
- Configuration Issue: explain correct configuration
- Incomplete Report: list questions for reporter
- RFE: suggest filing nova-spec
- Likely Valid Bug: suggest assignment, tagging, priority}

## Proposed Launchpad Comment

{Draft comment text formatted for posting to Launchpad. This is used by /nova-update-launchpad.}
```

### Step 3. Write Artifact

1. Create the `artifacts/nova-bug-triage/` directory if it doesn't exist
2. Save the report to `artifacts/nova-bug-triage/triage-{bug_id}.md`
3. If a report for this bug ID already exists, overwrite it (latest triage takes precedence)

### Step 4. Confirm

Report the file path to the user:

> Triage report saved to `artifacts/nova-bug-triage/triage-{bug_id}.md`

Offer next steps:
- `/nova-update-launchpad` — post the triage findings to Launchpad

## Output

Artifact written to `artifacts/nova-bug-triage/triage-{bug_id}.md`.

### Writing Style

Follow the rules in `rules.md`. In particular:

- The report should be self-contained — a reader should understand the triage decision without additional context
- Use clear section headers for easy scanning
- The Proposed Launchpad Comment section should be ready for direct posting — write it in the tone of a helpful Nova community member
