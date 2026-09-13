#!/usr/bin/env bash
# Create the sealed home and auto-bridge the host credentials declared in
# [01] system/bridges.json. Called by scripts/sealed-exec.sh on EVERY sealed
# launch — never from the devbox init_hook, which would seal the human's shell.
#
# Why HOME: XDG_* and per-CLI *_CONFIG_DIR only redirect tools that agreed to
# honor them. Moving $HOME captures EVERY tool — including ones that hardcode
# ~/.foo and ones not installed yet — with one lever instead of a growing list
# of per-tool escape hatches. See SYSTEM-RULES.md Rule 8.
#
# Why auto-bridge: a sealed home has no credentials, and a workspace you must
# remember to unlock is the same fight in a different shape. Credentials are
# CAPABILITY, not CONTEXT — bridging them back does not make the next agent
# confidently wrong, which is what host *config* leaking in would do.
#
# Portability: every source path is $HOST_HOME-relative and identical on macOS
# and Linux. No uname branching, no platform-specific secret store (git's
# osxkeychain helper has no Linux equivalent and is deliberately unused).
#
# Constraints: must be fast (runs on every `devbox run`), idempotent, and must
# never fail the shell — so no `set -e`, and every step tolerates failure.
set -u

[ -n "${HOME:-}" ] || exit 0
mkdir -p "$HOME" 2>/dev/null || exit 0

ROOT="${WORKSPACE_ROOT:-$PWD}"
BRIDGES="$ROOT/[01] system/bridges.json"
gitconfig="$HOME/.gitconfig"
marker="$HOME/.bridged"

# --- 1. seed the sealed gitconfig -------------------------------------------
# GIT_CONFIG_SYSTEM=/dev/null excludes the platform's system gitconfig, so the
# credential helper is chosen here, explicitly, and is the same on both OSes.
if [ ! -f "$gitconfig" ]; then
  cat > "$gitconfig" <<'EOF'
# Sealed workspace git config. GIT_CONFIG_GLOBAL points here, so the host's
# ~/.gitconfig is deliberately NOT read — it can point git at host binaries via
# credential.helper / core.sshCommand. Identity is bridged from the host by
# scripts/seal-home.sh; see [01] system/bridges.json.
[credential "https://github.com"]
	helper = !gh auth git-credential
[init]
	defaultBranch = main
EOF
fi

# --- 2. fast path -----------------------------------------------------------
# Pure shell tests, no subprocesses: re-bridge only when the policy or the host
# identity file is newer than the last run.
if [ -f "$marker" ] \
   && [ ! "$BRIDGES" -nt "$marker" ] \
   && [ ! "${HOST_HOME:-/nonexistent}/.gitconfig" -nt "$marker" ]; then
  exit 0
fi

[ -n "${HOST_HOME:-}" ] && [ -d "${HOST_HOME:-}" ] || { : > "$marker" 2>/dev/null; exit 0; }
[ -f "$BRIDGES" ] && command -v jq >/dev/null 2>&1 || { : > "$marker" 2>/dev/null; exit 0; }

enabled() { jq -e --arg k "$1" '.auto[$k] == true' "$BRIDGES" >/dev/null 2>&1; }
applied=""

# --- 3. git identity (name + email ONLY, never the whole host file) ----------
if enabled git-identity && [ -f "$HOST_HOME/.gitconfig" ]; then
  if ! git config --global --get user.email >/dev/null 2>&1; then
    n=$(git config -f "$HOST_HOME/.gitconfig" --get user.name 2>/dev/null)
    e=$(git config -f "$HOST_HOME/.gitconfig" --get user.email 2>/dev/null)
    [ -n "$n" ] && git config --global user.name "$n" 2>/dev/null && applied="$applied git-identity"
    [ -n "$e" ] && git config --global user.email "$e" 2>/dev/null
  fi
fi

# --- 4. gh auth (symlink: host re-auth propagates, copy cannot go stale) -----
# Same path on macOS and Linux — gh uses XDG on both.
if enabled gh && [ -f "$HOST_HOME/.config/gh/hosts.yml" ]; then
  ghdir="${XDG_CONFIG_HOME:-$HOME/.config}/gh"
  if [ ! -L "$ghdir/hosts.yml" ]; then
    mkdir -p "$ghdir" 2>/dev/null \
      && ln -sfn "$HOST_HOME/.config/gh/hosts.yml" "$ghdir/hosts.yml" 2>/dev/null \
      && applied="$applied gh"
  fi
fi

# --- 5. ssh (symlink the dir; keeps keys, config and known_hosts consistent) -
if enabled ssh && [ -d "$HOST_HOME/.ssh" ]; then
  if [ ! -e "$HOME/.ssh" ]; then
    ln -sfn "$HOST_HOME/.ssh" "$HOME/.ssh" 2>/dev/null && applied="$applied ssh"
  fi
fi

: > "$marker" 2>/dev/null
[ -n "$applied" ] && printf '  bridged:%s (policy: [01] system/bridges.json)\n' "$applied"
exit 0
