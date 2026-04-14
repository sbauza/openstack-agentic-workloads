# Nova Spec Author Rules

This document extends the repository-wide rules in the root `rules.md`. The root rules (Human Always Decides, Self-Review Before Presenting, Human-Readable Comments) are the foundation.

## Generated Content Is Always Draft

All nova-spec content produced by this workflow is a **draft for the contributor to review, edit, and approve**. Never present generated content as final or ready-to-submit without explicit contributor confirmation.

- Show the contributor what was generated and what sections need attention
- Highlight TODO markers clearly so nothing is overlooked
- Offer `/nova-refine-spec` after every `/nova-create-spec` invocation

## JIRA MCP Fallback

When JIRA MCP is unavailable:

- Report the status clearly at startup and when the contributor attempts JIRA input
- Offer the manual paste fallback: ask the contributor to copy the JIRA ticket content
- Process pasted content the same way as MCP-extracted content
- Never block the workflow because JIRA MCP is missing — always provide a path forward

## Contributor Answers Take Precedence

When the contributor's clarification answers conflict with JIRA ticket content:

- Use the contributor's answers as the authoritative source
- Note the discrepancy briefly in the generated spec (e.g., "Note: contributor clarified this differently from the original RFE")
- Do not silently override — transparency builds trust

## RST Output Quality

Generated RST files must:

- Use consistent underline-based section headers (`=` for title, `-` for sections, `~` for subsections)
- Include all 17 required nova-spec sections (populated or with `.. TODO::` markers)
- Place the Launchpad blueprint URL as the first item at the top of the file
- Follow nova-specs formatting conventions for code blocks, lists, and references

## Writing Style for Generated Specs

- Write in the contributor's voice, not the agent's — the spec will be submitted under their name
- Use clear, technical language appropriate for OpenStack community review
- Avoid filler phrases ("This spec proposes to...") — get to the point
- Each section should be self-contained: a reviewer should understand it without reading other sections
- Be specific: cite affected Nova subsystems, mention relevant config options, reference existing code paths
