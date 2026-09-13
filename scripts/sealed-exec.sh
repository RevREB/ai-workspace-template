#!/usr/bin/env bash
# sealed-exec — run a command with HOME and all config redirected into .aihome/.
#
#   scripts/sealed-exec.sh <command> [args...]
#
# This is where host-isolation lives. It is deliberately NOT in devbox.json's
# env: that would seal the ambient shell too, so merely `cd`-ing into the
# workspace (direnv) would take away the human's own git identity, credentials
# and ~/.zshrc. The devbox shell provides the TOOLCHAIN; this wrapper provides
# the ISOLATION, and only to what it launches.
#
# Sealing here still covers everything that matters: the AI CLI and every
# process it spawns inherit this environment, so an agent cannot reach host
# config even by shelling out.
#
# Portability: `env`-style export + exec is POSIX and behaves identically on
# macOS and Linux. Nothing here branches on platform.
set -u

# Resolve the workspace root from this script's own location, so the wrapper
# works when invoked directly (outside the devbox shell) too. Do NOT cd — the
# launched tool must keep the caller's working directory.
self=$0
case "$self" in */*) here=${self%/*} ;; *) here=. ;; esac
ROOT=$(cd "$here/.." && pwd)

[ $# -gt 0 ] || { echo "usage: sealed-exec.sh <command> [args...]" >&2; exit 64; }

export WORKSPACE_ROOT="$ROOT"
export HOST_HOME="$HOME"          # captured before the override, for bridges
export AI_HOME="$ROOT/.aihome"

# The lever: every tool that hardcodes ~/.foo now lands inside the workspace,
# including tools not installed yet. The redirects below are belt-and-braces for
# tools that honor them, and keep the existing .aihome layout stable.
export HOME="$ROOT/.aihome/home"
export XDG_CONFIG_HOME="$ROOT/.aihome/config"
export XDG_DATA_HOME="$ROOT/.aihome/data"
export XDG_STATE_HOME="$ROOT/.aihome/state"
export XDG_CACHE_HOME="$ROOT/.cache"

# git: never read the host's global/system config — it can point git at host
# binaries via credential.helper / core.sshCommand. GIT_CONFIG_SYSTEM=/dev/null
# also drops the platform system config (macOS ships an osxkeychain helper with
# no Linux equivalent), so behaviour matches on both OSes.
export GIT_CONFIG_GLOBAL="$ROOT/.aihome/home/.gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null

export NPM_CONFIG_PREFIX="$ROOT/.aihome/npm"
export NPM_CONFIG_USERCONFIG="$ROOT/.aihome/home/.npmrc"

export CLAUDE_CONFIG_DIR="$ROOT/.aihome/config/claude"
export OPENCODE_CONFIG="$ROOT/.aihome/config/opencode/opencode.json"
export OPENCODE_CONFIG_DIR="$ROOT/.aihome/config/opencode"
# OpenCode does not honor the AGENTS.md host-fallback rule on its own; without
# these it reads the host ~/.claude prompt and skills.
export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1

[ -f "$ROOT/.aihome/config/opencode/mininet-ca.pem" ] \
  && export NODE_EXTRA_CA_CERTS="$ROOT/.aihome/config/opencode/mininet-ca.pem"

# Create + auto-bridge the sealed home (fast path is ~10ms after first run).
"$ROOT/scripts/seal-home.sh" || true

exec "$@"
