---
name: dotfiles
slug: dotfiles
chapter: "1"
audience: internal
vendor_class: soft-fork-inspired
upstream: https://github.com/mecattaf/leger-labs
sanitization_posture: private-forever
status: active
depends_on: [harness]
consumed_by: [harness]
---

Chezmoi-managed dotfiles for the Sodimo Framework Desktop harness (Fedora 44 bootc, AMD Strix Halo). Ships the podman Quadlet definitions, Caddyfile, per-service routes, shell config, and a small set of operator skills. Soft-forked from `leger-labs/quadlet-setup/dotfiles1/` (upstream provides the quadlet template pattern for local AI: llama.cpp + llama-swap + LiteLLM + OpenWebUI + Caddy + Cockpit) and extended with the Sodimo-net-new layer (mail stack, Twenty CRM, Vaultwarden, Sodiwin ETL timer, Email pull-drain). Does not carry the OS image (that's `sodimo/harness` bootc); does not carry the application-layer code (Workers/MCP live in `sodimo/mcp`, CRM customizations in `sodimo/crm`). Intended to be applied to the harness via `chezmoi apply` at provisioning time.
