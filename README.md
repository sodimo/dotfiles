# dotfiles

> Chezmoi-managed `home/` for the Sodimo Framework Desktop harness — quadlets, Caddyfile, shell config, operator skills.

See [`REPO.md`](REPO.md) for architecture metadata (chapter, audience, dependencies).

## Status

Chapter 1 — [changelog.sodimo.eu](https://changelog.sodimo.eu) · see the `35a-…` quadlet reference chapters.

## Layout

```
home/
├── .chezmoi.yaml.tmpl          # data model (user, network, secrets)
├── .chezmoiignore
├── dot_bashrc                  # shell baseline
├── dot_gitconfig.tmpl          # git identity
└── dot_config/
    ├── caddy/                  # Caddyfile + per-service HTTP routes
    ├── cloudflared/            # single tunnel config, credentials via chezmoi secret
    ├── containers/systemd/     # podman Quadlet definitions
    │   ├── sodimo.network      # 10.89.0.0/24 shared bridge
    │   ├── caddy.container
    │   ├── cockpit.container
    │   ├── openwebui{,-db,-redis}.container + openwebui.env
    │   ├── litellm{,-postgres,-redis}.container + litellm.yaml
    │   ├── llama-swap.container + config.yml
    │   ├── twenty{,-worker,-db,-redis}.container + twenty.env
    │   ├── vaultwarden.container + vaultwarden.env
    │   ├── postfix.container + main.cf + master.cf
    │   ├── dovecot.container + dovecot.conf
    │   ├── rspamd.container
    │   ├── piler.container
    │   ├── sodiwin-etl.timer + sodiwin-etl.service
    │   └── sodimo-email-drain.service
    └── systemd/user/
        └── sodimo.target       # grouping target for the whole stack

skills/                         # operator skills (git-history-mgmt, remote-connection, ...)
```

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
   under `~/.config/` — `*.env.tmpl` becomes `*.env`, `dot_*` becomes `.*`,
   secrets are decrypted.

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
