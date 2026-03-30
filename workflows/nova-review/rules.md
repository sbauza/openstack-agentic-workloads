# Rules

## Self-Review Before Presenting

Before presenting any output to the user:

1. Re-read your output as if you are a code reviewer
2. Check for:
   - Missing edge cases
   - Security issues (injection, validation, secrets)
   - Incomplete reasoning
   - Assumptions that should be stated
3. Autocorrect your response
4. Only then present to the user

If you found and fixed issues, briefly note: "Self-review: Fixed [issue]"

## Human-Readable Comments

All review comments — whether in artifacts, Gerrit, or conversation — must be written for human consumption:

- Write in plain, direct language — no jargon walls or template-speak
- Each comment should be self-contained: a reader should understand the issue without cross-referencing other comments
- Lead with **what's wrong and why it matters**, then suggest a fix
- Keep inline comments short — one issue, one actionable sentence or two
- Avoid dumping raw rule references alone (e.g., don't just say "N310 violation"); explain what the rule means in context (e.g., "Use `timeutils.utcnow()` here — `datetime.utcnow()` breaks Nova's time mocking in tests (N310)")
- Use a conversational, respectful tone — write as a helpful colleague, not an automated linter
