# kyuz0/amd-strix-halo-toolboxes as a reference dependency

## What kyuz0 is

[kyuz0/amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)
is a community-maintained set of pre-built container images and
documentation for running `llama.cpp` on AMD Ryzen AI Max "Strix Halo"
iGPUs (gfx1151). It tracks Llama.cpp master, maintains working Dockerfiles
for Vulkan (RADV / AMDVLK) and ROCm (6.4.4 / 7.2.1 / 7-nightlies) on the
exact silicon we ship on — Framework Desktop, Ryzen AI MAX+ 395, 128 GB
unified memory — and publishes benchmark results plus the current known-
good kernel / firmware combos.

**We depend on kyuz0 as a reference, not as a runtime.** The Sodimo stack
keeps the llama-swap gateway on `ghcr.io/mostlygeek/llama-swap:vulkan`
(see "Why we don't run kyuz0 toolboxes directly" below). Kyuz0 is the
authoritative source for llama-server invocation flags, kernel boot
parameters, firmware pins, and backend-selection heuristics — those
inputs are copied (not pulled) into our configs.

## Snapshot state

| Field                 | Value                                                            |
| --------------------- | ---------------------------------------------------------------- |
| Upstream repo         | github.com/kyuz0/amd-strix-halo-toolboxes                        |
| Commit SHA at sync    | `1421e8706020e8d7e797f71b9f28cd3072e7f868`                        |
| Sync date             | 2026-04-22                                                       |
| Source file (flags)   | `docs/models.ini.example`                                        |
| Source file (host)    | `README.md` §"Host Configuration" + `docs/troubleshooting-firmware.md` |

Bump all three rows together when re-syncing; see `resync-runbook.md`.

## Interpolation map — kyuz0 → our llama-swap.yaml

Kyuz0 expresses model presets as `models.ini` sections consumed by
`llama-server --models-preset`. We don't use preset mode (llama-swap
spawns one `llama-server` per `cmd:` block), so the `[*]` global defaults
and per-model overrides were inlined as explicit CLI flags on every
model entry in `llama-swap.yaml`.

### Global `[*]` defaults → per-cmd flags

Every `cmd:` in `llama-swap.yaml` carries the following, sourced from the
`[*]` stanza of `docs/models.ini.example`:

| kyuz0 ini key       | our CLI flag                   | Why                                     |
| ------------------- | ------------------------------ | --------------------------------------- |
| `threads = 12`      | `--threads 12`                 | CCD/core budget for Strix Halo          |
| `flash-attn = on`   | `-fa on`                       | kyuz0 tags as MANDATORY on gfx1151      |
| `mmap = off`        | `--no-mmap`                    | kyuz0 tags as MANDATORY (crash avoidance) |
| `batch-size = 4096` | `--batch-size 4096`            | prompt-processing throughput            |
| `ubatch-size = 512` | `--ubatch-size 512`            | memory/throughput balance on iGPU       |
| `cache-type-k = q8_0` | `--cache-type-k q8_0`        | KV cache memory footprint               |
| `cache-type-v = q8_0` | `--cache-type-v q8_0`        | KV cache memory footprint               |
| `jinja = true`      | `--jinja`                      | enables modern chat-template features   |
| `direct-io = on`    | `--direct-io`                  | skip page-cache double-buffering        |
| `cache-prompt = true` | `--cache-prompt`             | server-side prompt cache                |
| `cache-reuse = 256` | `--cache-reuse 256`            | min KV-shift chunk size                 |
| (implicit)          | `-ngl 999`                     | kyuz0 sets `n-gpu-layers = 999` per model |

Keys in kyuz0's `[*]` that we did **not** port:
- `mlock = off` — llama-server default, redundant.
- `fit = off` — llama-server default.
- `warmup = off` — llama-server default.
- `cache-ram = 32768` — experimental; not load-bearing for our models.

### Per-model overrides

#### `gpt-oss-120b` — from kyuz0 `[gpt-oss-120b]` stanza

| kyuz0 ini key                              | our CLI flag                                     |
| ------------------------------------------ | ------------------------------------------------ |
| `model = /path/.../gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf` | `-m /models/gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf` |
| `alias = gpt-120b`                         | `aliases: [gpt-oss-120b, local-heavy]` (our naming) |
| `ctx-size = 65536`                         | `--ctx-size 65536`                               |
| `temp = 0.8`                               | `--temp 0.8`                                     |
| `min-p = 0.05`                             | `--min-p 0.05`                                   |
| `chat-template-kwargs = {"reasoning_effort": "high"}` | `--chat-template-kwargs {"reasoning_effort":"high"}` |

Note: the UD-Q8_K_XL quant is sharded into two GGUF files. llama-server
follows the shard chain automatically when given shard 1; both files
must be present on disk at the same prefix.

## Mandatory host configuration (Framework Desktop / Strix Halo)

These are OS-level requirements — they don't live in this repo, they
live on the harness. They're documented here because every operator
touching llama-swap should know they exist.

### Kernel cmdline (boot parameters)

