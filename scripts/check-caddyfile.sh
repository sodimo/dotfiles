#!/usr/bin/env bash
# check-caddyfile.sh — validate Caddyfile + every routes/*.caddy inside a
# caddy:2-alpine container (same image the quadlet runs in production).
#
# Runs `caddy validate` against the mounted tree. The Caddyfile uses an
# `import /etc/caddy/routes/*.caddy` directive, so we mount the whole
# home/dot_config/caddy dir at /etc/caddy to preserve path semantics.
#
# Usage:
#   scripts/check-caddyfile.sh              # validate home/dot_config/caddy
#   scripts/check-caddyfile.sh /some/dir    # validate some other caddy dir
#
# Exits:
#   0  valid
#   1  parse or semantic error
#   2  prerequisites missing (podman/docker)
#
# CI-friendly: uses podman if present, falls back to docker. Escape hatch
# for legitimately-broken-at-commit-time state: set SKIP_CADDY_VALIDATE=1.

set -euo pipefail

if [[ "${SKIP_CADDY_VALIDATE:-}" == "1" ]]; then
  echo "check-caddyfile: skipped (SKIP_CADDY_VALIDATE=1)"
  exit 0
fi

caddy_dir="${1:-home/dot_config/caddy}"

if [[ ! -f "$caddy_dir/Caddyfile" ]]; then
  printf >&2 'check-caddyfile: Caddyfile not found at %s/Caddyfile\n' "$caddy_dir"
  exit 2
fi

# Pick a container runtime (podman preferred, docker fallback).
if command -v podman >/dev/null 2>&1; then
  runtime=podman
elif command -v docker >/dev/null 2>&1; then
  runtime=docker
else
  printf >&2 'check-caddyfile: neither podman nor docker in PATH\n'
  exit 2
fi

image="docker.io/library/caddy:2-alpine"
abs_dir="$(cd "$caddy_dir" && pwd)"

# `--config /etc/caddy/Caddyfile` + the bind-mount at /etc/caddy keeps the
# `import /etc/caddy/routes/*.caddy` directive resolvable. Validation
# emits a stream of JSON log lines; the exit code carries the verdict.
"$runtime" run --rm \
  -v "$abs_dir:/etc/caddy:ro,Z" \
  "$image" \
  caddy validate --adapter caddyfile --config /etc/caddy/Caddyfile
