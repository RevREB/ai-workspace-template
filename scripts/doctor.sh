#!/usr/bin/env bash
# Verify the workspace: toolchain, host-isolation, AI-CLI roster, submodule pins.
set -uo pipefail
cd "${WORKSPACE_ROOT:-$PWD}"
source scripts/lib.sh
rc=0

# --- toolchain -------------------------------------------------------------
miss=""
for t in git jq node npm; do command -v "$t" >/dev/null 2>&1 || miss="$miss $t"; done
if [ -z "$miss" ]; then ok "toolchain present (git, jq, node, npm)"; else warn "missing tools:$miss"; rc=1; fi

# --- host isolation (the point of this template) ---------------------------
if [ "${AI_HOME:-}" = "$PWD/.aihome" ]; then ok "AI_HOME sealed to workspace (.aihome)"; else warn "AI_HOME not sealed (got '${AI_HOME:-unset}') — re-enter the devbox shell"; rc=1; fi
if [ -f AGENTS.md ]; then ok "AGENTS.md present (AGENTS.md-aware CLIs won't fall back to host ~/.claude)"; else warn "AGENTS.md missing — CLIs may inherit host config"; rc=1; fi
case "${CLAUDE_CONFIG_DIR:-}" in "$PWD"/*) ok "CLAUDE_CONFIG_DIR workspace-local";; *) warn "CLAUDE_CONFIG_DIR not workspace-local ('${CLAUDE_CONFIG_DIR:-unset}')"; rc=1;; esac
case "${XDG_CONFIG_HOME:-}" in "$PWD"/*) ok "XDG_CONFIG_HOME workspace-local";; *) warn "XDG_CONFIG_HOME not workspace-local ('${XDG_CONFIG_HOME:-unset}')"; rc=1;; esac

# --- AI-CLI roster ---------------------------------------------------------
ROSTER="[01] system/ai-tools.json"
if [ -f "$ROSTER" ]; then
  while IFS=$'\t' read -r name bin; do
    if [ -x ".aihome/npm/bin/$bin" ] || command -v "$bin" >/dev/null 2>&1; then
      ok "CLI '$name' available"
    else
      warn "CLI '$name' not provisioned — run: devbox run provision $name"
    fi
  done < <(jq -r '.clis[] | "\(.name)\t\(.bin)"' "$ROSTER")
else
  warn "roster missing: $ROSTER"
fi

# --- product boundary: warn on unpushed component pins ---------------------
if [ -f .gitmodules ] && git rev-parse --git-dir >/dev/null 2>&1; then
  dirty=$(git submodule status --recursive 2>/dev/null | grep -cE '^\+' || true)
  [ "${dirty:-0}" -gt 0 ] && warn "$dirty submodule pin(s) differ from recorded commit (review before committing pins)" || ok "submodule pins match recorded commits"
fi

# --- knowledge bundle integrity -------------------------------------------
if [ -d "[02] knowledge" ]; then
  bad=$(grep -Lri 'status:' "[02] knowledge/"*.md 2>/dev/null | grep -v _TEMPLATE | wc -l | tr -d ' ')
  [ "${bad:-0}" -gt 0 ] && warn "$bad knowledge file(s) missing a 'status:' field" || ok "knowledge bundle has status fields"
fi

if [ $rc -eq 0 ]; then ok "doctor: all green"; else warn "doctor: issues above"; fi
exit $rc