```
iommu=pt amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

| Parameter                  | Purpose                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| `iommu=pt`                 | IOMMU pass-through; reduces iGPU unified-memory overhead         |
| `amdgpu.gttsize=126976`    | Cap iGPU unified memory at 124 GiB (126976 MiB)                  |
| `ttm.pages_limit=32505856` | Cap pinned memory at 124 GiB (32505856 × 4 KiB pages)            |

Without these, the iGPU cannot address the full 128 GB pool and large
models (gpt-oss-120b at Q8_K_XL is >120 GB with context) will OOM.

### Stable baseline per kyuz0

Kyuz0 validates against:

- **OS**: Fedora 42 or 43
- **Kernel**: 6.18.6-200
- **linux-firmware**: 20260110 (strictly avoid `20251125` — breaks ROCm; harmless on Vulkan but worth knowing)

Sodimo's `sodimo/harness` bootc image is built on **Fedora 44**. This is
**one release ahead of kyuz0's validated band**. Open question flagged to
the team: confirm gfx1151 / Vulkan behavior is unchanged on F44, or pin
harness back to F43 if regressions show up in smoke testing. Track in
the smoke-test writeup for Wednesday.

## Backend selection (RADV / AMDVLK / ROCm)

| Backend | When to use (per kyuz0)                                          | Our posture                                   |
| ------- | ---------------------------------------------------------------- | --------------------------------------------- |
| **Vulkan / RADV**  | Most stable and compatible; recommended for most users and all models. | **Default for all models** in current config. |
| **Vulkan / AMDVLK** | Fastest backend for large-context / prompt-heavy loads. ≤2 GiB single-buffer allocation cap — some large models won't load. | **Aspirational** for gpt-oss-120b; see divergence below. |
| **ROCm 6.4.4**     | Latest stable 6.x; backported kernel 6.18.4+ patch.              | Not used. Kyuz0 flags ROCm as fragile on Strix Halo; we stay on Vulkan per Tom's direction. |
| **ROCm 7.2.1 / nightlies** | Latest 7.x. Had a perf regression (llvm#147700) — kyuz0 applies `-mllvm --amdgpu-unroll-threshold-local=600` as a workaround. | Not used (same rationale).                    |

## Why we keep mostlygeek/llama-swap:vulkan as the gateway

`llama-swap` is an OpenAI-compatible front-end that hot-swaps `llama-server`
instances by model name. That hot-swap logic, TTL-based unloading, group
exclusivity, and OpenAI `/v1` surface are exactly what LiteLLM expects to
talk to — kyuz0's toolboxes don't provide any of that (they ship raw
`llama-server` in interactive containers).

So the split is:

- **kyuz0** = reference for *what flags to pass to llama-server*.
- **mostlygeek/llama-swap:vulkan** = runtime that *spawns llama-server with those flags* and exposes `/v1/*`.

## Divergences from kyuz0 defaults (and why)

1. **No ramalama wrapper.** The previous llama-swap.yaml invoked models
   via `ramalama --runtime llama.cpp run` with `--vulkan-driver` and
   `hf://` URIs. `ghcr.io/mostlygeek/llama-swap:vulkan` ships
   `/app/llama-server` directly and does **not** contain `ramalama` —
   those commands would have failed at spawn time. Rewrite uses raw
   `llama-server` invocations with GGUF paths, which matches kyuz0's
   own examples in `docs/docker-compose-how-to.md` and README §4.

2. **Model files mounted at `/models`, not `~/.local/share/ramalama`.**
   The container mount moved from `%h/.local/share/ramalama:/root/.local/share/ramalama:ro`
   to `%h/.local/share/llama-models:/models:ro`. Raw llama-server expects
   a filesystem path, not a HuggingFace cache layout. Operators need to
   `hf download` (or rsync) GGUF files into `~/.local/share/llama-models/`
   on the harness.

3. **RADV for all models, including gpt-oss-120b.** Kyuz0 recommends
   AMDVLK for prompt-heavy / long-context workloads. The mostlygeek
   image ships only the Mesa RADV Vulkan ICD
   (`/usr/share/vulkan/icd.d/radeon_icd.json`) — AMDVLK is not present.
   Switching to AMDVLK would require either (a) a custom gateway image
   with `amdvlk-2025.Q2.1.rpm` installed, or (b) a different upstream
   tag. Deferred: revisit after the gpt-oss-120b smoke test — if RADV
   long-context perf is acceptable, keep RADV; otherwise build a
   custom llama-swap image with AMDVLK layered in (Dockerfile can be
   lifted from `toolboxes/Dockerfile.vulkan-amdvlk` in kyuz0's repo).

4. **`HSA_OVERRIDE_GFX_VERSION=11.0.0` left in place.** This env var
   targets ROCm/HSA; harmless on Vulkan but required if we ever flip a
   model to ROCm. `AddDevice=/dev/kfd` in the `.container` file is in
   the same category — unused by the Vulkan path, left for forward
   compatibility.

5. **Fedora 44 host vs. kyuz0's F42/F43 baseline.** See "Stable baseline"
   above. Flagged as open question.
