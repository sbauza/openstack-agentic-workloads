# OpenStack Agentic Workflows

Workflow repository for OpenStack services, usable with **Cursor**, **Claude Code**, and the **Ambient Code Platform** (ACP).

## Table of Contents

- [Overview](#overview)
- [Available Workflows](#available-workflows)
- [Quickstart](#quickstart)
  - [Invoking Skills](#invoking-skills)
  - [All Available Skills](#all-available-skills)
  - [Using Agent Personas](#using-agent-personas)
  - [Persona Reference](#persona-reference)
- [Using Workflows](#using-workflows)
  - [Cursor](#cursor)
  - [Claude Code](#claude-code)
  - [Ambient Code Platform (ACP)](#ambient-code-platform-acp)
  - [How Discovery Works Across Tools](#how-discovery-works-across-tools)
- [Configuring MCP Servers](#configuring-mcp-servers)
  - [Atlassian (JIRA)](#atlassian-jira)
  - [Gerrit](#gerrit)
  - [GitLab](#gitlab)
- [Shared Knowledge](#shared-knowledge)
- [Agent Personas](#agent-personas)
- [Repository Structure](#repository-structure)
- [Design Principles](#design-principles)
- [Contributing](#contributing)

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

## Quickstart

### Invoking Skills

Skills are the primary entry points for each workflow. They are invoked as slash commands.

**Claude Code** -- run `claude` from any workflow directory, then use slash commands:

```bash
cd workflows/nova-review
claude
# Inside Claude Code:
/code-review https://review.opendev.org/c/openstack/nova/+/912345
/spec-review specs/2024.2/approved/my-feature.rst
```

**Cursor** -- open the repo root in Cursor, then type `/` in the agent chat. Skills are prefixed by workflow to avoid name collisions:

```text
/review-code-review     # same as /code-review in nova-review
/jira-triage            # same as /triage in jira-issue-triage
/gtg-backport           # same as /backport in gerrit-to-gitlab
```

**ACP** -- load any workflow via Custom Workflow, then use the unprefixed skill names (`/triage`, `/backport`, etc.).

### All Available Skills

| Workflow | Skill | Cursor Name | What It Does |
|----------|-------|-------------|--------------|
| nova-review | `/spec-review` | `review-spec-review` | Review a nova-specs proposal |
| nova-review | `/code-review` | `review-code-review` | Review Nova code changes |
| nova-review | `/gerrit-comment` | `review-gerrit-comment` | Post review to Gerrit |
| nova-bug-triage | `/triage` | `nova-bug-triage` | Triage a Launchpad bug |
| nova-bug-triage | `/reproduce` | `nova-bug-reproduce` | Assess bug reproducibility |
| nova-bug-triage | `/report` | `nova-bug-report` | Generate triage report |
| nova-bug-triage | `/update-launchpad` | `nova-bug-update-launchpad` | Post triage to Launchpad |
| jira-issue-triage | `/triage` | `jira-triage` | Triage a JIRA issue |
| jira-issue-triage | `/reproduce` | `jira-reproduce` | Assess issue reproducibility |
| jira-issue-triage | `/report` | `jira-report` | Generate triage report |
| jira-issue-triage | `/update-jira` | `jira-update-jira` | Generate JIRA update instructions |
| nova-spec-workflow | `/create-spec` | `spec-create-spec` | Generate a nova-spec from RFE or description |
| nova-spec-workflow | `/refine-spec` | `spec-refine-spec` | Refine a spec with architectural review |
| nova-spec-workflow | `/blueprint` | `spec-blueprint` | Add Launchpad blueprint URL |
| gerrit-to-gitlab | `/backport` | `gtg-backport` | Cherry-pick a Gerrit change to GitLab |
| gerrit-to-gitlab | `/test` | `gtg-test` | Run tests on a backport branch |
| gerrit-to-gitlab | `/create-mr` | `gtg-create-mr` | Create a GitLab merge request |

### Using Agent Personas

Personas are specialized subagents that skills invoke automatically when needed. You can also reference them directly in conversation.

**Claude Code** -- personas are loaded via `@` references in `CLAUDE.md`. Within a workflow session, mention a persona to get its perspective:

```text
# Personas are invoked automatically by skills, but you can also ask directly:
"What would nova-core say about this change?"
"Can you review this from a security perspective?" (triggers nova-coresec)
```

**Cursor** -- persona files in `agents/` are auto-detected. Reference them in your prompt:

```text
@nova-core.md review this diff for versioning issues
@bug-triager.md classify this bug report
```

### Persona Reference

| Persona | File | Expertise | Used By |
|---------|------|-----------|---------|
| Nova Core Reviewer | `@nova-core.md` | Versioning, conductor boundary, API microversions, upgrade safety | nova-review, nova-spec-workflow |
| Nova Core Security | `@nova-coresec.md` | Privsep, RBAC, credentials, vulnerability assessment | nova-review, nova-bug-triage, jira-issue-triage, nova-spec-workflow |
| OpenStack Bug Triager | `@bug-triager.md` | Bug classification, Launchpad lifecycle, common not-a-bug patterns | nova-bug-triage, jira-issue-triage |
| Backport Specialist | `@backport-specialist.md` | Dependency analysis, conflict resolution, stable branch conventions | gerrit-to-gitlab |
| OpenStack Operator | `@openstack-operator.md` | Config troubleshooting, deployment topology, upgrade paths | nova-bug-triage, jira-issue-triage |

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

## Configuring MCP Servers

Some workflows integrate with external services via MCP (Model Context Protocol) servers. Each workflow gracefully degrades when an MCP server is unavailable — see individual workflow READMEs for fallback details.

| MCP Server | Used By | Purpose |
|------------|---------|---------|
| Atlassian (JIRA) | jira-issue-triage, nova-spec-workflow | Fetch JIRA issues, search duplicates, discover transitions |
| Gerrit | nova-review, gerrit-to-gitlab | Fetch change metadata, post reviews, query topics |
| GitLab | gerrit-to-gitlab | List branches, create merge requests |

### Where to Put MCP Configuration

| Tool | Global (personal) | Per-project (shared) |
|------|-------------------|---------------------|
| Claude Code | `~/.claude.json` | `.claude/settings.json` |
| Cursor | `~/.cursor/mcp.json` | `.cursor/mcp.json` |
| ACP | Workspace Settings UI | Integrations UI |

The JSON format is the same for both Claude Code and Cursor — add entries under the `mcpServers` key. The examples below work in either tool's config file.

For ACP, MCP integrations are configured through the UI: go to **Workspace Settings** (Atlassian) or **Integrations** (Gerrit, GitLab) in your ACP session.

### Atlassian (JIRA)

Uses [mcp-atlassian](https://github.com/sooperset/mcp-atlassian) (Python). Requires `uv` (`brew install uv` or `pip install uv`).

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://your-instance.atlassian.net",
        "JIRA_USERNAME": "you@example.com",
        "JIRA_API_TOKEN": "YOUR_JIRA_API_TOKEN",
        "JIRA_SSL_VERIFY": "true",
        "READ_ONLY_MODE": "true"
      }
    }
  }
}
```

Set `READ_ONLY_MODE` to `"true"` for triage workflows (jira-issue-triage, nova-spec-workflow) where write access is not needed. Set to `"false"` if you need write operations.

For JIRA Server/Data Center, use a personal access token instead of username + API token:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://jira.your-company.com",
        "JIRA_PERSONAL_TOKEN": "YOUR_PERSONAL_ACCESS_TOKEN",
        "JIRA_SSL_VERIFY": "true",
        "READ_ONLY_MODE": "true"
      }
    }
  }
}
```

Generate a Cloud API token at [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

Claude Code alternative — add via CLI:

```bash
claude mcp add-json "mcp-atlassian" \
  '{"command":"uvx","args":["mcp-atlassian"],"env":{"JIRA_URL":"https://your-instance.atlassian.net","JIRA_USERNAME":"you@example.com","JIRA_API_TOKEN":"YOUR_TOKEN","JIRA_SSL_VERIFY":"true","READ_ONLY_MODE":"true"}}'
```

### Gerrit

Uses the official [gerrit-mcp-server](https://github.com/GerritCodeReview/gerrit-mcp-server) (Python). Requires Python 3.11+.

#### 1. Install the server

```bash
git clone https://gerrit.googlesource.com/gerrit-mcp-server /opt/gerrit-mcp-server
cd /opt/gerrit-mcp-server
./build-gerrit.sh
```

#### 2. Configure `gerrit_config.json`

Create the config file at `gerrit_mcp_server/gerrit_config.json`:

```bash
cp gerrit_mcp_server/gerrit_config.sample.json gerrit_mcp_server/gerrit_config.json
```

Edit it with your OpenDev Gerrit credentials:

```json
{
  "default_gerrit_base_url": "https://review.opendev.org/",
  "gerrit_hosts": [
    {
      "name": "OpenDev",
      "external_url": "https://review.opendev.org/",
      "authentication": {
        "type": "http_basic",
        "username": "YOUR_GERRIT_USERNAME",
        "auth_token": "YOUR_HTTP_PASSWORD"
      }
    }
  ]
}
```

Alternatively, use `git_cookies` authentication if you already have `~/.gitcookies` configured:

```json
{
  "default_gerrit_base_url": "https://review.opendev.org/",
  "gerrit_hosts": [
    {
      "name": "OpenDev",
      "external_url": "https://review.opendev.org/",
      "authentication": {
        "type": "git_cookies",
        "gitcookies_path": "~/.gitcookies"
      }
    }
  ]
}
```

Find your HTTP password at [https://review.opendev.org/settings/#HTTPCredentials](https://review.opendev.org/settings/#HTTPCredentials).

#### 3. Add to Claude Code or Cursor

The server runs in STDIO mode. Replace `/opt/gerrit-mcp-server` with your actual install path:

```json
{
  "mcpServers": {
    "gerrit": {
      "command": "/opt/gerrit-mcp-server/.venv/bin/python",
      "args": [
        "/opt/gerrit-mcp-server/gerrit_mcp_server/main.py",
        "stdio"
      ],
      "env": {
        "PYTHONPATH": "/opt/gerrit-mcp-server/"
      }
    }
  }
}
```

For read-only access (fetching change metadata, querying topics), authentication can be omitted — OpenDev's Gerrit allows anonymous reads.

### GitLab

The `gerrit-to-gitlab` workflow interacts with GitLab via the `glab` CLI and git operations — no MCP server is required. This is how ACP handles GitLab integration.

#### 1. Install the GitLab CLI

```bash
# macOS
brew install glab

# Linux (binary)
curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v1.52.0/downloads/glab_1.52.0_linux_amd64.tar.gz" \
  | tar -xz -C /usr/local/bin --strip-components=1 bin/glab
```

See [https://gitlab.com/gitlab-org/cli](https://gitlab.com/gitlab-org/cli) for other install methods.

#### 2. Authenticate

```bash
# Option A: Personal access token (recommended)
export GITLAB_TOKEN="YOUR_GITLAB_TOKEN"
glab auth login --hostname gitlab.example.com --token "$GITLAB_TOKEN"

# Option B: Interactive browser login
glab auth login --hostname gitlab.example.com
```

Generate a personal access token with `api` and `write_repository` scopes at `https://gitlab.example.com/-/user_settings/personal_access_tokens`.

The `GITLAB_TOKEN` environment variable is also used by the workflow's git credential helper for clone, fetch, and push operations.

#### 3. Optional: GitLab MCP Server

If you want MCP-based GitLab integration (for branch listing and MR creation via MCP tools instead of `glab`), two options are available:

**Official GitLab MCP (GitLab 18.6+)** — OAuth-based, no tokens in config files:

```bash
# Claude Code
claude mcp add --transport http GitLab https://gitlab.example.com/api/v4/mcp
```

```json
// Cursor (.cursor/mcp.json)
{
  "mcpServers": {
    "gitlab": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://gitlab.example.com/api/v4/mcp"]
    }
  }
}
```

**Reference MCP server (any GitLab version)** — uses [@modelcontextprotocol/server-gitlab](https://www.npmjs.com/package/@modelcontextprotocol/server-gitlab):

```json
{
  "mcpServers": {
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-gitlab"],
      "env": {
        "GITLAB_PERSONAL_ACCESS_TOKEN": "YOUR_GITLAB_TOKEN",
        "GITLAB_API_URL": "https://gitlab.example.com/api/v4"
      }
    }
  }
}
```

### Which Workflows Need Which MCP Servers

| Workflow | Required MCP | Optional MCP | Without MCP |
|----------|-------------|-------------|-------------|
| nova-review | -- | Gerrit | REST API fallback for review posting; manual artifact for comments |
| nova-bug-triage | -- | -- | Fully functional (uses Launchpad REST API directly) |
| jira-issue-triage | Atlassian | -- | Cannot fetch JIRA issues without MCP |
| nova-spec-workflow | -- | Atlassian | Manual paste of JIRA ticket content |
| gerrit-to-gitlab | -- | Gerrit, GitLab | REST API + `glab` CLI + git for both; manual MR template if no GitLab access |

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

### Adding a New Workflow

1. **Create the workflow directory** under `workflows/{service}-{purpose}/` (e.g., `workflows/neutron-review/`)

2. **Add the required config** at `.ambient/ambient.json`:

   ```json
   {
     "name": "Workflow Name",
     "description": "Brief description of what the workflow does.",
     "systemPrompt": "You are a ...\n\n## Skills\n- /skill-name — ...\n\n## Output\nartifacts/{workflow-name}/",
     "startupPrompt": "Welcome! Use /skill-name to start."
   }
   ```

   The `systemPrompt` should include a role definition, list of available skills, workflow phases, output locations, and a workspace navigation block. See `AGENTS.md` for full guidelines on writing effective system prompts.

3. **Add skills** in `.claude/skills/{skill-name}/SKILL.md`. Each skill needs YAML frontmatter (`name`, `description`) and a structured body with Process, Output, and Writing Style sections.

4. **Add Cursor symlinks** so Cursor discovers your skills. Use a workflow prefix to avoid name collisions:

   ```bash
   # Pick a short prefix (e.g., "neutron" for neutron-review)
   ln -s ../../workflows/neutron-review/.claude/skills/my-skill .agents/skills/neutron-my-skill
   ```

   See the prefix table in `AGENTS.md` for existing prefixes.

5. **Add project context files**:
   - `AGENTS.md` — model-agnostic project reference (architecture, conventions, key paths). Reference shared knowledge with `@../../knowledge/nova.md` rather than duplicating it.
   - `CLAUDE.md` — a thin pointer: `@AGENTS.md` and `@rules.md`
   - `rules.md` — behavioral rules specific to this workflow

6. **Add a `README.md`** documenting the workflow's purpose, prerequisites, available skills, and usage instructions for ACP, Claude Code, and Cursor.

7. **Reference agent personas** if your workflow benefits from subagent expertise. Use `@../../agents/{persona}.md` in skill files to invoke shared personas (e.g., `@../../agents/nova-core.md` for architectural review). If you need a workflow-specific persona, create it in `.claude/agents/` within your workflow directory.

8. **Test the workflow** before merging. You can use any of the three supported tools:

   **ACP** — load your branch via Custom Workflow:
   - Push your branch to GitHub
   - In ACP, select **Custom Workflow...**
   - Enter the repo URL, your branch name, and the workflow path (e.g., `workflows/neutron-review`)
   - Run each skill end-to-end

   **Claude Code** — run directly from your local checkout:

   ```bash
   cd workflows/neutron-review
   claude
   # Then invoke skills: /my-skill
   ```

   **Cursor** — open the repo root in Cursor. Skills are available immediately via `.agents/skills/` symlinks. Type `/` in the agent chat and look for your prefixed skill name (e.g., `/neutron-my-skill`).

### Modifying an Existing Workflow

1. **Read first** — understand the current `ambient.json`, skills, and `AGENTS.md` before changing anything
2. **Scope your changes** — each workflow is independent. Do not propagate changes to other workflows unless explicitly asked
3. **Preserve existing skills** — do not remove or rename skills without explicit instruction, as users may depend on them
4. **Keep paths consistent** — if you change artifact output paths, update both the `systemPrompt` and the `results` field in `ambient.json`
5. **Update Cursor symlinks** — if you add or rename a skill, update the corresponding symlink in `.agents/skills/`

### Adding a New Agent Persona

1. Create the persona file in `agents/{persona-name}.md` with YAML frontmatter (`name`, `description`, `tools`) and a structured body defining personality, domain knowledge, and key behaviors
2. Reference the persona from workflow skills using `@../../agents/{persona-name}.md`
3. Update the persona tables in `AGENTS.md` and this README

### Checklist

Before submitting a pull request:

- [ ] `.ambient/ambient.json` is valid JSON with all 4 required fields
- [ ] `systemPrompt` includes a workspace navigation block and lists all skills
- [ ] Skills have YAML frontmatter and do not duplicate deterministic checks (linters, CI)
- [ ] Human approval is required before any external action (Gerrit posts, JIRA updates, etc.)
- [ ] Cursor symlinks exist in `.agents/skills/` with the correct workflow prefix
- [ ] `README.md` documents purpose, prerequisites, skills, and usage for ACP/Claude Code/Cursor
- [ ] All markdown follows linting standards (blank lines around headings, lists, and code blocks)
