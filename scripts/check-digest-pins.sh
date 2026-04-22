#!/usr/bin/env bash
# check-digest-pins.sh — fail if any quadlet Image= pin is missing a
# @sha256:... digest. Enforces D-167.
#
# Two explicit allow-list entries:
#   cockpit.container      — D-167 explicit exemption (slow cadence, strong compat)
#   paperclip.container    — tracks sodimo/dotfiles#12 (ghcr.io/sodimo org
#                            write:packages not yet granted; digest pin
#                            arrives with the first published image)
#
# Usage:  scripts/check-digest-pins.sh [SYSTEMD_DIR]
# Default SYSTEMD_DIR is home/dot_config/containers/systemd relative to repo root.

set -euo pipefail

systemd_dir="${1:-home/dot_config/containers/systemd}"

if [[ ! -d "$systemd_dir" ]]; then
  printf >&2 'check-digest-pins: directory not found: %s\n' "$systemd_dir"
  exit 2
fi

allow_list=(
  cockpit.container
  paperclip.container
)

fail=0
while IFS= read -r -d '' unit; do
  base="$(basename "$unit")"
  for allowed in "${allow_list[@]}"; do
    if [[ "$base" == "$allowed" ]]; then
      continue 2
    fi
  done

  # Extract the Image= line (ignore commented lines).
  image_line="$(grep -E '^Image=' "$unit" || true)"
  [[ -z "$image_line" ]] && continue

  if [[ "$image_line" != *"@sha256:"* ]]; then
    printf '%s: missing @sha256: digest pin\n  %s\n' "$unit" "$image_line"
    fail=1
  fi
done < <(find "$systemd_dir" -maxdepth 1 -name '*.container' -print0)

if [[ "$fail" -ne 0 ]]; then
  printf >&2 '\ncheck-digest-pins: one or more quadlets violate D-167.\n'
  printf >&2 'Resolve the current digest with:\n'
  printf >&2 '  skopeo inspect --format '\''{{.Digest}}'\'' docker://<registry>/<image>:<tag>\n'
  printf >&2 'and append it to the Image= line as `Image=<ref>@sha256:<hex>`.\n'
  exit 1
fi

echo "check-digest-pins: all $(find "$systemd_dir" -maxdepth 1 -name '*.container' | wc -l) .container units pass (allow-list: ${allow_list[*]})"
