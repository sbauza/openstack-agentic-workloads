# Nova Review

An ACP workflow for reviewing OpenStack Nova code and specifications.

## Skills

| Skill | Description |
|-------|-------------|
| `/spec-review` | Review nova-specs proposals for completeness, technical soundness, and alignment with Nova architecture |
| `/code-review` | Review Nova code changes against coding conventions (N-codes), versioning rules, and testing requirements |
| `/gerrit-comment` | Post a review as inline and top-level comments on a Gerrit change (requires Gerrit MCP server) |

## Setup

This workflow works best when the Nova and nova-specs repositories are added to your ACP session:

- **nova** — The Nova compute service source code
- **nova-specs** — Specification proposals for Nova features

If repositories are not available, the workflow will guide you to add them or you can paste code/specs inline.

To post reviews to Gerrit, the **Gerrit MCP server** must be configured in your ACP session integrations.

## What It Checks

### Spec Review

- Structural completeness against the Nova spec template (17 required sections)
- Versioning compliance (RPC, objects, DB, API microversions)
- Cell v2 awareness and conductor boundary compliance
- Cross-project impact assessment
- Risk assessment for high-impact patterns

### Code Review

- **Versioning rules** (blockers) — RPC version bumps, object versioning, DB migration safety, API microversions
- **N-code conventions** — 20+ Nova-specific hacking checks
- **Testing adequacy** — unit test coverage, proper assertion patterns
- **Conductor boundary** — compute never touches DB directly
- **Release notes** — whether `reno` notes are needed
- **API conventions** — terminology, HTTP status codes, microversion handling

### Gerrit Comment

- Transforms review findings into Gerrit top-level messages and inline file comments
- Maps verdicts to Code-Review label votes (+1, -1, or 0)
- Always previews the full comment and requires explicit user approval before posting
- Falls back to saving the formatted comment locally if the MCP server is unavailable

## Output

Review artifacts are written to `artifacts/nova-review/`:

- `spec-{name}.md` — Spec review reports
- `code-{topic}.md` — Code review reports
- `gerrit-comment-{change}.md` — Formatted Gerrit comments (only on post failure)

## File Structure

```text
workflows/nova-review/
├── .ambient/
│   └── ambient.json       # Workflow configuration
├── .claude/
│   └── skills/
│       ├── spec-review/
│       │   └── SKILL.md   # Spec review skill
│       ├── code-review/
│       │   └── SKILL.md   # Code review skill
│       └── gerrit-comment/
│           └── SKILL.md   # Post review to Gerrit
├── CLAUDE.md              # Nova project reference (conventions, architecture)
├── rules.md               # Behavioral rules (self-review, etc.)
└── README.md              # This file
```
