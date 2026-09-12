#!/usr/bin/env sh
# devbox run ticket <id> [project] ["title"]
#
# Start (or resume) work on a ticket in this workspace: create a ticket branch,
# scaffold the per-ticket record, and print the "Working a ticket" loop. This is
# the local half of the ticket contract — see SYSTEM-RULES.md §10.
set -eu
cd "${WORKSPACE_ROOT:-$PWD}"

ID="${1:-}"
[ -n "$ID" ] || { echo 'usage: devbox run ticket <id> [project] ["title"]' >&2; exit 1; }
PROJECT="${2:-}"
TITLE="${3:-$ID}"

# resolve the project (auto if there's exactly one)
if [ -z "$PROJECT" ]; then
  projs=$(find "[03] projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
          | sed 's#.*/##' | grep -v '^_project-template$' || true)
  n=$(printf '%s\n' "$projs" | grep -c . || true)
  if [ "$n" = "1" ]; then PROJECT="$projs"
  else
    echo "specify the project: devbox run ticket $ID <project>" >&2
    printf '%s\n' "$projs" | sed 's/^/  - /' >&2
    exit 1
  fi
fi
PDIR="[03] projects/$PROJECT"
[ -d "$PDIR" ] || { echo "no such project: $PROJECT" >&2; exit 1; }

TDIR="$PDIR/03_DRAFTS/$ID"
mkdir -p "$TDIR"
TODAY=$(date +%F 2>/dev/null || echo "YYYY-MM-DD")

# per-ticket branch (isolation; PRs back to the canonical workspace)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git switch -c "ticket/$ID" 2>/dev/null || git switch "ticket/$ID" 2>/dev/null \
    || echo "  ! could not switch to ticket/$ID (uncommitted changes?) — do it by hand" >&2
fi

# per-ticket record (never clobber an existing one)
if [ ! -f "$TDIR/00_TICKET.md" ]; then
  cat > "$TDIR/00_TICKET.md" <<EOF
---
ticket: $ID
source:            # URL / system the ticket came from (Yrkjendr, Forgejo, ...)
project: $PROJECT
status: in-progress   # open | in-progress | in-review | done
opened: $TODAY
branch: ticket/$ID
---

# $TITLE

## Goal / acceptance
(What "done" looks like + acceptance criteria. Fill from the ticket.)

## Plan
(Your plan; keep it current as you learn.)

## Work log
- $TODAY — ticket opened

## Outcome
(Close summary: PRs opened, docs updated, pins advanced. This is what follows the work.)
EOF
  echo "  ✓ scaffolded $TDIR/00_TICKET.md"
else
  echo "  ✓ resuming $TDIR/00_TICKET.md"
fi

cat <<EOF

Ticket $ID is ready on branch ticket/$ID (project: $PROJECT).

Working-a-ticket loop (SYSTEM-RULES §10):
  1. devbox run sync && devbox run doctor        # hydrate + verify the desk
  2. orient  → read $PDIR/ARCHITECTURE.md, 00_BRIEF.md, and the relevant [02] knowledge/
  3. record  → write the goal/acceptance + plan into $TDIR/00_TICKET.md
  4. work    → code = PR into 06_PRODUCT/<component>; non-repo = 05_FINAL/ + [04] outputs/
  5. write back (§9) → update BRIEF/ARCHITECTURE/knowledge + last_verified; advance pins;
                       append a 02_NOTES/CHANGELOG.md entry
  6. report  → fill Outcome, set status: in-review, open a workspace PR (branch ticket/$ID),
               post the Outcome back to the ticket source
EOF
