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
# Checked by CONTAINMENT, never by exact path: macOS tools write to
# ~/Library/Application Support/... and Linux tools to ~/.config/... — both land
# inside the sealed HOME, at different paths. Asserting literal paths would pass
# on one OS and fail on the other.
case "${HOME:-}" in
  "$PWD"/*) ok "HOME sealed to workspace — tools that hardcode ~/ land inside" ;;
  *) warn "HOME NOT sealed (got '${HOME:-unset}') — every tool that hardcodes ~/ reads the host; re-enter the devbox shell"; rc=1 ;;
esac
for v in AI_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME CLAUDE_CONFIG_DIR OPENCODE_CONFIG_DIR GIT_CONFIG_GLOBAL NPM_CONFIG_PREFIX NPM_CONFIG_USERCONFIG; do
  val=${!v:-}
  case "$val" in
    "$PWD"/*) ok "$v workspace-local" ;;
    "") warn "$v unset"; rc=1 ;;
    *) warn "$v escapes the workspace ('$val')"; rc=1 ;;
  esac
done
if [ -f AGENTS.md ]; then ok "AGENTS.md present (AGENTS.md-aware CLIs won't fall back to host ~/.claude)"; else warn "AGENTS.md missing — CLIs may inherit host config"; rc=1; fi

# --- leak probes: ask the tools themselves, don't trust the env vars --------
# git is the highest-value probe: the AI runs git, and a host gitconfig can point
# git at host binaries via credential.helper / core.sshCommand.
leaks=$(git config --list --show-origin --show-scope 2>/dev/null \
        | awk -F'\t' '$1!="local" && $1!="worktree" {print $2}' \
        | sed 's/^file://' | sort -u \
        | grep -vE "^($PWD/|/dev/null$)" || true)
if [ -z "$leaks" ]; then
  ok "git reads no config outside the workspace"
else
  warn "git is reading host config (these can run host binaries via credential.helper / core.sshCommand):"
  printf '%s\n' "$leaks" | sed 's/^/      /' >&2
  rc=1
fi
npmrc=$(npm config get userconfig 2>/dev/null || true)
case "$npmrc" in
  "$PWD"/*) ok "npm reads workspace .npmrc" ;;
  *) warn "npm reads host userconfig ('$npmrc')"; rc=1 ;;
esac

# --- bridges: what host access was granted ON PURPOSE -----------------------
# Applied automatically on shell entry per [01] system/bridges.json. Advisory
# only (never rc=1): a credential the host does not have is not a fault here —
# but it IS why a push will fail, so say so plainly.
if [ -f "[01] system/bridges.json" ]; then
  offs=$(jq -r '.auto | to_entries[] | select(.value != true) | .key' "[01] system/bridges.json" 2>/dev/null | tr '\n' ' ')
  [ -n "${offs// /}" ] && info "bridge policy: disabled by config -> $offs"
fi
if [ -n "$(git config --global --get user.name 2>/dev/null)$(git config --global --get user.email 2>/dev/null)" ]; then
  ok "bridge: git identity ($(git config --global --get user.name 2>/dev/null || echo '?') <$(git config --global --get user.email 2>/dev/null || echo '?')>)"
else
  warn "bridge: no git identity — the host has none to bridge; commits use git's auto-detected user@host (set one: 'devbox run bridge git-identity \"Name\" \"email\"')"
fi
if gh auth status >/dev/null 2>&1; then
  ok "bridge: gh authenticated (HTTPS remotes will push)"
else
  warn "bridge: gh not authenticated — HTTPS remotes will FAIL to push; nothing on the host to bridge, so log in once: 'devbox run bridge gh'"
fi
if [ -L "$HOME/.ssh" ] || [ -d "$HOME/.ssh" ]; then
  ok "bridge: ssh keys reachable ($([ -L "$HOME/.ssh" ] && echo 'host ~/.ssh bridged' || echo 'individual keys linked'))"
else
  warn "bridge: no ssh keys bridged — SSH remotes will FAIL"
fi
if [ -S "${SSH_AUTH_SOCK:-}" ]; then
  if ssh-add -l >/dev/null 2>&1; then ok "bridge: ssh-agent reachable with keys (preferred — uses a key without reading it)"
  else info "bridge: ssh-agent reachable but empty — 'ssh-add' on the host is narrower than the ~/.ssh bridge"; fi
else
  info "bridge: no ssh-agent socket (relying on bridged key files)"
fi

# --- cross-platform parity: userland must come from devbox, not the host ----
missing=""
for p in coreutils gnused gnugrep findutils gawk bash gh; do
  jq -e --arg p "$p" '.packages[] | select(startswith($p))' devbox.json >/dev/null 2>&1 || missing="$missing $p"
done
if [ -z "$missing" ]; then
  ok "GNU userland + gh declared in devbox.json (scripts behave the same on macOS and Linux)"
else
  warn "undeclared packages:$missing — scripts may use host BSD tools on macOS and GNU on Linux"; rc=1
fi

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

# --- documentation currency (write-back discipline, SYSTEM-RULES Rule 9) ---
if git rev-parse --git-dir >/dev/null 2>&1; then
  # (a) stale docs: a last_verified date older than 30 days
  cutoff=$(date -v-30d +%F 2>/dev/null || date -d '30 days ago' +%F 2>/dev/null || echo "")
  if [ -n "$cutoff" ]; then
    stale=0
    while IFS= read -r f; do
      lv=$(grep -m1 -iE '^last[_ -]?verified:' "$f" 2>/dev/null | sed -E 's/^[^:]*:[[:space:]]*//; s/[]["'"'"' ]//g')
      if [ -n "$lv" ] && [[ "$lv" < "$cutoff" ]]; then warn "stale doc (verified $lv < $cutoff, >30d): $f"; stale=1; fi
    done < <(find "[02] knowledge" "[03] projects" -type f -name '*.md' 2>/dev/null | grep -iE 'knowledge/|ARCHITECTURE|00_BRIEF')
    [ "$stale" -eq 0 ] && ok "docs within currency window (last_verified <= 30d)"
  fi
  # (b) unreviewed-approved tripwire: uncommitted knowledge already marked approved
  while IFS= read -r f; do
    if grep -qiE '^status:[[:space:]]*approved' "$f" 2>/dev/null && [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]; then
      warn "uncommitted knowledge marked status:approved ($f) — approval is a human act (Rule 3); review before committing"
    fi
  done < <(find "[02] knowledge" -type f -name '*.md' ! -name '_TEMPLATE.md' 2>/dev/null)
  # (c) projects with components should keep a decision log
  for pj in "[03] projects/"*/; do
    [ -d "${pj}06_PRODUCT" ] || continue
    case "$pj" in *_project-template/*) continue;; esac
    if [ -f "${pj}02_NOTES/CHANGELOG.md" ]; then ok "changelog present: ${pj}02_NOTES/CHANGELOG.md"
    else warn "no 02_NOTES/CHANGELOG.md in ${pj} — log material changes there (Rule 9)"; fi
  done
fi

if [ $rc -eq 0 ]; then ok "doctor: all green"; else warn "doctor: issues above"; fi
exit $rc
