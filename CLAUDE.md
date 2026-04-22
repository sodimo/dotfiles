# CLAUDE.md

## Repo identity

See `REPO.md` for slug, chapter, audience, and dependency graph.

## Conventions

- Commits: see `COMMIT_MESSAGE.md`
- Releases: calver `YYYY-MM-DD-dotfiles` via release-please from conventional commits
- Regressions are new releases — never edit past changelog entries
- "Deployed" = `chezmoi apply` runs cleanly on the harness AND every `sodimo.target` unit is `active (running)` for 5 consecutive business days

## Sodimo stack

- DNS / R2 / D1 / CF Access / Pages / Workers / Queues: Cloudflare
- SMTP / IMAP / LLM inference / CRM / Vault: Framework Desktop on-prem (Tailscale + Cloudflare Tunnel bound)
- Secrets: Vaultwarden (this repo ships the quadlet); chezmoi age-encrypts anything that lands in `home/` at render time

## Branch rules

- `main` is always deployable
- PRs required for any quadlet change or env-var change
- CODEOWNERS enforced on `home/dot_config/containers/systemd/**`

## Principle alignment

This repo is the concrete expression of three design principles from the manual (`15-design-principles.md`):

1. **Conceptual-fork-over-upstream** — every pinned image is owned; no `:latest` tags in production; upstream configs are adapted, not tracked. Exceptions: decades-stable OSS (Postfix, Dovecot, rspamd) run near-upstream because the breakage surface is tiny.
2. **Token accounting** — OpenWebUI, LiteLLM and the Paperclip sync job all emit to the D1 `run_ledger`. Quadlets that invoke an LLM carry the emission hook in their env or sidecar.
3. **Single MCP surface** — no on-prem MCP server in this repo. Email-send and Paperclip-mirror go through pull-based systemd units (`sodimo-email-drain.service`, `paperclip-d1-mirror.timer`), not through a local MCP daemon.

## What this repo does NOT own

- The bootc OS image — `sodimo/harness`.
- MCP tool implementations — `sodimo/mcp`.
- Twenty CRM customizations (MCP wrapper, turbular) — `sodimo/crm`.
- Skills content beyond the small operator set — `sodimo/skills`.
- Secrets material — Vaultwarden + paper.

See `REPO.md` `consumed_by` / `depends_on` fields.
