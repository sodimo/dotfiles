# Runbook: re-sync llama-swap against kyuz0/amd-strix-halo-toolboxes

Use this when kyuz0 publishes a new stable config, a new backend image,
or a new kernel/firmware baseline. The goal is to reconcile our
`llama-swap.yaml` flag set with whatever is current upstream, while
explicitly deciding what to adopt and what to defer.

Reference: `docs/kyuz0-toolbox.md` explains *why* each flag exists. This
doc is just mechanics.

## Prerequisites

- You're on a workstation (not the harness) with git + podman.
- You have write access to `~/sodimo-dev/dotfiles` on this branch.
- You know the kyuz0 commit SHA currently pinned (see top of
  `docs/kyuz0-toolbox.md`).

## Steps

### 1. Pull or clone kyuz0 into a scratch dir

```sh
if [ -d /tmp/kyuz0-toolbox ]; then
  git -C /tmp/kyuz0-toolbox pull --ff-only
else
  git clone https://github.com/kyuz0/amd-strix-halo-toolboxes /tmp/kyuz0-toolbox
fi
```

Never commit `/tmp/kyuz0-toolbox` into `sodimo-dev/`; it's scratch-only.

### 2. See what changed since the last sync

```sh
git -C /tmp/kyuz0-toolbox log -10 --oneline
git -C /tmp/kyuz0-toolbox log \
  "$(grep -oE '`[0-9a-f]{40}`' ~/sodimo-dev/dotfiles/docs/kyuz0-toolbox.md | head -1 | tr -d '`')..HEAD" \
  --oneline -- docs/models.ini.example toolboxes/ README.md docs/troubleshooting-firmware.md
```

That second command shows only commits that touched the files we care
about. If nothing prints, nothing meaningful changed; bump the SHA in
`docs/kyuz0-toolbox.md` and stop.

### 3. Diff the canonical flag source

```sh
diff -u \
  <(git -C /tmp/kyuz0-toolbox show HEAD:docs/models.ini.example) \
  <(git -C /tmp/kyuz0-toolbox show "$LAST_SYNCED_SHA":docs/models.ini.example)
```

Where `$LAST_SYNCED_SHA` is the SHA from `docs/kyuz0-toolbox.md`. Pay
attention to:

- Changes inside the `[*]` global stanza — those apply to every `cmd:`
  block in our `llama-swap.yaml`.
- The `[gpt-oss-120b]` stanza specifically (our `local-heavy` alias).
- New MANDATORY flags (kyuz0 calls these out in README §4).

### 4. Inspect Dockerfile variants for backend changes

```sh
ls /tmp/kyuz0-toolbox/toolboxes/
git -C /tmp/kyuz0-toolbox show HEAD:toolboxes/Dockerfile.vulkan-amdvlk | head -40
git -C /tmp/kyuz0-toolbox show HEAD:toolboxes/Dockerfile.vulkan-radv | head -40
```

Watch for:
- New AMDVLK RPM version (currently `amdvlk-2025.Q2.1`).
- llama.cpp branch/pin changes.
- New `--build-arg` defaults.

If kyuz0 ships a materially newer Vulkan backend, consider whether our
reliance on `ghcr.io/mostlygeek/llama-swap:vulkan` needs to be revisited
— see "Why we keep mostlygeek" in `docs/kyuz0-toolbox.md`.

### 5. Host baseline deltas

```sh
git -C /tmp/kyuz0-toolbox show HEAD:README.md | sed -n '/Stable Configuration/,/## /p'
git -C /tmp/kyuz0-toolbox show HEAD:docs/troubleshooting-firmware.md | head -60
```

Check for:
- New kernel pin (currently `6.18.6-200`).
- New linux-firmware pin (currently `20260110`).
- New firmware blocklist entries (currently `linux-firmware-20251125`).
- New kernel cmdline parameters.

Anything here belongs in a ticket against `sodimo/harness`, not this repo.

### 6. Update `llama-swap.yaml` flags

For each change adopted in step 3:

- Add/remove/modify the corresponding `--flag` on **every** `cmd:` block
  in `home/dot_config/containers/systemd/llama-swap.yaml`. Do not rely
  on a default — llama.cpp upstream changes defaults periodically, and
  an explicit flag is immune to that.
- If a flag was added per-model (e.g. `chat-template-kwargs` for a new
  reasoning model), add it only to the matching model.

### 7. Dry-run the quadlet

```sh
QUADLET_UNIT_DIRS=$HOME/sodimo-dev/dotfiles/home/dot_config/containers/systemd \
  /usr/libexec/podman/quadlet -user -dryrun 2>&1 | tee /tmp/quadlet-dryrun.log
echo "exit=$?"
```

Expect exit 0 and no parse errors. `(c)`-class advisory messages
(short-name warnings, architectural notes) are acceptable. Fix parse
errors before going further.

### 8. Smoke test

Run the end-to-end smoke test on the harness:
- Start `llama-swap.service` + `litellm.service`.
- `curl http://127.0.0.1:9292/v1/models` — expect the four aliases.
- `curl -X POST http://127.0.0.1:9292/v1/chat/completions \
   -H 'Content-Type: application/json' \
   -d '{"model":"local-heavy","messages":[{"role":"user","content":"hi"}]}'`
  — expect a response from gpt-oss-120b.
- Watch `journalctl --user -u llama-swap` for DCHECK/FATAL/segfault.

If a dedicated smoke-test doc ever lands at `docs/smoke-test.md`, point
there instead. For now, see Wednesday's writeup on the harness.

### 9. Update the pinned SHA

```sh
NEW_SHA=$(git -C /tmp/kyuz0-toolbox rev-parse HEAD)
echo "new kyuz0 SHA: $NEW_SHA"
```

Edit `docs/kyuz0-toolbox.md` — update:
- "Commit SHA at sync"
- "Sync date"

Commit with a message like `chore(llama-swap): resync kyuz0 → <short-sha>`.

### 10. Open questions to verify each sync

- Is the harness OS still a release ahead of kyuz0's stable band?
  (F44 vs. F42/F43 at time of writing.) If yes, validate smoke test
  still green; if no, remove the note from `docs/kyuz0-toolbox.md`.
- Has a hosted image gained an AMDVLK ICD? If yes, reconsider the RADV-
  everywhere posture for `local-heavy`.
- Has kyuz0 added/changed the MANDATORY flag list in their README §4?
