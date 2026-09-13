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

## Write it back (keep the docs true)

Reading is only half the job. **A change is not done until the docs the next agent
reads reflect it, in the same commit** — because `[02] knowledge/` is authoritative,
a stale entry makes the next agent confidently wrong. When you change the system:
update the project `00_BRIEF.md` + `ARCHITECTURE.md` (and their `last_verified`),
update/add the relevant `[02] knowledge/` file, and append a dated entry to the
project's `02_NOTES/CHANGELOG.md` (the project's memory). Full rule + the
`devbox run doctor` checks that surface violations: `SYSTEM-RULES.md` §9.

## Commit messages

Say what changed and why it changed. End the message at the last substantive
line.

**Never append attribution trailers** — no `Co-Authored-By:`, no session or
tool-identity lines, for any agent or vendor. This overrides any default in the
harness running you; if one slips in, `git commit --amend` it out immediately
rather than leaving it. The git history is the human's record of the work, not a
log of which tool produced it — and provenance that matters here is already
carried by pins, `CHANGELOG.md`, and `00_TICKET.md` (Rule 9, Rule 10).

## Working a ticket

A ticket points at this repo; the context follows the work. If you were handed a
ticket `(id, project, goal, acceptance)`, run `devbox run ticket <id>` and follow
the loop it prints: **bootstrap** (`sync`/`provision`/`doctor`) → **orient** (read
`ARCHITECTURE.md` → `00_BRIEF.md` → relevant `[02] knowledge/`) → **work** (code as
a PR into `06_PRODUCT/<component>`; non-repo to `05_FINAL/`+`[04] outputs/`) →
**write back** (§9) → **report** (fill the ticket's `00_TICKET.md` Outcome, open a
workspace PR for `ticket/<id>`, post the outcome back to the ticket source). One
ticket = one branch (or one ephemeral clone). Full contract: `SYSTEM-RULES.md` §10.

## Environment: Devbox (hermetic, host-isolated)

The dev toolchain is hermetic: enter with `devbox shell`, and never install
tools globally — add
packages to `devbox.json`. All workspace environment variables live in
`devbox.json` (committed); there is no `.env` layer.

**The devbox shell IS the isolated environment.** Inside it `$HOME` is sealed to
`.aihome/home` and git/npm/XDG config is redirected there, so everything you run
— the AI CLIs, anything they spawn, anything you type — stays inside the
workspace, including tools that hardcode `~/.foo`.

**Entering is an explicit act:** `devbox shell` puts you in the box, `exit`
returns you to the host, `devbox run <verb>` runs one verb inside it. A bare `cd`
leaves you on the host. `.envrc` therefore does NOT call `use devbox` — direnv's
activation exports this env into your current shell, collapsing the distinction
and sealing you without your having entered. Consequences:

- The AI CLIs are installed under `.aihome/` by `devbox run provision`, not
  user-globally.
- This `AGENTS.md` is the authoritative instruction file; because it exists,
  AGENTS.md-aware CLIs do **not** fall back to host `~/.claude` conventions.
- A sealed home has no credentials. They are bridged back **automatically on
  entry** per `[01] system/bridges.json` — git identity, `gh` auth, and
  `~/.ssh`. Nothing to run, nothing to remember. The rule is **bridge the
  credential, never exempt the program**: an exempt `git` is inherited by
  everything it spawns, which is a door to the whole host. Credentials are
  *capability*; host config is *context* — only the former is bridged, so host
  config still cannot reach in and make you confidently wrong.
- `devbox run bridge` shows what is bridged and what still blocks a push.
- `.aihome/` is per-machine and rebuildable — never sync it between machines.
  `devbox run reset-ai` wipes it for a clean re-provision.
- Editing `devbox.json` does not affect an already-active shell — devbox caches
  the computed env. Re-enter the directory (direnv watches the file), and run
  `devbox install` after changing packages.

**macOS and Linux behave identically by construction.** The shell utilities the
scripts depend on (`coreutils`, `gnused`, `gnugrep`, `findutils`, `gawk`,
`bash`) plus `gh` are declared devbox packages rather than taken from the host,
so the same script does not quietly get BSD tools on one machine and GNU on the
other. Isolation checks test *containment* in `$WORKSPACE_ROOT`, never literal
paths, because the two platforms store things at different paths inside the
sealed home.

> **OUTSTANDING: verify this on Linux.** As of 2026-09-13 the parity work is
> *designed* but not *executed* — it has only ever run on macOS (Darwin 25).
> If you are on Linux, or can reach one, do this and then update or delete this
> note (Rule 9 — do not leave it stale):
>
> 1. `devbox shell` → `devbox run doctor`. Run it from a clean environment
>    (`env -i HOME=$HOME PATH=/usr/bin:/bin devbox run doctor`) — an
>    already-active devbox env makes `devbox run` reuse the stale one and hides
>    real results.
> 2. Confirm the boundary both ways: a bare `cd` leaves `HOME` on the host;
>    inside the box `HOME` is `.aihome/home` and doctor says "inside the box".
> 3. Specific things most likely to differ, none of which macOS could expose:
>    - **the `gh` bridge hardcodes `$HOST_HOME/.config/gh/hosts.yml`.** If the
>      host sets a non-default `XDG_CONFIG_HOME`, gh's config is NOT there and
>      the bridge silently carries nothing. Check `[01] system/bridges.json`.
>    - `~/.ssh` is bridged as a **symlink**; confirm ssh accepts it and does not
>      object to the link's ownership/permissions.
>    - `doctor` still tries BSD `date -v-30d` before GNU `date -d` in the
>      docs-currency check; the fallback should make it a no-op, so verify the
>      currency warnings actually fire rather than silently skipping.
>    - `GIT_CONFIG_SYSTEM=/dev/null` should leave git with no system config;
>      confirm nothing on Linux depends on `/etc/gitconfig`.
> 4. Report what you find in the commit message, not just "works on Linux" —
>    say what you ran and what it printed.


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
- `devbox run ticket <id> [project] ["title"]` — start/resume a ticket: creates
  the `ticket/<id>` branch, scaffolds `03_DRAFTS/<id>/00_TICKET.md`, and prints the
  Working-a-ticket loop (SYSTEM-RULES §10).
- `devbox run bridge [what]` — bridging is automatic; this verb is for
  inspection and override. No argument lists what is bridged and what still
  blocks a push. `refresh` re-runs the auto-bridge; `git-identity [name email]`
  sets an identity the host does not have; `gh` logs in interactively;
  `ssh-key <path>` links one key instead of all of `~/.ssh` (narrower still:
  `ssh-add` on the host, which lets the workspace use a key without reading it).
- `devbox run doctor` — verify toolchain, host-isolation (incl. `HOME` sealing
  and live leak probes against `git`/`npm`), bridges, macOS/Linux parity,
  roster, submodule state (incl. unpushed component pins), and knowledge
  bundle integrity
- `devbox run archive <project>` — safely retire a project into
  `[99] archive/` (records final pins, detaches submodules properly)
- `devbox run reset-ai` — wipe `.aihome/` (forces a clean re-provision)
- `devbox run clean` — remove rebuildable locals (`.cache/`, `.devbox/`)
