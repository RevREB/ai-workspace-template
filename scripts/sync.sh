#!/usr/bin/env bash
# Hydrate / sync the project component submodules to their RECORDED pins.
# Use this after a fresh clone, after pulling workspace changes that advanced a
# pin, or whenever a component checkout looks out of date.
#
# This NEVER advances a pin. Moving a component to a newer commit is a
# deliberate act (work in the component, PR-merge, push, then commit the new
# gitlink here) — see [01] system/SYSTEM-RULES.md, Rule 7.
set -uo pipefail
cd "${WORKSPACE_ROOT:-$PWD}"
source scripts/lib.sh

if [ ! -f .gitmodules ]; then
  ok "no component submodules to sync (.gitmodules absent)"
  exit 0
fi

info "syncing submodule URLs from .gitmodules ..."
git submodule sync --recursive >/dev/null 2>&1

info "fetching + checking out recorded pins (this can be large on first run) ..."
if git submodule update --init --recursive; then
  ok "component submodules hydrated to recorded pins"
else
  warn "submodule update hit errors — private repos need git auth (SSH key or 'gh auth')"
  exit 1
fi

drift=$(git submodule status --recursive 2>/dev/null | grep -cE '^\+' || true)
if [ "${drift:-0}" -gt 0 ]; then
  warn "$drift component(s) now differ from the recorded pin (run 'devbox run doctor')"
else
  ok "all component checkouts match recorded pins"
fi
