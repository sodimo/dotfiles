# Retired mail-stack quadlets

The on-prem mail server stack — `postfix`, `dovecot`, `rspamd`, `piler`,
`piler-mysql` — was removed from `dot_config/containers/systemd/` on
2026-05-05 (#23, harness#42).

Why retired: the in-house Postfix path was superseded by the **Apr 29 hybrid
Purelymail decision** (memory: `project_sodimo_email_arch`). Outbound mail
flows through Purelymail as the SMTP relay; inbound IMAP is fed via
`imapsync` from Purelymail to a local archive (no in-house MX). Vaultwarden,
Twenty CRM, and Paperclip outbound notifications all point at
`smtp.purelymail.com:587` post-cutover (env stubs are commented in their
respective `.env` files until the cutover lands).

The Piler email-archive frontend was removed alongside the rest because
its incoming-mail feed was the local Postfix LMTP path, which no longer
exists. If the operator decides to bring an archive back later, Piler can
be re-introduced fed by `imapsync` directly into its MailDir; the quadlet
shape is preserved in commit history (see `git log --diff-filter=D --
home/dot_config/containers/systemd/piler*`).

## What was removed

| File | Replaced by |
|---|---|
| `postfix.container` | Purelymail `smtp.purelymail.com:587` (commented in env files) |
| `dovecot.container` | Purelymail IMAP read-side (no on-prem MX) |
| `rspamd.container` | Not replaced (Purelymail handles inbound spam) |
| `piler.container` | TBD; not in Purelymail, archive scope deferred |
| `piler-mysql.container` | (sidecar of piler) |

## What was kept

The companion files (`postfix.env`, `postfix-main.cf`, `postfix-master.cf`,
`*.volume`, `dovecot.conf`) were left in place to make the rollback
mechanical if the decision ever flips. They have no effect on the running
stack without their respective `.container` units.

## Side effects on other quadlets

- `vaultwarden.env` — `SMTP_*` block converted from `SMTP_HOST=postfix` to a
  commented Purelymail stub (#26).
- `twenty.env` — `EMAIL_SMTP_HOST=postfix` removed; commented Purelymail
  stub block put in its place. `IS_IMAP_SMTP_CALDAV_ENABLED=true` retained
  so the feature flag stays on; outbound mail simply fails until cutover.
- `archive.caddy` route — kept (points at `piler:80`); will 502 until/unless
  Piler is reintroduced. Idempotent: harmless to leave.

## Cross-references

- `project_sodimo_email_arch` (Apr 29 hybrid Purelymail decision)
- `midday-handoff-paperclip-and-other-quadlets.md` Priority D
- harness#42 — track the bootc-side removal of Postfix/Dovecot OS packaging
- sodimo/changelog chapter 39 — pending: drop the Postfix/Dovecot/rspamd/piler
  cards or annotate as "Retired 2026-05-05"
