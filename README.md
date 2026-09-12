# AI-Workspace-template

A hermetic, **host-isolated** workspace template for AI coding agents. Any
AGENTS.md-aware CLI (OpenCode, Claude Code, …) runs inside the Devbox shell
reading **only** the workspace's config — never the host's `~/.claude`,
`~/.config`, or host skills. Reproducible per-workspace; nothing leaks in or out.

## Layout
- `AGENTS.md` — entry point + cross-tool instructions (read first)
- `[01] system/` — `SYSTEM-RULES.md` (the router), `ai-tools.json` (AI-CLI roster),
  `config-seeds/` (per-CLI workspace config, seeded on provision)
- `[02] knowledge/` — curated, authoritative knowledge (trust per `status`)
- `[03] projects/` — active work; product repos mount as component submodules
  under `06_PRODUCT/` (SHA-pinned, PR-only)
- `[04] outputs/` — final deliverable files (decoupled from git)
- `[99] archive/` — searchable, never authoritative
- `.aihome/` — **sealed AI home** (gitignored); all CLI config/creds/tools live here

## Host-isolation (the point)
`devbox.json` redirects every AI CLI's home/config into `.aihome/` via `AI_HOME`,
`XDG_*`, and per-CLI `*_CONFIG_DIR`. Because the workspace ships its own
`AGENTS.md`, AGENTS.md-aware CLIs also won't fall back to host conventions. Net:
what the agent sees is defined entirely by this repo.

## Verbs
- `devbox run provision [cli...]` — install roster CLIs into `.aihome/` + seed config
- `devbox run doctor` — verify toolchain, host-isolation, roster, submodule pins
- `devbox run archive <project>` — retire a project (records pins, detaches submodules)
- `devbox run reset-ai` — wipe `.aihome/` for a clean re-provision
- `devbox run clean` — remove rebuildable locals

## Instantiate
1. Copy this template to a new directory (it git-inits per instance).
2. `direnv allow` (or `devbox shell`).
3. `devbox run provision` — installs the AI CLIs into `.aihome/`.
4. `devbox run doctor` — confirm host-isolation is intact.
5. Edit `[01] system/config-seeds/<cli>/` to set providers/keys per workspace.

Host prerequisites: only `git`, `devbox`, `direnv`.
