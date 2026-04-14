---
name: nova-create-spec
description: Generate a nova-spec proposal from a JIRA RFE ticket or free-form feature description. Use when a contributor wants to write a new nova-spec from an RFE or feature idea.
---

# Create Spec

You are generating an OpenStack Nova specification proposal. Your goal is to help the contributor produce a well-structured RST document that follows the official nova-specs template, pre-populated with content derived from their input and clarification answers.

**Important**: JIRA RFE tickets are often unclear or incomplete. Always ask the contributor to explain the feature in their own words before generating -- use the JIRA content as context, not as the authoritative source.

## Input

The user will provide one of:

- A JIRA issue key (e.g., `NOVA-1234` or `https://jira.example.com/browse/NOVA-1234`)
- A free-form text description of a feature idea
- Pasted JIRA ticket content (when JIRA MCP is unavailable)

## Process

### 1. Determine Input Type

Parse the user's argument to detect the input type:

- **JIRA key pattern**: Matches `[A-Z]+-\d+` or contains a JIRA URL -> proceed to Step 2 (JIRA path)
- **Everything else**: Treat as free-form text -> skip to Step 3

### 2. Extract JIRA Ticket Content

a. **Check JIRA MCP availability**: Determine if `jira_get_issue` is callable.

b. **If JIRA MCP is available**:
   - Call `jira_get_issue` with the ticket key
   - Extract: summary, description, comments, linked issues, labels/components, priority, status
   - If linked issues exist, note them for the Dependencies section
   - Present a brief summary of the extracted content to the contributor

c. **If JIRA MCP is unavailable**:
   - Report: "JIRA MCP is not available in this session. To proceed with this ticket, please paste the JIRA ticket content (copy the description and any relevant comments)."
   - Process the pasted content as structured input, extracting the same fields where identifiable

d. **Error handling**:
   - If the JIRA key is not found: "Could not find JIRA ticket {key}. You can paste the ticket content manually, or provide a free-form feature description instead."
   - If the ticket spans multiple distinct features: Flag the multi-feature scope and suggest: "This RFE appears to cover multiple distinct features. Consider running /nova-create-spec separately for each feature."

### 3. Locate Nova-Specs Template

a. Check if the nova-specs repository is available at `/workspace/repos/nova-specs/`:
   - If available: read the template from `specs/templates/` (look for the most recent template file)
   - Extract the required section list and any section-specific guidance from the template

b. If the nova-specs repo is unavailable, use this standard section list:

   1. Problem description
   2. Use Cases
   3. Proposed change
   4. Alternatives
   5. Data model impact
   6. REST API impact
   7. Security impact
   8. Notifications impact
   9. Other end user impact
   10. Performance impact
   11. Other deployer impact
   12. Developer impact
   13. Implementation
   14. Dependencies
   15. Testing
   16. Documentation impact
   17. References

   Notify the contributor: "Nova-specs repo not found in workspace. Using standard template sections. Add the repo to your ACP session for automatic template detection."

### 4. Detect Target Release Directory

a. If the nova-specs repo is available:
   - List directories matching `specs/20*/` pattern
   - Sort and select the latest (e.g., `specs/2026.2/`)
   - The spec will be placed in `{latest}/approved/`
   - Report: "Targeting release: {release}"

b. If no release directories exist or repo is unavailable:
   - Fall back to `specs/backlog/`
   - Report: "No release directory detected. Spec will target specs/backlog/."

### 5. Ask Clarification Questions

Before generating, ask the contributor three targeted questions. Use any available input (JIRA content or free-form description) as context for each question.

**Adaptive behavior**: If the input already contains detailed information for a question, cite it and ask for confirmation or refinement rather than asking from scratch.

**Question 1 -- Problem Statement**:
> Based on [cite input context if available], **what problem does this feature solve?**
> Describe what is wrong, missing, or suboptimal in Nova today.

**Question 2 -- Use Cases**:
> **Who benefits from this feature and how would they use it?**
> Describe the operators, users, or developers affected and their specific scenarios.

**Question 3 -- Proposed Approach**:
> **What is your proposed approach to solving this?**
> Describe the high-level solution -- which Nova components are involved, what changes are needed.

Wait for the contributor to answer all three questions before proceeding.

### 6. Generate RST Spec

Map all available input to the 17 template sections using these rules:

**Content mapping**:

