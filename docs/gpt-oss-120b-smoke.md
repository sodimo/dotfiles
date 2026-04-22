# gpt-oss-120b Strix Halo smoke test — 2026-04-22 overnight

End-to-end runtime validation of the `local-heavy` alias
(`unsloth/gpt-oss-120b-GGUF`, `UD-Q8_K_XL` quant, 2-shard) on an
AMD Strix Halo (Framework Desktop-class) dev box. Companion to the
Wednesday-evening qwen3-4b pass (53 tok/s RADV Vulkan, same hardware).

## Why this file exists

The Wednesday smoke-test [report][wed-report] deferred `local-heavy`
runtime validation on two blockers:

1. The 60 GiB UD-Q8_K_XL GGUF was never downloaded.
2. The dev-box kernel cmdline was not kyuz0-tuned (filed as
   [sodimo/harness#11][h11]).

This document carries the test to the finish line, records the measured
numbers, and captures every gap between the ideal (kyuz0 kernel, 65k
ctx, AMDVLK) and what actually ran.

[wed-report]: ../../sodimo/secondweek/wednesday/wednesday-evening-report.md
[h11]: https://github.com/sodimo/harness/issues/11

## Environment

| Facet | Value |
| -- | -- |
| Host OS | Fedora 44 (bootc target: sodimo/harness F44) |
| Kernel | 6.19.13-300.fc44.x86_64 |
| Hardware | Strix Halo class, 128 GB unified memory, nvme0n1 929 GB |
| GPU | Radeon 8060S Graphics (RADV STRIX_HALO), gfx1151, Mesa 26.0.4 |
| Vulkan | 1.4.341, `DRIVER_ID_MESA_RADV`, driverVersion 26.0.4 |
| Podman | 5.8.2, rootless (uid 1000) |
| llama-swap image | `ghcr.io/mostlygeek/llama-swap:vulkan@sha256:820e40ec…` |
| llama-server | bundled in the image (no ramalama wrapper) |
| Date (CET) | 2026-04-22 overnight session |

### Kernel cmdline — running vs kyuz0 requirement

**Running:**

```
amd_iommu=off ttm.pages_limit=33554432 ttm.page_pool_size=33554432
```

**kyuz0 wants (per `docs/kyuz0-toolbox.md` / [harness#11][h11]):**

```
iommu=pt amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

**Delta:**

| Parameter | Running | Required | Delta |
| -- | -- | -- | -- |
| `iommu=*` | `amd_iommu=off` (fully off) | `iommu=pt` (pass-through) | Off vs pass-through; functionally similar for iGPU DMA |
| `amdgpu.gttsize` | absent | `126976` (124 GiB) | **Missing** — iGPU GTT window may be well below 124 GiB |
| `ttm.pages_limit` | `33554432` (128 GiB) | `32505856` (124 GiB) | Higher than required — harmless |
| `ttm.page_pool_size` | `33554432` | not specified | Harmless |

**Mitigation used for this pass:** dropped `gpt-oss-120b` context size
from 65536 → **16384** tokens in the test `llama-swap.yaml`. KV cache at
q8_0 with 16k ctx is small enough to fit even if GTT is capped at the
default. A post-reboot pass on a kyuz0-tuned kernel is required before
flipping `local-heavy` to the full 65k ctx in production.

## Model acquisition

**Target:** `unsloth/gpt-oss-120b-GGUF`, quant `UD-Q8_K_XL`, 2-shard
GGUF (`00001-of-00002.gguf` + `00002-of-00002.gguf`).

**Exact sizes from HF HEAD:**

| Shard | Bytes | ≈ GiB |
| -- | -- | -- |
| `gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf` | 49,532,512,480 | 46.13 |
| `gpt-oss-120b-UD-Q8_K_XL-00002-of-00002.gguf` | 14,940,710,240 | 13.92 |
| **Total** | **64,473,222,720** | **60.05** |

(The brief's "100 GB" estimate was conservative — actual is ~60 GiB.)

**Local path:** `~/.local/share/llama-models/gpt-oss-120b/UD-Q8_K_XL/`
(matches the `Volume=%h/.local/share/llama-models:/models:ro` mount in
`llama-swap.container`).

**Finding: `hf download` (xet backend) resume is unreliable.** First
attempt used `hf download unsloth/gpt-oss-120b-GGUF --include
"UD-Q8_K_XL/*.gguf"`. The xet-chunked `.incomplete` files in
`.cache/huggingface/download/UD-Q8_K_XL/` progressed to ~10 GiB before
the controlling shell was terminated during a session pause. A second
`hf download` invocation **discarded** the 10 GiB of xet chunks and
started from scratch, losing all progress. The filenames (content
hashes) were identical between runs, but the backend chose to re-fetch.

**Mitigation:** switched to `wget -c` against the HF `resolve/main/`
URLs directly. Those 302-redirect to `cas-bridge.xethub.hf.co` signed
URLs, which honor HTTP Range and resume cleanly. Full command:

```
cd ~/.local/share/llama-models/gpt-oss-120b/UD-Q8_K_XL
nohup bash -c '
  wget -c --show-progress \
    "https://huggingface.co/unsloth/gpt-oss-120b-GGUF/resolve/main/UD-Q8_K_XL/gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf" \
    "https://huggingface.co/unsloth/gpt-oss-120b-GGUF/resolve/main/UD-Q8_K_XL/gpt-oss-120b-UD-Q8_K_XL-00002-of-00002.gguf"
' > /tmp/wget-gpt-oss-120b.log 2>&1 &
disown
```

Throughput observed: ~25–36 MB/s sustained. Total download elapsed:
**~30 minutes** (start ~22:45 CEST, finish ~23:15 CEST; shard 2 done first
at ~22:56 in ~11 min, shard 1 finished at ~23:14 after another ~18 min).

Final on-disk verification:

```
$ ls -la ~/.local/share/llama-models/gpt-oss-120b/UD-Q8_K_XL/
-rw-r--r-- 1 tom tom 49532512480 Apr 22 23:14 gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf
-rw-r--r-- 1 tom tom 14940710240 Apr 22 22:56 gpt-oss-120b-UD-Q8_K_XL-00002-of-00002.gguf

$ du -b .../*.gguf | awk '{s+=$1} END{print s}'
64473222720   # exact match vs HF combined Content-Length
```

Byte-for-byte match on both shards (delta = 0 vs HF `Content-Length`).

In the container, the volume mount is visible at
`/models/gpt-oss-120b/UD-Q8_K_XL/` (checked via `podman exec
sodimo-gpt120-llama-swap ls -la /models/gpt-oss-120b/UD-Q8_K_XL/`).

## Stack bring-up

Same `podman run` topology as the Wednesday smoke, on a dedicated test
network `sodimo-gpt120-test` at `172.32.0.0/24` (to avoid colliding
with other overnight agents using `sodimo.network` or
`sodimo-test`).

| Container | Image (sha) | IP | Host port |
| -- | -- | -- | -- |
| sodimo-gpt120-litellm-db | pgvector/pgvector:pg16@sha256:7d400e34… | 172.32.0.11 | — |
| sodimo-gpt120-litellm-redis | redis:7-alpine@sha256:7aec734b… | 172.32.0.12 | — |
| sodimo-gpt120-openwebui-db | pgvector/pgvector:pg16@sha256:7d400e34… | 172.32.0.13 | — |
| sodimo-gpt120-openwebui-redis | redis:7-alpine@sha256:7aec734b… | 172.32.0.14 | — |
| sodimo-gpt120-llama-swap | mostlygeek/llama-swap:vulkan@sha256:820e40ec… | 172.32.0.20 | 127.0.0.1:19292 → 8080 |
| sodimo-gpt120-litellm | berriai/litellm:main-stable@sha256:9e1536c6… | 172.32.0.21 | 127.0.0.1:14000 → 4000 |
| sodimo-gpt120-openwebui | open-webui:main@sha256:1e834205… | 172.32.0.22 | 127.0.0.1:13000 → 8080 |
| sodimo-gpt120-caddy | caddy:2-alpine@sha256:83446812… | 172.32.0.23 | 127.0.0.1:18080 → 80 |

### DNS fix for the test network

The production quadlets use hostnames like `litellm-postgres`,
`openwebui-db`, `llama-swap` — which podman resolves via its DNS server
only when the *container name* matches. In the test run those names
don't match the container names (`sodimo-gpt120-litellm-db` etc.), so
`--add-host <short-name>:<static-ip>` was set on each consumer pair.

### Test `llama-swap.yaml` diff from prod

- `ctx-size: 65536 → 16384` for the `gpt-oss-120b` entry (kernel-cmdline
  mitigation).
- `-m /models/gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf`
  → `-m /models/gpt-oss-120b/UD-Q8_K_XL/gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf`
  (prod will either put shards directly at `/models/` or keep the
  subdir — this is an open question for the production rsync path and
  is tracked in the open-issues section below).

### Pre-load HTTP reachability

| URL | Verdict |
| -- | -- |
| `GET http://127.0.0.1:19292/v1/models` (llama-swap) | 4 aliases listed (qwen3-4b, gpt-oss-120b, qwen3-30b, qwen3-embedding) ✓ |
| `GET http://127.0.0.1:14000/v1/models` (LiteLLM, `sk-test-sodimo-gpt120-master`) | 6 models listed incl. `local-heavy` ✓ |
| `GET http://127.0.0.1:13000/health` (OpenWebUI) | 200 in 3 ms ✓ |
| `GET http://127.0.0.1:18080/` (Caddy → OpenWebUI) | 200 in 19 ms ✓ |

Stack-up elapsed (postgres+redis+llama-swap+litellm+openwebui+caddy):
**~3 minutes** (dominated by LiteLLM's Prisma migrations at cold start,
~1 min on its own).

## gpt-oss-120b test run

Three sequential `POST /v1/chat/completions` requests against LiteLLM
(`model: local-heavy`, `Authorization: Bearer sk-test-sodimo-gpt120-master`),
which hops through `litellm → llama-swap → llama-server` (all
intra-podman, on `sodimo-gpt120-test`). The first request triggered
model load (swap.exclusive=true, group=heavy); requests 2 and 3
re-used the loaded model (served by llama-server directly, no reload).

| # | Prompt (summary) | max_tokens | Intent |
| -- | -- | -- | -- |
| 1 | 50-word summary of Sodimo (Levantine distributor) | 200 | Cold — full model-load included |
| 2 | "Name three common mezze dishes." | 120 | Warm — model cache, small prompt |
| 3 | ~450-token prompt on importing Levantine food to France | 500 | Steady-state — exercises decode at length |

All three returned `HTTP 200` (cross-checked on LiteLLM side and
llama-swap `POST /v1/chat/completions` access log). Responses were
coherent English at `reasoning_effort=high` — llama-server emitted
`reasoning_content` (chain-of-thought) in addition to the user-visible
content, matching the harmony-format behaviour documented by unsloth
for gpt-oss-120b.

llama-swap access log (the wall-clock numbers below match llama-swap's
own per-request duration):

```
[INFO] <gpt-oss-120b> Health check passed on http://127.0.0.1:8002/health
[INFO] Request 172.32.0.21 POST /v1/chat/completions 200 1711 30.343308394s  # cold
[INFO] Request 172.32.0.21 POST /v1/chat/completions 200 1237  2.710519758s  # warm
[INFO] Request 172.32.0.21 POST /v1/chat/completions 200 3252 11.226327817s  # steady
```

### Measured numbers

llama-server ships timing fields inside each response body
(`timings.prompt_per_second`, `timings.predicted_per_second`,
`timings.predicted_ms`). These are the ground truth; the `curl
time_total` numbers agree within ~50 ms and include
LiteLLM + JSON marshalling overhead.

| Metric | Value |
| -- | -- |
| Cold wall-clock (first request: load + generate 200 tok) | **30.51 s** (curl), **30.34 s** (llama-swap access log) |
| Cold model-load duration (derived = 30.34 s − 4.30 s decode − 0.76 s prompt) | **~25 s** |
| Cold steady-state decode (200 tok / 4.298 s) | **46.5 tok/s** |
| Cold prompt eval (86 prompt tok / 764 ms) | 112.4 tok/s |
| Warm wall-clock (request 2: 120 tok, prompt cache hit) | **2.73 s** |
| Warm decode (120 tok / 2.56 s) | ~46.9 tok/s |
| Steady-state wall-clock (request 3: 500 tok, longer prompt) | **11.24 s** |
| Steady-state decode (500 tok / 10.726 s from llama-server) | **46.6 tok/s** |
| Steady-state prompt eval (91 tok / 487 ms) | 186.6 tok/s |
| Peak iGPU VRAM (`drm-total-vram` via fdinfo on `renderD128`) | **59.8 GiB** (62,681,024 KiB) |
| Peak GTT allocation (`drm-memory-gtt`) | **60.8 GiB** (63,729,628 KiB) |
| llama-server host RSS (CPU-side; weights live in GTT) | 311 MiB |
| Host `MemAvailable` drop during load | 111 GiB → 49 GiB (~62 GiB consumed) |
| Ctx size used | 16,384 (reduced from 65,536 per kernel gating) |
| Quant | UD-Q8_K_XL (unsloth) |
| Driver | RADV Vulkan (Mesa 26.0.4) |
| Date | 2026-04-22 overnight (test fired 23:15 CEST) |

The `local-task` (qwen3-4b) Wednesday reference was **53 tok/s**. At
~46.6 tok/s for a **30× larger** model, `local-heavy` clears the
"tolerably fast reasoning tier" bar on this hardware — response to a
500-token answer lands in under 12 s.

### Kyuz0 flag verification (`podman exec … ps -eo command`)

Exact cmdline of the spawned `llama-server` (PID 168 inside the
container, host PID 2,060,187), captured **during inference**:

```
/app/llama-server \
  --host 0.0.0.0 \
  --port 8002 \
  -m /models/gpt-oss-120b/UD-Q8_K_XL/gpt-oss-120b-UD-Q8_K_XL-00001-of-00002.gguf \
  --ctx-size 16384 \
  --temp 0.8 \
  --min-p 0.05 \
  --chat-template-kwargs {"reasoning_effort":"high"} \
  -ngl 999 \
  --no-mmap \
  -fa on \
  --batch-size 4096 \
  --ubatch-size 512 \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --jinja \
  --direct-io \
  --cache-prompt \
  --cache-reuse 256 \
  --threads 12
```

Every mandatory kyuz0 flag is present verbatim: `-ngl 999`,
`--no-mmap`, `-fa on`, `--batch-size 4096 --ubatch-size 512`,
`--cache-type-k q8_0 --cache-type-v q8_0`, `--jinja`,
`--direct-io`, `--cache-prompt --cache-reuse 256`, `--threads 12`.
gpt-oss-120b-specific: `--temp 0.8 --min-p 0.05`,
`--chat-template-kwargs {"reasoning_effort":"high"}`.

### GPU memory accounting (fdinfo on `/dev/dri/renderD128`)

```
drm-total-vram:  62,681,024 KiB  (~59.8 GiB — weights + activation buffers)
drm-total-gtt:    1,190,012 KiB  (~1.14 GiB — small staging)
drm-memory-gtt:  63,729,628 KiB  (~60.8 GiB — actual resident)
drm-engine-compute:       19.2 s (accumulated across the 3 requests)
drm-engine-gfx:            1.08 s
```

On Strix Halo's unified-memory architecture, "VRAM" as reported by the
kernel is the reserved iGPU view into the GTT window; the 62.7 GB
figure matches model weights (~60 GiB) + the q8_0 KV cache for 16k ctx
(small at this quant).

## Verdict

**PASS.**

- GGUFs downloaded byte-exact, visible to the container, loaded without
  error.
- All 3 latency tiers (cold, warm, steady-state) completed with
  `HTTP 200` and coherent outputs.
- Steady-state **46.6 tok/s** at UD-Q8_K_XL, 16k ctx, RADV Vulkan.
- Every mandatory kyuz0 flag was present on the actual spawned
  `llama-server` process.
- No OOM, no swap hit (swap used steady at 516 MB, pre-test baseline),
  no `Killed` in container logs, no errors in llama-swap log.
- The kernel cmdline delta (`amd_iommu=off` in place of `iommu=pt`,
  absent `amdgpu.gttsize=126976`) did **not** cap GTT below the 60 GiB
  needed for this run. `amd_iommu=off` on AMD effectively disables
  IOMMU translation (equivalent to pass-through for this iGPU DMA
  case), and default `amdgpu` GTT sizing on a 128 GiB box is already
  large enough for a ~60 GiB model at 16k ctx. The kyuz0 `gttsize`
  parameter becomes load-bearing only at 65k ctx where the KV cache
  alone needs another ~20–30 GiB.

## Open issues / next steps

1. **Re-run at 65k ctx on a kyuz0-tuned kernel.** Once [harness#11][h11]
   is deployed in the real harness (`iommu=pt
   amdgpu.gttsize=126976 ttm.pages_limit=32505856`), restore
   `--ctx-size 65536` in `llama-swap.yaml` and re-measure. The 16k-ctx
   numbers in this doc are a lower bound on capability.
2. **Port decision for the shard path.** Production harness rsyncs
   GGUFs into `~/.local/share/llama-models/`. This smoke placed them
   under `gpt-oss-120b/UD-Q8_K_XL/<shard>.gguf`. The prod
   `llama-swap.yaml` currently points at `/models/<shard>.gguf` (flat).
   Options: (a) flatten shards at rsync time; (b) update the prod yaml
   to match the subdir layout. Neither is load-bearing for this smoke;
   resolved when the real harness first syncs models.
3. **AMDVLK revisit.** RADV was the only ICD present in the
   mostlygeek image; kyuz0 recommends AMDVLK for long-context /
   prompt-heavy workloads. Deferred — see [kyuz0-toolbox.md][kxt] and
   [sodimo/dotfiles#14][d14].
4. **`hf download` resume gotcha.** Document in the operator runbook
   (`resync-runbook.md` or a new `model-download.md`) that `hf download`
   using the xet backend should not be SIGTERM'd mid-run; prefer
   `wget -c` or `aria2c -c` against the direct `resolve/main/` URLs for
   reliability.

[kxt]: kyuz0-toolbox.md
[d14]: https://github.com/sodimo/dotfiles/issues/14

## Cross-references

- [kyuz0-toolbox.md](kyuz0-toolbox.md) — interpolation map + flag rationale.
- [resync-runbook.md](resync-runbook.md) — procedure for re-syncing kyuz0
  upstream changes into `llama-swap.yaml`.
- Wednesday's evening report (`sodimo/secondweek/wednesday/wednesday-evening-report.md`)
  — sections 3 (kyuz0-integrator) and 4 (AI smoke).
- [harness#11](https://github.com/sodimo/harness/issues/11) — kernel
  cmdline requirement.
- [dotfiles#14](https://github.com/sodimo/dotfiles/issues/14) — ramalama
  vestige investigation / AMDVLK toolbox-native future.
