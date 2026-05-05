# dotfiles

> Chezmoi-managed `home/` for the Sodimo Framework Desktop harness — quadlets, Caddyfile, shell config, operator skills.

See [`REPO.md`](REPO.md) for architecture metadata (chapter, audience, dependencies).

## Status

Chapter 1 — [changelog.sodimo.eu](https://changelog.sodimo.eu) · see the `35a-…` quadlet reference chapters.

## Layout

```
home/
├── .chezmoi.yaml.tmpl          # operator/network metadata (no secrets)
├── .chezmoiignore              # excludes live env files (real secrets) from chezmoi sync
├── dot_bashrc                  # shell baseline
├── dot_gitconfig.tmpl          # git identity
└── dot_config/
    ├── caddy/                  # Caddyfile + per-service HTTP routes (cf-access-aware)
    ├── cloudflared/            # single tunnel config; credentials via vault-fetch
    ├── sodimo/                 # per-service env shape files (mode 0600 on the box)
    │   ├── paperclip.env       # populated by `vault-fetch paperclip` at deploy time
    │   ├── vaultwarden.env     # populated by `vault-fetch vaultwarden` at deploy time
    │   └── cockpit.conf.snippet  # host-side cockpit.conf reference
    ├── containers/systemd/     # podman Quadlet definitions
    │   ├── sodimo.network      # 10.89.0.0/24 shared bridge
    │   ├── caddy.container     # reverse proxy (closed #21)
    │   ├── openwebui{,-db,-redis}.container + openwebui.env
    │   ├── litellm{,-postgres,-redis}.container + litellm.yaml + litellm.env
    │   ├── llama-swap.container + llama-swap.yaml
    │   ├── twenty{,-worker,-db,-redis}.container + twenty.env
    │   ├── vaultwarden{,-data}.container
    │   ├── paperclip{,-db}.container
    │   ├── sodiwin-etl.timer + sodiwin-etl.service
    │   └── sodimo-email-drain.service
    ├── systemd/user/
    │   └── sodimo.target       # grouping target for the whole stack
    └── dot_local/bin/
        ├── executable_vault-fetch          # bw CLI wrapper, populates *.env (#25)
        ├── executable_sodimo-email-drain   # CF Queue → sendmail relay
        └── executable_sodiwin-etl          # nightly ETL helper

skills/                         # operator skills (git-history-mgmt, remote-connection, ...)
docs/
├── retired-mail-quadlets.md    # postfix/dovecot/rspamd/piler removed 2026-05-05
└── ...
```

### What's NOT in this repo

- **Cockpit container** — retired (#23). The bootc image runs `cockpit.socket`
  system-scope; Caddy proxies `cockpit.sodimo.eu` straight to host
  `127.0.0.1:9090`. See `home/dot_config/sodimo/cockpit.conf.snippet`.
- **Mail-stack quadlets** (`postfix`, `dovecot`, `rspamd`, `piler`,
  `piler-mysql`) — retired 2026-05-05; superseded by the hybrid Purelymail
  decision (memory: `project_sodimo_email_arch`). Outbound through
  `smtp.purelymail.com:587`; the `*.env` files carry commented stubs ready
  for the cutover. See `docs/retired-mail-quadlets.md`.
- **Real secrets** — never. `.chezmoiignore` excludes every
  `.config/sodimo/*.env` and `.config/containers/systemd/*.env`; the box
  carries the only canonical copy at mode 0600. `vault-fetch` (#25) is the
  helper that materializes live env from Vaultwarden.

## Usage

On a fresh harness (after `sodimo/harness` bootc install):

```bash
chezmoi init --apply https://github.com/sodimo/dotfiles.git
systemctl --user daemon-reload
systemctl --user enable --now sodimo.target
```

## Development

Edit the source tree, re-render locally, verify:

```bash
chezmoi diff         # preview what would change on the target host
chezmoi apply -n     # dry-run
podman quadlet -dryrun -user ~/.config/containers/systemd/  # validate quadlets parse
```

## Upgrade loop

Every change to a quadlet, env file or Caddy route reaches a running harness
through the same four steps. Run them in order from any harness shell with
`chezmoi` pointed at the repo.

1. **Bump the tag.** Cut a new calver tag on `main` (`YYYY-MM-DD-dotfiles`).
   Release-please handles the `CHANGELOG.md` update; the tag is what
   `chezmoi update` pulls against.

2. **Render.** `chezmoi apply` writes the new sources to the live locations
   under `~/.config/` — `dot_*` becomes `.*`. Env files in the source tree
   are SHAPE-only (CHANGEME-* placeholders) and `.chezmoiignore` excludes
   them; the live copies on the box (mode 0600) are populated by
   `vault-fetch <service>` (#25) from Vaultwarden.

3. **Daemon-reload.** `systemctl --user daemon-reload` tells systemd to
   re-read the generated unit files that Quadlet produced from the new
   `.container` / `.volume` / `.network` sources.

4. **Restart the touched unit.** `systemctl --user restart <unit>.service`
   — for example `systemctl --user restart openwebui.service`. The whole
   stack does not need to bounce; only the units whose source changed.

```bash
# One-shot upgrade for a single service
chezmoi update                               # 1 + 2
systemctl --user daemon-reload               # 3
systemctl --user restart paperclip.service   # 4
```

**Rollback.** Revert the offending commit, re-apply, restart:

```bash
git -C ~/.local/share/chezmoi revert <SHA>   # against the local chezmoi source dir
chezmoi apply
systemctl --user daemon-reload
systemctl --user restart paperclip.service
```

Per-quadlet specifics (ports, env keys, known gotchas) live in
[changelog.sodimo.eu ch38 Quadlet reference](https://changelog.sodimo.eu/manual/38-quadlet-reference/).
OS-layer equivalent (image-based `bootc switch` / `bootc rollback`) lives
in [`sodimo/harness`](https://github.com/sodimo/harness).

## Releases

Calver tags: `YYYY-MM-DD-dotfiles`. See [`CHANGELOG.md`](CHANGELOG.md).
