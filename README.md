# OpenStack Agentic Workflows

Workflow repository for OpenStack services, usable with **Cursor**, **Claude Code**, and the **Ambient Code Platform** (ACP).

## Overview

This repository contains workflow definitions tailored for OpenStack development. Each workflow provides structured processes — skills, rules, and project-specific knowledge — that guide AI agents through complex OpenStack tasks like code review, spec authoring, bug triage, backporting, and Gerrit interaction.

All content is authored once and discovered by multiple tools through standard conventions and symlinks — no duplication across tools.

## Available Workflows

| Workflow | Description | Skills |
|----------|-------------|--------|
| [**nova-review**](workflows/nova-review/) | Review Nova code changes and nova-specs proposals against project conventions and architecture | `/spec-review`, `/code-review`, `/gerrit-comment` |
| [**nova-bug-triage**](workflows/nova-bug-triage/) | Triage Nova Launchpad bug reports by validating whether they describe genuine defects or fall into invalid categories | `/triage`, `/reproduce`, `/report`, `/update-launchpad` |
| [**jira-issue-triage**](workflows/jira-issue-triage/) | Triage Nova JIRA issue reports against source code, classifying validity and generating update instructions | `/triage`, `/reproduce`, `/report`, `/update-jira` |
| [**nova-spec-workflow**](workflows/nova-spec-workflow/) | Generate well-structured nova-spec proposals from JIRA RFE tickets or free-form feature descriptions with architectural review | `/create-spec`, `/refine-spec`, `/blueprint` |
| [**gerrit-to-gitlab**](workflows/gerrit-to-gitlab/) | Backport merged upstream OpenStack Gerrit changes to internal GitLab repository stable branches | `/backport`, `/test`, `/create-mr` |

## Using Workflows

### Cursor

Clone or open this repository as a project in Cursor. Everything is auto-discovered:

- **Skills** from `.agents/skills/` — all 17 workflow skills are available via symlinks, prefixed by workflow to avoid name collisions (e.g., `gtg-backport`, `jira-triage`, `review-code-review`). Type `/` in the agent chat to invoke a skill directly.
- **Rules** from `.cursor/rules/` — the global behavioral rules (`rules.md`) are loaded via an `.mdc` rule file with `alwaysApply: true`
- **Agent personas** from `agents/` — the shared persona files (e.g., `nova-core.md`, `bug-triager.md`) are auto-detected
- **Project context** from `AGENTS.md` — read automatically at startup, including nested `AGENTS.md` files in each workflow directory

No plugin or additional configuration is needed. Open the repository in Cursor and all skills, rules, and personas are available immediately.

### Claude Code

Clone this repository and run `claude` from within it. Claude Code automatically reads:

- **`CLAUDE.md`** at the project root — a thin pointer that loads `AGENTS.md` (project guidelines) and `rules.md` (behavioral rules) into the agent context
- **Skills** from `.claude/skills/*/SKILL.md` within each workflow directory — these are the canonical skill files that Cursor also reads via symlinks
- **Per-workflow context** — each workflow has its own `CLAUDE.md` that loads the workflow's `AGENTS.md` and `rules.md`, plus shared knowledge from `knowledge/` and agent personas from `agents/`

#### Working with an OpenStack repo (e.g., Nova)

The workflows in this repository are designed to analyze and act on OpenStack project source code (Nova, Neutron, etc.) without bundling that code here. To use a workflow with Claude Code:

1. Clone both repositories side by side:

   ```bash
   git clone https://github.com/sbauza/openstack-agentic-workflows.git
   git clone https://opendev.org/openstack/nova.git
   ```

2. Run `claude` from the workflow directory:

   ```bash
   cd openstack-agentic-workflows/workflows/nova-review
   claude
   ```

3. Claude Code loads the workflow's `CLAUDE.md`, skills, rules, and personas automatically. It can read and edit files anywhere on disk, so it will access the Nova repo at its cloned path (e.g., `../../nova/` or `/path/to/nova/`) when skills reference it.

This works because Claude Code is not restricted to the current directory for file access — it uses the working directory only for context discovery (`CLAUDE.md`, `.claude/skills/`). The skills themselves reference the target repo by path.

### Ambient Code Platform (ACP)

Use the **Custom Workflow** feature in ACP:

1. In your ACP session, select **"Custom Workflow..."**
2. Fill in the fields:
   - **URL**: `https://github.com/sbauza/openstack-agentic-workflows.git`
   - **Branch**: `main` (or a feature branch for testing)
   - **Path**: path to the workflow directory (e.g., `workflows/nova-review`)
3. Click **"Load Workflow"**

ACP reads `.ambient/ambient.json` for the workflow configuration (`systemPrompt`, `startupPrompt`) and discovers skills from `.claude/skills/*/SKILL.md`.

### How Discovery Works Across Tools

