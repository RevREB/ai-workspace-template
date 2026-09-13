---
type: system
title: "System Rules"
description: "Operating rules for this workspace: folder map, retrieval protocol, naming, product boundary, environment."
owner: "me"
tags: [system, rules, router]
timestamp: 2026-08-30T00:00:00Z
---

# SYSTEM RULES

These rules govern how the AI agent works inside this workspace. The folder structure is
part of the prompt: it tells you what to read, what to trust, what to ignore, and
where to save results.

## 1. The Folder Map

| Folder | Role | Memory tier |
|---|---|---|
| `[01] system/` | Rules you must follow | Read at session start (via the AGENTS.md pointer) |
| `[02] knowledge/` | Curated, reviewed, authoritative facts (OKF bundle) | **Deterministic** — read directly, trust per status (Rule 2) |
| `[03] projects/` | Active work, one subfolder per project | Working memory |
| `[04] outputs/` | Final deliverable files (PDFs, renders, exports) | Write-only destination |
| `[99] archive/` | Old material, kept for search | **Probabilistic** — search it, never trust it blindly |

## 2. Retrieval Protocol (the Router)

When you need a fact, definition, preference, formula, contract, or procedure:

1. **Knowledge first.** Check `[02] knowledge/` for a file whose name or
   frontmatter matches the concept. Trust by its `status` field:
   `approved` — the official answer; use it verbatim, do not second-guess it
   against anything found elsewhere. `draft` — provisional; use it, but say
   it is a draft. `deprecated` — history only; never act on it.
2. **Active project second.** If not in knowledge, check the project you are
   working in: its `00_BRIEF.md` and `01_SOURCES/`. If it is ambiguous which
   project is active, ask.
3. **Archive last (probabilistic).** If still not found, search `[99] archive/`.
   Anything retrieved from archive is *possibly stale and unreviewed*: label it
   as such in your answer (e.g., "per an archived note from 2025, unverified").
   Exception: `ARCHIVED.md` files are factual records of final component
   pins — cite them as records, not as stale knowledge.
4. **Never fabricate.** If none of the three tiers answers the question, say so
   and ask — do not guess at formulas, contracts, names, or procedures.

**Precedence on conflict:** knowledge > active project > archive. A newer archive
file never overrides a knowledge file; instead, flag the discrepancy so the
knowledge file can be updated.

## 3. Promotion Rule (how knowledge grows)

When an answer dug out of `[99] archive/` or produced during a project proves
correct and reusable, promote it: create a new file in `[02] knowledge/` using
`_TEMPLATE.md` (one concept per file, frontmatter filled in), born as
`status: draft`. Flipping a file to `approved` is a deliberate human act —
The AI agent proposes, the human approves. Nothing enters `[02] knowledge/` as a
side effect.

## 4. File Naming

Names are context: they should answer *when? what? what status?* before the file
is opened.

**Scope:** this format applies to project working files (`01_SOURCES/`,
`02_NOTES/`, `03_DRAFTS/`, `05_FINAL/`) and `[04] outputs/`. `04_VISUALS/`
is exempt — assets keep their natural filenames. Knowledge files
use descriptive kebab-case names instead (`voice-guide.md`); `_TEMPLATE.md`'s
underscore marks it as scaffolding.

- Format: `DATE_topic_status.ext` → `2026-08-30_q3-report_draft-v2.md`
- Date precision matches the file's lifespan:
  - `YYYY` — long-term files
  - `YYYY-Q3` — planning cycles
  - `YYYY-MM` — recurring work
  - `YYYY-MM-DD` — task-specific files
- Never: `final.docx`, `final_v2.docx`, `new_final_REAL.docx`, `notes.md`

## 5. Numbering

- Workspace top level: numbered map (`[01]`–`[04]`, `[99]` so archive sorts last).
- Inside a project: numbered workflow — `00_BRIEF.md` → `01_SOURCES/` →
  `02_NOTES/` → `03_DRAFTS/` → `04_VISUALS/` → `05_FINAL/` → `06_PRODUCT/`
  (container of component submodules). The numbers are the reading and
  working order.
- `[02] knowledge/` is a **library, not a workflow** — descriptive names, no numbers.

## 6. Saving Results

