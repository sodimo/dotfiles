# Sodimo-derived Paperclip image — adds the pi-mono coding-agent CLI
# (@mariozechner/pi-coding-agent) on top of upstream paperclip.
#
# Important: the package is `@mariozechner/pi-coding-agent`, NOT `@mariozechner/pi`.
# The latter (also published by Mario Zechner under npm name `@mariozechner/pi`)
# is a different product — a CLI for managing vLLM deployments on GPU pods,
# binary `pi-pods`. The coding-agent CLI's binary is `pi`. The chapter and
# the original Dockerfile both had this wrong; corrected 2026-05-05.
#
# Build locally on the box (see midday-paperclip-pi-setup.md for replay):
#   cd ~/.local/share/chezmoi/docker/paperclip && \
#     podman build -t localhost/sodimo-paperclip:dev-<date> .
# Until the ghcr.io publish path is unblocked (sodimo/dotfiles#12), the image
# stays local-only — paperclip.container references the localhost/ tag.
FROM ghcr.io/paperclipai/paperclip:sha-b8725c5
USER root
RUN npm install -g @mariozechner/pi-coding-agent@latest \
  && rm -rf /tmp/* /root/.npm
USER node
