#!/usr/bin/env bash
# bridge — inspect or override the host credentials bridged into the sealed HOME.
#
#   devbox run bridge                       # what is bridged, and what still blocks a push
#   devbox run bridge refresh               # re-run the auto-bridge now
#   devbox run bridge git-identity [N] [E]  # set identity explicitly (host has none)
#   devbox run bridge gh                    # interactive gh login, inside the workspace
#   devbox run bridge ssh-key <path>        # link ONE key (narrower than the 'ssh' bridge)
#
# Normal operation needs none of this: scripts/seal-home.sh applies the bridges
# declared in [01] system/bridges.json on every sealed launch. This verb exists
# for inspection, for credentials the host does not have to give, and for
# narrowing the default (e.g. one key instead of all of ~/.ssh).
#
# Must run sealed — it operates on the sealed home, not yours. 'devbox run
# bridge' routes through scripts/sealed-exec.sh; invoked directly it will refuse.
#
# The rule (SYSTEM-RULES Rule 8): bridge the CREDENTIAL, never exempt the PROGRAM.
# Exempting a program leaks to everything it spawns — the AI runs git, git runs
# ssh and credential helpers — so an "exempt" git is a door to the whole host.
set -uo pipefail
cd "${WORKSPACE_ROOT:-$PWD}"
source scripts/lib.sh

[ -n "${HOME:-}" ] || fail "HOME unset — re-enter the devbox shell"
case "$HOME" in
  "${WORKSPACE_ROOT:-$PWD}"/*) ;;
  *) fail "HOME is not sealed (got '$HOME') — re-enter the devbox shell before bridging" ;;
esac

BRIDGES="[01] system/bridges.json"
host_home="${HOST_HOME:-}"
what="${1:-list}"

case "$what" in
  list)
    info "sealed HOME: $HOME"
    info "host   HOME: ${host_home:-<not captured>}"
    if [ -f "$BRIDGES" ]; then
      info "policy: $BRIDGES"
      jq -r '.auto | to_entries[] | "    \(.key): \(if .value then "auto" else "off" end)"' "$BRIDGES" 2>/dev/null
    fi
    echo

    name=$(git config --global --get user.name 2>/dev/null || true)
    mail=$(git config --global --get user.email 2>/dev/null || true)
    if [ -n "$name$mail" ]; then ok "git identity: ${name:-?} <${mail:-?}>"
    else warn "git identity: none (host has none to bridge) — commits use git's auto-detected user@host"; fi

    if gh auth status >/dev/null 2>&1; then ok "gh: authenticated — HTTPS pushes will work"
    else warn "gh: not authenticated — HTTPS pushes will FAIL (run: devbox run bridge gh)"; fi

    if [ -L "$HOME/.ssh" ]; then ok "ssh: host ~/.ssh bridged (keys on disk usable)"
    elif [ -d "$HOME/.ssh" ]; then
      find "$HOME/.ssh" -maxdepth 1 -type l 2>/dev/null | while read -r k; do info "ssh: bridged key $(basename "$k")"; done
    else warn "ssh: no keys bridged"; fi

    if [ -S "${SSH_AUTH_SOCK:-}" ]; then
      case "$(ssh-add -l 2>&1)" in
        *"no identities"*) warn "ssh-agent: reachable but holds no keys ('ssh-add' on the host to use keys without exposing them)" ;;
        *) ok "ssh-agent: reachable with keys — SSH pushes will work" ;;
      esac
    else
      warn "ssh-agent: no socket"
    fi
    ;;

  refresh)
    rm -f "$HOME/.bridged"
    scripts/seal-home.sh
    ok "auto-bridge re-run"
    exec "$0" list
    ;;

  git-identity)
    name="${2:-}"; mail="${3:-}"
    if [ -z "$name" ] && [ -n "$host_home" ] && [ -f "$host_home/.gitconfig" ]; then
      name=$(git config -f "$host_home/.gitconfig" --get user.name 2>/dev/null || true)
      mail=$(git config -f "$host_home/.gitconfig" --get user.email 2>/dev/null || true)
      [ -n "$name$mail" ] && info "reading identity from host $host_home/.gitconfig"
    fi
    [ -n "$name" ] || fail "host has no git identity to bridge — pass it: devbox run bridge git-identity \"Your Name\" \"you@example.com\""
    git config --global user.name "$name"
    [ -n "$mail" ] && git config --global user.email "$mail"
    ok "git identity: $name <${mail:-unset}>"
    ;;

  gh)
    ghdir="${XDG_CONFIG_HOME:-$HOME/.config}/gh"
    if [ -L "$ghdir/hosts.yml" ]; then
      warn "gh config is a symlink to the host — logging in here will also authenticate the host's gh"
      info "to keep them separate: rm '$ghdir/hosts.yml', set \"gh\": false in $BRIDGES, then re-run"
    fi
    info "authenticating gh inside the workspace (config -> $ghdir)"
    gh auth login || fail "gh auth login failed"
    ok "gh authenticated — HTTPS pushes will now work"
    ;;

  ssh-key)
    key="${2:-}"
    [ -n "$key" ] || fail "usage: devbox run bridge ssh-key <path-to-private-key>"
    [ -f "$key" ] || fail "no such key: $key"
    [ -L "$HOME/.ssh" ] && fail "all of ~/.ssh is already bridged — set \"ssh\": false in $BRIDGES first, then link one key"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ln -sf "$key" "$HOME/.ssh/$(basename "$key")"
    [ -f "$key.pub" ] && ln -sf "$key.pub" "$HOME/.ssh/$(basename "$key").pub"
    ok "bridged key: $(basename "$key")"
    info "narrower still: 'ssh-add $key' on the host — the agent lets the workspace USE a key without READING it"
    ;;

  *)
    fail "unknown bridge '$what' (want: list | refresh | git-identity | gh | ssh-key)"
    ;;
esac