- Work in progress → the project's `03_DRAFTS/`
- Repo-shaped deliverable → PR into the component under `06_PRODUCT/`, then
  advance the pin with a normal git commit in the workspace (see Rule 7)
- Non-repo deliverable → copy to `05_FINAL/` and `[04] outputs/` with a full
  `DATE_topic_final` name
- Completed project → `devbox run archive <project>`. NEVER plain-`mv` a
  project into `[99] archive/` — moving live submodules by hand corrupts the
  repo for every clone. The archive verb records final pins in ARCHIVED.md,
  detaches the components safely, and moves the folder.

## 7. The Product Boundary

The workspace is the office; the **work product** (code, art, creative,
business) lives in its own separate, clean repositories. Product repos carry
none of the workspace's cruft — no drafts, no knowledge bundle, no OKF
frontmatter, no workspace tooling. They have only their own conventions.

- **Mount:** `06_PRODUCT/` is always a plain container directory — it is
  **never itself a submodule**. Product repos mount as component submodules
  inside it: `[03] projects/<name>/06_PRODUCT/<component>/`. A monorepo is
  the one-component case (e.g. `06_PRODUCT/main/`); a modular codebase gets
  one component per repo (`frontend/`, `api-spec/`, `infra/`, ...).
- **One-way dependency:** the workspace knows the product; a product repo
  never references or depends on the workspace.
- **Write rules (PR-only):** inside every component submodule, work happens
  on a work branch; merging to that component's main goes through a
  PR/review. This is a working convention, not a mechanism — enable branch
  protection on each component repo at the forge to make it real.
- **Pinning (SHA):** git manages the state. Each component pin is a gitlink
  the workspace commits like any other change — advance it deliberately
  (`git add` the component, commit), never as a side effect of unrelated
  staging. Before committing a pin, the pinned commit must be merged and
  pushed: a pin nobody can fetch breaks `submodule update` on every other
  clone (`devbox run doctor` warns when a component HEAD is on no known
  remote ref). A workspace commit that advances pins IS the record that
  those component versions belong together — reconstruction is
  `git checkout` of that commit.
- **Hydrating (SHA → working tree):** `devbox run sync` checks out every
  component to its recorded pin (`git submodule sync` +
  `update --init --recursive`). Run it after a fresh clone or after pulling
  workspace changes that moved a pin. It only ever moves checkouts *to* the
  recorded pins — it never advances a pin (that is the deliberate act above).
- **Outputs rule:** `[04] outputs/` is decoupled from git and the work
  product — it holds only final deliverable *files* (a sent PDF, a
  submitted form, an exported render). Repo-shaped deliverables live in the
  product repos; their record is the workspace commit that advanced the pin.

## 8. Environment & Host-Isolation

- The workspace toolchain is Devbox-managed and rebuildable: host installs
  are only git + devbox + direnv. Everything else — including the AI coding
  CLIs — is provisioned into the workspace by `devbox run provision`.
- **The devbox shell IS the isolated environment.** Inside it `$HOME` is sealed
  to `.aihome/home` and git/npm/XDG config is redirected there, so *every* tool
  run in the box lands inside the workspace — including ones that hardcode
  `~/.foo` and ones not installed yet. Nothing is read from or written to the
  host: not `~/.claude`, not `~/.config`, not `~/.gitconfig`. Because this
  workspace ships its own `AGENTS.md`, AGENTS.md-aware CLIs also do not fall back
  to host conventions. `devbox run reset-ai` wipes `.aihome/`.
  - **Entering is an explicit act.** `devbox shell` enters; `exit` returns you to
    the host; `devbox run <verb>` runs one verb inside. A bare `cd` must leave
    you on the host, with your own git identity, credentials and shell intact.
  - **`.envrc` must not activate devbox.** direnv's `use devbox` evaluates
    `devbox shellenv --init-hook` and exports the whole environment into your
    *current* shell, so merely `cd`-ing here would seal you without your having
    entered anything — and once `HOME` is in the box that costs you the ability
    to commit from a normal shell. `doctor` fails if `use devbox` reappears.
  - **Why `HOME` and not more per-tool variables.** Redirect-by-variable only
    captures tools that agreed to honor those variables. Each tool that does not
    costs another escape hatch (see the OpenCode caveat below) and that list
    never stops growing. Moving `HOME` is one lever that needs no cooperation.
  - `HOST_HOME` captures the real home *before* the override, so a bridge can
    find it deliberately. It is a lookup path, never an automatic fallback.
