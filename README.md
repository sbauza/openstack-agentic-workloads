# OpenStack Agentic Workflows

Custom workflow repository for OpenStack services. Workflows can be consumed by [Cursor](https://cursor.com) (as plugins), [Claude Code](https://claude.ai/code), or the [Ambient Code Platform](https://ambient.code) (ACP).

## Overview

This repository contains workflow definitions tailored for OpenStack development. Each workflow provides structured processes — skills, rules, and project-specific knowledge — that guide AI agents through complex OpenStack tasks like code review, spec authoring, bug triage, backporting, and Gerrit interaction.

All domain knowledge lives in shared, tool-agnostic files (`AGENTS.md`, `rules.md`, `knowledge/`, `agents/`). Tool-specific integration files are thin pointers that reference the shared content — skills use the same `SKILL.md` format across all tools, so nothing is duplicated.

## Available Workflows

| Workflow | Description | Skills |
|----------|-------------|--------|
| [**nova-review**](workflows/nova-review/) | Review Nova code changes and nova-specs proposals against project conventions and architecture | `/spec-review`, `/code-review`, `/gerrit-comment` |
| [**nova-bug-triage**](workflows/nova-bug-triage/) | Triage Nova Launchpad bug reports by validating whether they describe genuine defects or fall into invalid categories | `/triage`, `/reproduce`, `/report`, `/update-launchpad` |
| [**jira-issue-triage**](workflows/jira-issue-triage/) | Triage Nova JIRA issue reports against source code, classifying validity and generating update instructions | `/triage`, `/reproduce`, `/report`, `/update-jira` |
| [**nova-spec-workflow**](workflows/nova-spec-workflow/) | Generate well-structured nova-spec proposals from JIRA RFE tickets or free-form feature descriptions with architectural review | `/create-spec`, `/refine-spec`, `/blueprint` |
| [**gerrit-to-gitlab**](workflows/gerrit-to-gitlab/) | Backport merged upstream OpenStack Gerrit changes to internal GitLab repository stable branches | `/backport`, `/test`, `/create-mr` |

## Using Workflows

### With Cursor (Plugin)

Each workflow directory is a self-contained [Cursor plugin](https://cursor.com/docs/plugins). Symlink the workflows you want into Cursor's local plugins directory.

To load a plugin:

1. Clone this repository:

   ```bash
   git clone https://github.com/sbauza/openstack-agentic-workflows.git
   ```

2. Symlink individual workflow(s) into Cursor's local plugins directory:

   ```bash
   ln -s /path/to/openstack-agentic-workflows/workflows/nova-review \
     ~/.cursor/plugins/local/nova-review
   ```

   Each workflow contains symlinks (`knowledge/`, `agents/`, `global-rules.md`) that point back to the shared files at the repo root. These resolve correctly through the filesystem symlink, so each plugin is self-contained.

3. Restart Cursor (or run **Developer: Reload Window**)

Each plugin provides:

- **Rules** — workflow-specific guidelines, Nova project knowledge, and agent personas are loaded automatically
- **Skills** — the same `SKILL.md` skills available in Claude Code / ACP (e.g., `code-review`, `triage`, `backport`) are registered as Cursor agent skills

### With Claude Code

Clone or open this repository with Claude Code. The `CLAUDE.md` files (root and per-workflow) automatically load the shared knowledge via `@` includes. Skills are available via `/skill-name` (e.g., `/code-review`).

### With ACP (Ambient Code Platform)

Use the **Custom Workflow** feature in ACP:

1. In your ACP session, select **"Custom Workflow..."**
2. Fill in the fields:
   - **URL**: `https://github.com/sbauza/openstack-agentic-workflows.git`
   - **Branch**: `main` (or a feature branch for testing)
   - **Path**: path to the workflow directory (e.g., `workflows/nova-review`)
3. Click **"Load Workflow"**

## Shared Knowledge

The `knowledge/` directory contains shared project reference files that multiple workflows depend on. This avoids duplicating architecture, conventions, and design rules across workflows.

| File | Contents |
|------|----------|
| [`knowledge/nova.md`](knowledge/nova.md) | Nova architecture, directory structure, versioning rules, core services, coding conventions, virt drivers, external dependencies, and commit conventions |

All workflows reference `knowledge/nova.md` via `@../../knowledge/nova.md` in their `AGENTS.md` and add only workflow-specific content locally. The backport workflow (`gerrit-to-gitlab`) uses it to understand Nova's architecture when resolving cherry-pick conflicts. New Nova-related workflows should follow the same pattern rather than duplicating the shared reference.

## Agent Personas

The `agents/` directory contains reusable agent persona definitions that workflows can invoke as specialized subagents. Each persona encodes OpenStack domain expertise — versioning rules, triage patterns, security threat models — rather than generic software roles.

| Persona | File | Used By |
|---------|------|---------|
| Nova Core Reviewer | [`nova-core.md`](agents/nova-core.md) | nova-review, nova-spec-workflow, gerrit-to-gitlab |
| Nova Core Security | [`nova-coresec.md`](agents/nova-coresec.md) | nova-review, nova-bug-triage, jira-issue-triage, nova-spec-workflow |
| OpenStack Bug Triager | [`bug-triager.md`](agents/bug-triager.md) | nova-bug-triage, jira-issue-triage |
| Backport Specialist | [`backport-specialist.md`](agents/backport-specialist.md) | gerrit-to-gitlab |
| OpenStack Operator | [`openstack-operator.md`](agents/openstack-operator.md) | nova-bug-triage, jira-issue-triage |

See [`agents/README.md`](agents/README.md) for details on how personas work, when to use them, and how to create new ones.

## Repository Structure

```text
agents/
├── nova-core.md              # Nova core reviewer persona
├── nova-coresec.md           # Nova security reviewer persona
├── bug-triager.md            # Bug triage specialist persona
├── backport-specialist.md    # Backport specialist persona
├── openstack-operator.md    # Operator perspective persona
└── README.md                 # Persona documentation
knowledge/
└── nova.md                   # Shared Nova project reference (used by Nova workflows)
workflows/
├── nova-review/              # Nova code and spec review
│   ├── .ambient/
│   │   └── ambient.json      # ACP workflow config
│   ├── .claude/
│   │   └── skills/           # Skills shared by all tools (SKILL.md format)
│   ├── .cursor-plugin/
│   │   └── plugin.json       # Cursor plugin manifest (name + description)
│   ├── skills -> .claude/skills       # Symlink for Cursor auto-detection
│   ├── rules/
│   │   └── nova-review.mdc   # Cursor rules (@-refs via symlinks)
│   ├── knowledge -> ../../knowledge   # Symlink to shared project knowledge
│   ├── _agents -> ../../agents        # Symlink to shared personas (prefixed to avoid auto-detection)
│   ├── global-rules.md -> ../../rules.md  # Symlink to repo-level rules
│   ├── AGENTS.md             # Project reference (model-agnostic)
│   ├── CLAUDE.md             # Pointer to AGENTS.md (Claude Code)
│   ├── rules.md              # Behavioral rules
│   └── README.md
├── [other-workflows]/        # Same structure for all workflows
└── [future-workflows]/
```

### Workflow Requirements

Every workflow must have:

- `.ambient/ambient.json` with `name`, `description`, `systemPrompt`, and `startupPrompt`
- A `README.md` documenting its purpose and usage

## Design Principles

- **Do not duplicate deterministic checks.** If a linter or CI job already enforces a rule, the workflow should not re-check it.
- **Use in-tree docs as the source of truth.** Reference each project's contributor documentation rather than forking rules into the workflow.
- **Model-agnostic where possible.** Project knowledge goes in `AGENTS.md`; tool-specific files (`CLAUDE.md`, `.cursor-plugin/`) are thin integration layers. Skills use a shared `SKILL.md` format that works across all tools.
- **Human decides, agent assists.** Workflows provide analysis and draft comments, but the human makes final decisions (e.g., Gerrit votes).

## Contributing

1. Fork this repository
2. Create a new workflow directory under `workflows/`
3. Add `.ambient/ambient.json` with the required fields
4. Test using the "Custom Workflow" feature in ACP
5. Submit a pull request
