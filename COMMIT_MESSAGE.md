# Commit message convention

Format: `<type>(<scope>): <subject>`

Types: feat | fix | docs | chore | refactor | test | perf

Examples:
  feat(etl): add baseMouvementsStock parser
  fix(mail): correct DKIM selector mismatch
  chore(deps): bump wrangler to 3.x

Rules:
- Subject in lowercase imperative ("add", not "adds" or "added")
- No period at end
- Body: explain WHY, not what (the diff shows what)
- Breaking change: add `BREAKING CHANGE:` footer

Release tags: `YYYY-MM-DD-<slug>` — Michel reads "2026-04-22-postfix-live", not "v1.2.3"
