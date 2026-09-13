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
**The devbox shell IS the isolated environment.** Enter it and `$HOME` is sealed
to `.aihome/home`, so everything you run there — the AI CLIs, anything they
spawn, anything you type — reads and writes workspace config, including tools
that hardcode `~/.foo`. Because the workspace ships its own `AGENTS.md`,
AGENTS.md-aware CLIs also won't fall back to host conventions. Net: what the
agent sees is defined entirely by this repo.

    devbox shell        -> inside the box (sealed)
    exit                -> back on the host
    devbox run <verb>   -> runs that verb inside the box

**Entering is an explicit act.** A bare `cd` leaves you on the host with your own
git identity, credentials and shell. That is why `.envrc` deliberately does *not*
call `use devbox`: direnv's activation exports this environment into your
*current* shell, which would seal you without your having entered anything — and
takes away your ability to commit from a normal shell the moment `HOME` moves
into the box. `devbox run doctor` fails if `use devbox` is ever re-added.

A sealed home has no credentials, so they are bridged back **automatically on
entry**, per the policy in `[01] system/bridges.json` (git identity, `gh` auth,
`~/.ssh`). Nothing to run, nothing to remember. The rule is **bridge the
credential, never exempt the program**: an exemption is inherited by everything
that program spawns, so an "exempt" `git` is a door to the whole host, while a
bridged credential leaks exactly one thing. Credentials are *capability*; host
config is *context* — only the former is bridged, which is why a stale host
`~/.gitconfig` still can't reach in and make the next agent wrong.

`devbox run doctor` probes `git` and `npm` by asking them directly rather than
trusting the env vars, and checks containment rather than literal paths so it
behaves the same on macOS and Linux.

Identical on both platforms by construction: the shell utilities the scripts use
(`coreutils`, `gnused`, `gnugrep`, `findutils`, `gawk`, `bash`) and `gh` are
declared devbox packages, not host tools — otherwise the same script gets BSD
tools on macOS and GNU on Linux.

## Verbs
- `devbox run provision [cli...]` — install roster CLIs into `.aihome/` + seed config
- `devbox run sync` — hydrate/sync `06_PRODUCT/` component submodules to their recorded pins (never advances a pin)
- `devbox run setup_opencode` — configure OpenCode against the Asbru gateway (paste VK → sealed `opencode.json` with all Meridian models + lean prompt); just curls `https://asbru.mininet/setup/opencode` (Asbru is the single source of truth for the script)
- `devbox run ticket <id> [project]` — start/resume a ticket: ticket branch + `03_DRAFTS/<id>/00_TICKET.md` scaffold + the working loop (SYSTEM-RULES §10)
- `devbox run bridge` — show which host credentials are bridged and what still blocks a push (bridging itself is automatic; `refresh`/`git-identity`/`gh`/`ssh-key` override)
- `devbox run doctor` — verify toolchain, host-isolation + leak probes, bridges, macOS/Linux parity, roster, submodule pins
- `devbox run archive <project>` — retire a project (records pins, detaches submodules)
- `devbox run reset-ai` — wipe `.aihome/` for a clean re-provision
- `devbox run clean` — remove rebuildable locals

## Instantiate
1. Copy this template to a new directory (it git-inits per instance).
2. `devbox shell` — enter the box.
3. `devbox run provision` — installs the AI CLIs into `.aihome/`.
4. `devbox run doctor` — confirm host-isolation is intact.
5. Edit `[01] system/config-seeds/<cli>/` to set providers/keys per workspace.
6. Optional: edit `[01] system/bridges.json` to narrow what auto-bridges in.

## Clone an existing instance (e.g. on another machine)
1. `git clone <workspace-repo>` (git must be authed to any private component repos).
2. `cd` in, then `devbox shell` to enter the box (a bare `cd` stays on the host).
3. `devbox run sync` — pull the `06_PRODUCT/` component submodules to their pins.
4. `devbox run provision` — install the AI CLIs into `.aihome/`.
5. `devbox run doctor` — confirm host-isolation, bridges, and pins are intact.

If `sync` can't reach a private component repo, `devbox run bridge` will say
which credential is missing — the host has to *have* one for the bridge to carry
it (an unauthenticated host `gh` bridges to an unauthenticated workspace `gh`).

Host prerequisites: only `git`, `devbox`, `direnv`.
