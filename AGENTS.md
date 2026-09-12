# Workspace Entry Point

Before doing anything in this workspace, read `[01] system/SYSTEM-RULES.md`.
It defines the folder map, the knowledge-retrieval protocol (which tier of memory
to trust), file naming rules, the product boundary, and where results get saved.

This file (`AGENTS.md`) is the cross-tool instruction standard — OpenCode, Claude
Code, and other AGENTS.md-aware CLIs all read it. It replaces the old
tool-specific `CLAUDE.md`. Keep instructions here vendor-neutral.

Quick map:

- `[01] system/` — rules the AI agent must follow (read first) + the tool roster
- `[02] knowledge/` — curated, authoritative knowledge (OKF bundle; trust per
  its `status` field)
- `[03] projects/` — active work, one folder per project, numbered workflow
  inside; work-product repos mount as component submodules under
  `06_PRODUCT/<component>/` (the container is never itself a submodule; work
  branch + PR only, SHA-pinned per component)
- `[04] outputs/` — final deliverable files (PDFs, renders, exports);
  decoupled from git/work product
- `[99] archive/` — old material; searchable but never authoritative

## Environment: Devbox (hermetic, host-isolated)

The dev toolchain is hermetic: enter via direnv (`direnv allow`, then re-enter
the directory) or `devbox shell`, and never install tools globally — add
packages to `devbox.json`. All workspace environment variables live in
`devbox.json` (committed); there is no `.env` layer.

**AI-CLI config is sealed to the workspace.** Unlike a normal install, this
template redirects every AI coding CLI's home/config into `.aihome/` (see the
`AI_HOME` / `XDG_*` / `*_CONFIG_DIR` env in `devbox.json`). Inside the devbox
shell, `opencode`, `claude`, etc. read config, credentials, and tool/plugin
state **only** from `.aihome/` — never from the host's `~/.claude`,
`~/.config`, or host skills. This keeps every workspace reproducible and
prevents host config from leaking into requests. Consequences:

- The AI CLIs are installed under `.aihome/` by `devbox run provision`, not
  user-globally.
- This `AGENTS.md` is the authoritative instruction file; because it exists,
  AGENTS.md-aware CLIs do **not** fall back to host `~/.claude` conventions.
- `devbox run reset-ai` wipes `.aihome/` for a clean re-provision.

Canonical verbs:

- `devbox run provision [cli...]` — install the workspace's AI CLIs into
  `.aihome/` and seed their config (default: all in the roster; e.g.
  `devbox run provision opencode claude`)
- `devbox run sync` — hydrate/sync the project component submodules under
  `06_PRODUCT/` to their recorded pins (`git submodule sync` +
  `update --init --recursive`). Run it after a fresh clone or after pulling
  workspace changes that advanced a pin. It never advances a pin itself.
- `devbox run setup_opencode` — configure OpenCode to use the Asbru gateway:
  prompts for your VK, enumerates all Meridian models, and writes a sealed
  `opencode.json` (single `asbru` provider) + a lean, identity-free system
  prompt (so it bills to the subscription, not metered usage). Running it via
  this verb guarantees the config lands in `.aihome`, not host `~/.config`.
  The verb just runs `curl -fsSL https://asbru.mininet/setup/opencode | sh` —
  Asbru serves the script (`GET /setup/opencode`) as the single source of truth,
  so edit it in the asbru repo (`transports/asbru-http/handlers/opencode.sh`),
  never here.
- `devbox run doctor` — verify toolchain, host-isolation, roster, submodule
  state (incl. unpushed component pins), and knowledge bundle integrity
- `devbox run archive <project>` — safely retire a project into
  `[99] archive/` (records final pins, detaches submodules properly)
- `devbox run reset-ai` — wipe `.aihome/` (forces a clean re-provision)
- `devbox run clean` — remove rebuildable locals (`.cache/`, `.devbox/`)
