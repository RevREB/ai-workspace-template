#!/usr/bin/env bash
# Provision the workspace's AI CLIs into the sealed .aihome/ (host-isolated).
# Reads the roster in [01] system/ai-tools.json. With no args, provisions the
# whole roster; otherwise only the named CLIs (e.g. provision opencode).
set -uo pipefail
cd "${WORKSPACE_ROOT:-$PWD}"
source scripts/lib.sh

ROSTER="[01] system/ai-tools.json"
[ -f "$ROSTER" ] || fail "roster not found: $ROSTER"
command -v npm >/dev/null || fail "npm not on PATH (add nodejs to devbox.json, re-enter shell)"
[ -n "${NPM_CONFIG_PREFIX:-}" ] || warn "NPM_CONFIG_PREFIX unset — CLIs may install user-global (re-enter the devbox shell)"

mkdir -p .aihome/npm/bin .aihome/config

want=("$@")
if [ ${#want[@]} -eq 0 ]; then
  while IFS= read -r n; do want+=("$n"); done < <(jq -r '.clis[].name' "$ROSTER")
fi

for name in "${want[@]}"; do
  entry=$(jq -c --arg n "$name" '.clis[] | select(.name==$n)' "$ROSTER")
  [ -n "$entry" ] || { warn "unknown CLI '$name' (not in roster $ROSTER)"; continue; }
  npmpkg=$(jq -r '.npm' <<<"$entry")
  seed=$(jq -r '.config_seed // empty' <<<"$entry")
  dest=$(jq -r '.config_dest // empty' <<<"$entry")

  info "installing $name ($npmpkg) into .aihome/npm ..."
  if npm install -g "$npmpkg" >/dev/null 2>&1; then ok "$name installed"; else warn "$name install failed ($npmpkg)"; fi

  # seed workspace config, never clobbering existing (cp -n)
  if [ -n "$seed" ] && [ -d "[01] system/config-seeds/$seed" ] && [ -n "$dest" ]; then
    mkdir -p "$dest"
    cp -Rn "[01] system/config-seeds/$seed/." "$dest/" 2>/dev/null || true
    ok "$name config seeded -> $dest"
  fi

done

ok "provision complete — AI CLIs sealed under .aihome/ (host config untouched)"
info "verify with: devbox run doctor"