| Component | Canonical location | Cursor | Claude Code | ACP |
|-----------|-------------------|--------|-------------|-----|
| Skills | `workflows/{name}/.claude/skills/*/SKILL.md` | `.agents/skills/` symlinks | `.claude/skills/` directly | via `systemPrompt` |
| Rules | `rules.md` | `.cursor/rules/*.mdc` | `CLAUDE.md` → `@rules.md` | `systemPrompt` embeds rules |
| Personas | `agents/*.md` | auto-detected | `@../../agents/*.md` refs | `systemPrompt` references |
| Knowledge | `knowledge/*.md` | auto-detected | `@../../knowledge/*.md` refs | `systemPrompt` references |
| Project context | `AGENTS.md` | auto-detected | `CLAUDE.md` → `@AGENTS.md` | `systemPrompt` embeds |

## Shared Knowledge

The `knowledge/` directory contains shared project reference files that multiple workflows depend on. This avoids duplicating architecture, conventions, and design rules across workflows.

| File | Contents |
|------|----------|
| [`knowledge/nova.md`](knowledge/nova.md) | Nova architecture, directory structure, versioning rules, core services, coding conventions, virt drivers, external dependencies, and commit conventions |

Workflows that need Nova domain knowledge (e.g., `nova-review`, `nova-bug-triage`, `nova-spec-workflow`) reference `knowledge/nova.md` via `@../../knowledge/nova.md` in their `AGENTS.md` and add only workflow-specific content locally. New Nova-related workflows should follow the same pattern rather than duplicating the shared reference.

## Agent Personas

The `agents/` directory contains reusable agent persona definitions that workflows can invoke as specialized subagents. Each persona encodes OpenStack domain expertise — versioning rules, triage patterns, security threat models — rather than generic software roles.

| Persona | File | Used By |
|---------|------|---------|
| Nova Core Reviewer | [`nova-core.md`](agents/nova-core.md) | nova-review, nova-spec-workflow |
| Nova Core Security | [`nova-coresec.md`](agents/nova-coresec.md) | nova-review, nova-bug-triage, jira-issue-triage, nova-spec-workflow |
| OpenStack Bug Triager | [`bug-triager.md`](agents/bug-triager.md) | nova-bug-triage, jira-issue-triage |
| Backport Specialist | [`backport-specialist.md`](agents/backport-specialist.md) | gerrit-to-gitlab |
| OpenStack Operator | [`openstack-operator.md`](agents/openstack-operator.md) | nova-bug-triage, jira-issue-triage |

See [`agents/README.md`](agents/README.md) for details on how personas work, when to use them, and how to create new ones.

## Repository Structure

```text
.agents/
└── skills/                    # Cursor skill discovery (symlinks to .claude/skills/)
    ├── gtg-backport/          # → workflows/gerrit-to-gitlab/.claude/skills/backport
    ├── jira-triage/           # → workflows/jira-issue-triage/.claude/skills/triage
    ├── review-code-review/    # → workflows/nova-review/.claude/skills/code-review
    ├── spec-create-spec/      # → workflows/nova-spec-workflow/.claude/skills/create-spec
    └── ...                    # (17 symlinks total, prefixed by workflow)
.cursor/
└── rules/
    └── openstack-rules.mdc   # Cursor rule file (references rules.md)
agents/
├── nova-core.md               # Nova core reviewer persona
├── nova-coresec.md            # Nova security reviewer persona
├── bug-triager.md             # Bug triage specialist persona
├── backport-specialist.md     # Backport specialist persona
├── openstack-operator.md     # Operator perspective persona
└── README.md                  # Persona documentation
knowledge/
└── nova.md                    # Shared Nova project reference (used by Nova workflows)
workflows/
├── nova-review/               # Nova code and spec review
│   ├── .ambient/
│   │   └── ambient.json       # Workflow config (name, description, prompts)
│   ├── .claude/
│   │   └── skills/            # Review skills (spec-review, code-review, gerrit-comment)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── rules.md
│   └── README.md
├── nova-bug-triage/           # Nova Launchpad bug triage
├── jira-issue-triage/         # Nova JIRA issue triage
├── gerrit-to-gitlab/          # Gerrit-to-GitLab backport workflow
├── nova-spec-workflow/        # Nova spec authoring from JIRA RFEs or descriptions
└── [future-workflows]/        # Workflows for other OpenStack services
```

### Workflow Requirements

Every workflow must have:

- `.ambient/ambient.json` with `name`, `description`, `systemPrompt`, and `startupPrompt`
- A `README.md` documenting its purpose and usage

## Design Principles

- **Do not duplicate deterministic checks.** If a linter or CI job already enforces a rule, the workflow should not re-check it.
- **Use in-tree docs as the source of truth.** Reference each project's contributor documentation rather than forking rules into the workflow.
- **Multi-tool, zero duplication.** Skills, rules, and knowledge are authored once and discovered by multiple tools via symlinks and pointer files. `AGENTS.md` is the model-agnostic reference; `CLAUDE.md` points to it for Claude; `.agents/skills/` symlinks expose `.claude/skills/` to Cursor; `.cursor/rules/` references `rules.md`.
- **Human decides, agent assists.** Workflows provide analysis and draft comments, but the human makes final decisions (e.g., Gerrit votes).

## Contributing

1. Fork this repository
2. Create a new workflow directory under `workflows/`
3. Add `.ambient/ambient.json` with the required fields
4. Test using the "Custom Workflow" feature in ACP
5. Submit a pull request
