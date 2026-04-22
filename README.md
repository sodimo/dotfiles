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

## Releases

Calver tags: `YYYY-MM-DD-dotfiles`. See [`CHANGELOG.md`](CHANGELOG.md).