- **Bridge the credential, never exempt the program.** A sealed home has no
  keys, so host access is granted back as named resources — never by letting a
  program see the host home. Exemptions are inherited by everything a program
  spawns: the AI runs `git`, `git` runs credential helpers and `ssh`, and a host
  `.gitconfig` can point those at arbitrary host binaries — so an "exempt" `git`
  is a door to the whole machine. A bridged credential leaks exactly one thing.
  - **Credentials are capability; host config is context.** Only capability is
    bridged. This is why auto-bridging does not weaken the tier system: a
    bridged token cannot make the next agent confidently wrong, whereas an
    inherited `~/.gitconfig` or `~/.claude` silently changes how it behaves.
  - **Bridging is automatic**, applied on entry to the box by
    `scripts/seal-home.sh` per `[01] system/bridges.json`. A workspace you must
    remember to unlock is the same fight the sealed `HOME` was meant to end;
    the policy file — not a command you have to recall — is the record of what
    is granted. Narrow it by setting an entry to `false`.
  - Prefer the ssh **agent** over bridging `~/.ssh`: it lets the workspace *use*
    a key without *reading* it. `SSH_AUTH_SOCK` passes through on its own.
  - `devbox run bridge` inspects and overrides; `doctor` reports the live state.
    Neither is required for normal work.
- **Isolation is checked by containment, never by exact path.** macOS tools
  write to `~/Library/Application Support/…` and Linux tools to `~/.config/…`;
  both land inside the sealed home at different paths. `doctor` therefore asks
  "is this inside `$WORKSPACE_ROOT`?" — a literal-path assertion would pass on
  one OS and fail on the other. `.aihome/` is per-machine and rebuildable:
  never sync it between machines, re-provision instead.
- **The userland comes from devbox, not the host.** `coreutils`, `gnused`,
  `gnugrep`, `findutils`, `gawk`, `bash`, and `gh` are declared packages so the
  scripts run against identical tools on macOS and Linux. Relying on whatever
  the host ships means BSD tools on one and GNU on the other — the same script
  silently behaving differently per machine. `GIT_CONFIG_SYSTEM=/dev/null`
  excludes the platform-specific system gitconfig for the same reason (its
  `osxkeychain` credential helper does not exist on Linux).
- **OpenCode caveat.** OpenCode does *not* honor the AGENTS.md host-fallback
  rule on its own — it will read the host `~/.claude` prompt and skills unless
  told not to. `devbox.json` therefore also sets `OPENCODE_CONFIG_DIR`
  (config dir → `.aihome/config/opencode`) and
  `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT` / `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS`
  to seal it. This rationale lives here because `devbox.json` cannot carry
  inline comments — an inline `#` becomes part of the value (see the
  `.gitignore` lesson).
- **All workspace environment variables live in `devbox.json` (committed).**
  There is no `.env` layer: nothing machine-specific belongs in this
  workspace, and secrets never live in workspace files — if one is ever
  needed, it arrives via a secret-manager command invoked through devbox.
- `ai-tools.json` (this folder) is the AI-CLI roster: the coding CLIs this
  workspace provisions into `.aihome/` (never user-global). `devbox run
  provision` installs them; `devbox run doctor` verifies each is present and
  that host-isolation is intact.
- Never install an AI CLI or tool ad hoc; add it to the roster first, then
  `devbox run provision`.
- **Changing `devbox.json` requires re-entering the shell.** Devbox caches the
  computed environment, and an already-active shell keeps serving the old one —
  `devbox run` inside it will not pick up new `env` keys. `.envrc` watches
  `devbox.json`/`devbox.lock` so direnv reloads on `cd`; after editing packages,
  run `devbox install`. If a change appears not to apply, check `devbox
  shellenv` (what devbox *computes*) against the live environment (what the
  stale shell *has*) before concluding the config is wrong.

## 9. Documentation Currency (write it back)