| Source | Priority | Maps to |
|--------|----------|---------|
| Contributor Q1 answer | Authoritative | Problem description |
| Contributor Q2 answer | Authoritative | Use Cases |
| Contributor Q3 answer | Authoritative | Proposed change |
| JIRA description | Supplementary | Problem description, Use Cases (additional context) |
| JIRA comments | Supplementary | Alternatives, additional context across sections |
| JIRA linked issues | Supplementary | Dependencies, References |
| JIRA labels/components | Supplementary | Helps identify affected impact sections |

**Conflict resolution**: If the contributor's answers contradict JIRA content, use the contributor's version. Add a brief note: `.. note:: Contributor clarified this differently from the original RFE discussion.`

**Section generation guidance**:
- **Problem description**: Lead with contributor's Q1 answer. Add JIRA context if it provides additional background.
- **Use Cases**: Lead with contributor's Q2 answer. Structure as numbered scenarios.
- **Proposed change**: Lead with contributor's Q3 answer. Expand with technical detail where possible.
- **Alternatives**: Include if mentioned in JIRA comments or contributor input. Otherwise add TODO marker.
- **Impact sections** (Data model, REST API, Security, Notifications, End user, Performance, Deployer, Developer): Infer from the proposed change description. If the change clearly requires a DB migration, API microversion, or policy change, note it. Otherwise add TODO marker with guidance on what to consider.
- **Implementation**: Always add TODO marker -- this requires the contributor's timeline and assignee information.
- **Dependencies**: Auto-populate from JIRA linked issues. Add any cross-project dependencies inferred from the proposed change.
- **Testing**: Infer testing approach from the proposed change. Otherwise add TODO marker.
- **Documentation impact**: Infer from the feature scope. Otherwise add TODO marker.
- **References**: Include JIRA ticket URL, any referenced blueprints, bugs, or external resources.

**TODO marker format**: Use `.. TODO:: [Guidance on what to add here]` for unfilled sections.

### 7. Handle Free-Form Input Specifics

When processing free-form text (no JIRA ticket):

- **Brief input** (1-2 sentences): Ask more detailed clarification questions. For example, if the contributor says "Add vGPU live migration", probe further: "Which virt drivers should support this?" or "Should this work across cells?"
- **Detailed input** (multiple paragraphs): Ask fewer clarification questions -- confirm understanding rather than re-asking what's already provided.
- **Multi-topic input**: If the description covers problem, use cases, and approach already, separate the content and map it to the appropriate questions/sections. Still ask the 3 questions but frame them as confirmation: "Based on your description, the problem seems to be [X]. Is that accurate, or would you refine it?"

### 8. Write Artifact and Present Summary

a. Derive the spec filename from the feature name:
   - Convert to lowercase, replace spaces with hyphens, remove special characters
   - Example: "vGPU Live Migration" -> `vgpu-live-migration.rst`

b. Write the RST file to `artifacts/nova-spec-workflow/{spec-name}.rst`

c. Present a summary to the contributor:

   ```
   ## Nova Spec Generated

   **File**: artifacts/nova-spec-workflow/{spec-name}.rst
   **Target**: specs/{release}/approved/{spec-name}.rst

   ### Section Status

   | Section | Status |
   |---------|--------|
   | Problem description | Populated |
   | Use Cases | Populated |
   | Proposed change | Populated |
   | Alternatives | TODO |
   | ... | ... |

   **Populated**: X/17 sections
   **TODO markers**: Y sections need your input

   ### Next Steps

   - Run `/nova-refine-spec` for structural and architectural review
   - Run `/nova-blueprint` to add the Launchpad blueprint URL
   - Copy the file to your nova-specs repo when ready for Gerrit submission
   ```

## Output

Write the generated spec to `artifacts/nova-spec-workflow/{spec-name}.rst`.

The RST file must:
- Start with the Launchpad blueprint URL placeholder (to be filled by `/nova-blueprint`)
- Contain all 17 required sections in the correct order
- Use RST section headers with underline characters (`=` for title, `-` for sections)
- Include `.. TODO::` markers for sections that could not be populated
- Follow nova-specs formatting conventions

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| JIRA key not found | Report error, offer manual paste or free-form fallback |
| JIRA MCP unavailable | Report status, prompt contributor to paste ticket content |
| Nova-specs repo missing | Use hardcoded 17-section template, warn contributor |
| No release directories | Place in `specs/backlog/`, notify contributor |
| Multi-feature JIRA RFE | Flag scope, suggest splitting into separate invocations |

### Writing Style

Follow the rules in `rules.md`. In particular:

- Write in the contributor's voice -- the spec will be submitted under their name
- Be specific: cite affected Nova subsystems, mention relevant config options
- Each section should be self-contained
- Get to the point -- avoid filler phrases
