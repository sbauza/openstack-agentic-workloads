# Nova Review

An ACP workflow for reviewing OpenStack Nova code and specifications.

## Skills

| Skill | Description |
|-------|-------------|
| `/spec-review` | Review nova-specs proposals for completeness, technical soundness, and alignment with Nova architecture |
| `/code-review` | Review Nova code changes against coding conventions (N-codes), versioning rules, and testing requirements |
| `/gerrit-comment` | Post a review as inline and top-level comments on a Gerrit change (uses Gerrit MCP if available, otherwise REST API with HTTP auth) |

## Setup

This workflow works best when the Nova and nova-specs repositories are added to your ACP session:

- **nova** — The Nova compute service source code
- **nova-specs** — Specification proposals for Nova features

If repositories are not available, the workflow will guide you to add them or you can paste code/specs inline.

### Gerrit Integration

The workflow supports two modes for posting reviews to Gerrit:

1. **With Gerrit MCP** (preferred): Full integration via MCP server configured in your ACP session integrations
   - Automated review posting
   - Access to review history and patchset details

2. **Without Gerrit MCP** (fallback): REST API with HTTP basic authentication
   - Prompts for Gerrit username and password when posting reviews
   - Credentials never stored - prompted each time, cleared after use
   - Falls back to manual artifact generation if authentication fails

The workflow automatically detects Gerrit MCP availability at startup and adapts accordingly.

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

**Posting Methods**:
- **With Gerrit MCP**: Direct programmatic posting via MCP server
- **Without Gerrit MCP**: Posts via REST API using HTTP basic authentication
  - Prompts for Gerrit username and password (hidden input)
  - Credentials cleared immediately after use
  - Maximum 3 authentication attempts on failure
  - Falls back to manual artifact if authentication repeatedly fails
- **Manual Artifact Fallback**: Saves formatted comment to `artifacts/nova-review/gerrit-comment-{change}.md` for manual copy-paste to Gerrit UI

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