Reading the docs is half the protocol; keeping what the next agent reads *true*
is the other half. Because `[02] knowledge/` is an **authoritative** tier, a
stale entry doesn't just leave a gap — it makes the next agent confidently wrong.
So **a change is not done until the docs that describe it are updated in the same
commit.**

When you change the system, update the matching docs:

| When you… | Update |
|---|---|
| change deploy / build / version | the project `00_BRIEF.md` current-state + `ARCHITECTURE.md` "Last verified" |
| add / remove / retire a component or dependency | `00_BRIEF.md` component list + `ARCHITECTURE.md` (narrative **and** diagram) + the affected `[02] knowledge/` file |
| change a contract, procedure, or constant | the matching `[02] knowledge/` file + bump its `last_verified` (never silently flip `status` — approval is a human act, Rule 3) |
| advance a component pin | `git add` the pin **and** append a decision-log entry |
| **any material change** | append one dated entry to the project's `02_NOTES/CHANGELOG.md` |

- **`02_NOTES/CHANGELOG.md`** is the project's memory: append-only, newest last,
  one entry per material change (*what changed, why, which docs you updated*).
- Knowledge and `ARCHITECTURE.md` carry a `last_verified: YYYY-MM-DD` field; bump
  it when you confirm the content still matches reality.
- If you find a doc already stale, fix it as part of your task and log it.
- `devbox run doctor` surfaces violations (stale `last_verified`, an uncommitted
  `status: approved` file, a project missing its `CHANGELOG.md`). Like the rest of
  this workspace it's convention + a visible check, not filesystem enforcement —
  the discipline is yours to keep.

## 10. Working a Ticket

This is how a human and a bot share work: a ticket points at this meta-repo, and
the context follows the work. A ticket handed to a bot MUST carry:

| Field | Meaning |
|---|---|
| `id` | stable ticket identifier |
| `workspace` | this repo's clone URL |
| `project` | which `[03] projects/<name>` it targets |
| `goal` | what "done" looks like |
| `acceptance` | how "done" is verified |
| `constraints` | optional — component(s), deadline, hard requirements |

Given `(workspace, ticket)`, the loop (`devbox run ticket <id>` scaffolds 0–1):

0. **Bootstrap** — clone → `direnv allow`/`devbox shell` → `devbox run sync` →
   `devbox run provision` → `devbox run doctor` (green before working).
1. **Branch + record** — work on `ticket/<id>`; the living record is
   `[03] projects/<project>/03_DRAFTS/<id>/00_TICKET.md` (goal, plan, work log, outcome).
2. **Orient** — read `ARCHITECTURE.md` → `00_BRIEF.md` → the relevant `[02] knowledge/`
   (Retrieval Protocol, Rule 2). Never start blank when the desk already has memory.
3. **Work** — code lands as a PR into the right `06_PRODUCT/<component>` (Product
   Boundary, Rule 7); non-repo deliverables to `05_FINAL/` + `[04] outputs/`.
4. **Write back** — update `00_BRIEF`/`ARCHITECTURE`/`[02] knowledge` + `last_verified`,
   advance pins, append a `02_NOTES/CHANGELOG.md` entry (Documentation Currency, Rule 9).
5. **Report** — fill the ticket's Outcome, set `status: in-review`, open a workspace PR
   for `ticket/<id>`, and post the Outcome back to the ticket's source.

**Concurrency (an army of bots):** one ticket = one branch, or one ephemeral clone
(a fresh desk per ticket). Bots reconcile through PRs to the canonical workspace, the
same way component pins do; `main` is the shared record, a ticket branch is a private
draft until reviewed.

**What lives where:** the ticket's *assignment* comes from outside (Yrkjendr / an issue
tracker); its *trail* — plan, decisions, outcome — lives in `00_TICKET.md` + `CHANGELOG.md`
so the next bot or human inherits it. Org-durable, cross-project knowledge is promoted
out to an external KB; this repo is the lowest-order layer beneath it.

## 11. Summary Mnemonic

> Markdown for instructions. Numbers for order. Names for meaning.
> Dates for search. Archive for noise. Knowledge for truth.
> Product in its own repos. Pins for provenance. Roster for tools.
> Change it, then write it back. A ticket points here; the context follows.
