# Nova Spec Author

Generate well-structured nova-spec proposals from JIRA RFE tickets or free-form feature descriptions. Includes interactive clarification, architectural review via Nova core reviewer personas, and Launchpad blueprint registration.

## Skills

| Skill | Description |
|-------|-------------|
| `/create-spec` | Generate a nova-spec from a JIRA RFE or feature description |
| `/refine-spec` | Review and refine a generated spec with architectural feedback |
| `/blueprint` | Add Launchpad blueprint URL to a spec |

## Prerequisites

- **Required**: ACP session, Claude Code, or Cursor
- **Recommended**: `openstack/nova-specs` repository added to the workspace (for template and release detection)
- **Optional**: JIRA MCP integration configured (for automatic RFE ticket extraction; manual paste fallback available). In ACP, configure via **Workspace Settings**. For Claude Code or Cursor, see [Configuring MCP Servers](../../README.md#configuring-mcp-servers) in the main README.

## Usage

### Ambient Code Platform (ACP)

1. In ACP, select **"Custom Workflow..."**
2. Fill in the fields:
   - **URL**: `https://github.com/sbauza/openstack-agentic-workflows.git`
   - **Branch**: `main`
   - **Path**: `workflows/nova-spec-workflow`
3. Click **"Load Workflow"**

### Claude Code

Run `claude` from the workflow directory to auto-load skills, rules, and personas:

```bash
cd openstack-agentic-workflows/workflows/nova-spec-workflow
claude
```

Skills are available as slash commands: `/create-spec`, `/refine-spec`, `/blueprint`. Agent personas (`nova-core`, `nova-coresec`) are loaded automatically via `CLAUDE.md`.

### Cursor

Open the repository root in Cursor. Skills are discovered via symlinks in `.agents/skills/` with the `spec-` prefix:

| Cursor Skill | Maps To |
|--------------|---------|
| `spec-create-spec` | `/create-spec` |
| `spec-refine-spec` | `/refine-spec` |
| `spec-blueprint` | `/blueprint` |

Type `/` in the agent chat to invoke a skill. Agent personas are auto-detected from `agents/`.

### Create a Spec from a JIRA RFE

```text
/create-spec NOVA-1234
```

The workflow reads the JIRA ticket, asks you 3 clarification questions about the problem, use cases, and approach, then generates a complete nova-spec RST file.

### Create a Spec from a Description

```text
/create-spec Add support for live migration of instances with vGPUs
```

### Refine a Generated Spec

```text
/refine-spec
```

Checks structural completeness, invokes `nova-core` and `nova-coresec` agents for architectural review, and helps strengthen weak sections interactively.

### Add Blueprint URL

```text
/blueprint vgpu-live-migration
```

## Output

Generated specs are written to `artifacts/nova-spec-workflow/`. RST files are ready to be copied into the `nova-specs` repository for Gerrit submission.

## Agent Personas

This workflow reuses shared agent personas from the repository root:

- **nova-core** — Architectural fit, versioning, conductor boundary, upgrade safety
- **nova-coresec** — Security review for privsep, RBAC, credential handling
