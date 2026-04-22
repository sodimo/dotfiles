# skills/

Operator skills carried into the Sodimo harness. These are reference
material loaded by Claude Code / Claude.ai when the operator is working
on the harness (e.g. rewriting a bad commit, cutting a release,
bootstrapping a new sodimo/* repo, SSHing in for break-glass).

Skills are **not applied to disk** by chezmoi — they live at the repo
root, outside `home/`, and are read directly from this source tree.

## Included

- `git-aicademy/` — OSS workflow: commit craft, release flow, repo
  bootstrap. Consumed when kicking off new sodimo/* repos or cutting
  a release with release-please.
- `git-history-mgmt/` — rewriting, undoing, assessing commits. Used
  when the operator needs to fix a bad merge or clean up a history
  before tagging.
- `project-mgmt/` — PRD + task-generation prompts. Used for spec'ing
  new capabilities (e.g. a new MCP tool family, a new quadlet).
- `remote-connection/` — Tailscale + `kitten ssh` into the harness.
  Daily-use reference for break-glass access.

## Soft-forked from

`mecattaf/dotfiles/skills/` — Tom's personal skills library. Only the
server-relevant subset is carried over; desktop-only skills
(screenshot-tool, slides-skill, video-aigen, frontend-design-skill,
etc.) stay in the personal tree.

## Skipped on purpose

- `google-workspace-cli.md` — personal Gmail/Calendar CLI
- `meeting-memory-concept.md` — Cloudflare-edge browser recording
- `microvm/` — Firecracker sandbox research
- `screenshot-tool/`, `slides-skill/`, `video-aigen/` — Wayland/UI-bound
- `COWL-approach.md`, `aicademy-2025-writing/` — not operator-facing
