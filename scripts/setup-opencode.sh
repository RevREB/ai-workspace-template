#!/usr/bin/env sh
# Asbru -> OpenCode setup.
#
# Configures OpenCode to use Asbru (governed: VK + guardrails + accounting) as
# its provider, with all models Meridian exposes, and a lean identity-free system
# prompt so Meridian bills to the subscription (not metered "extra usage").
#
# Run inside the workspace devbox shell — or `devbox run setup_opencode` — so the
# config lands in the sealed .aihome, never host ~/.config.
#
# Env overrides: ASBRU_URL, MODELS_URL, ASBRU_VK (skip the prompt).
set -eu

ASBRU_URL="${ASBRU_URL:-https://asbru.mininet}"
MODELS_URL="${MODELS_URL:-https://meridian.mininet/v1/models}"

command -v jq   >/dev/null 2>&1 || { echo "jq is required (add it to devbox.json)"   >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

# --- resolve the (sealed) config path from the environment -------------------
if   [ -n "${OPENCODE_CONFIG:-}" ];     then CFG="$OPENCODE_CONFIG"
elif [ -n "${OPENCODE_CONFIG_DIR:-}" ]; then CFG="$OPENCODE_CONFIG_DIR/opencode.json"
else CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
fi
CFGDIR=$(dirname "$CFG")
mkdir -p "$CFGDIR"

echo "Asbru -> OpenCode setup"
echo "  config: $CFG"
case "$CFGDIR" in
  */.aihome/*) : ;;
  *) echo "  ! not a sealed .aihome path — are you in the devbox shell? (devbox run setup_opencode)" ;;
esac

# --- CA so Node/OpenCode trusts asbru.mininet -------------------------------
CA="$CFGDIR/mininet-ca.pem"
if [ ! -f "$CA" ]; then
  if [ -f "$HOME/.config/opencode/mininet-ca.pem" ]; then
    cp "$HOME/.config/opencode/mininet-ca.pem" "$CA"
  else
    host=$(printf '%s' "$ASBRU_URL" | sed -E 's#^https?://##; s#/.*##')
    echo | openssl s_client -showcerts -connect "$host:443" 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > "$CA" || true
  fi
fi
CURL_CA=""; [ -s "$CA" ] && CURL_CA="--cacert $CA"

# --- fetch the model list ---------------------------------------------------
echo "  fetching models from $MODELS_URL ..."
MODELS_JSON=$(curl -fsS $CURL_CA "$MODELS_URL") || { echo "could not reach $MODELS_URL" >&2; exit 1; }
COUNT=$(printf '%s' "$MODELS_JSON" | jq '.data | length')
[ "${COUNT:-0}" -gt 0 ] || { echo "no models returned from $MODELS_URL" >&2; exit 1; }

# provider.models map: { "<id>": {"name":"<display>"} , ... }
MODELS_OBJ=$(printf '%s' "$MODELS_JSON" | jq '[.data[] | {key:.id, value:{name:(.display_name // .id)}}] | from_entries')
have() { printf '%s' "$MODELS_JSON" | jq -e --arg m "$1" 'any(.data[]; .id==$m)' >/dev/null 2>&1; }
DEFAULT=claude-sonnet-5; have "$DEFAULT" || DEFAULT=$(printf '%s' "$MODELS_JSON" | jq -r '.data[0].id')
SMALL=claude-haiku-4-5;  have "$SMALL"   || SMALL="$DEFAULT"

# --- prompt for the VK (works even when piped from curl) --------------------
VK="${ASBRU_VK:-}"
if [ -z "$VK" ]; then
  printf 'Paste your Asbru VK (bfk_... or sk-bf-...): '
  if [ -r /dev/tty ]; then
    stty -echo 2>/dev/null || true; read VK < /dev/tty; stty echo 2>/dev/null || true; printf '\n'
  else
    read VK
  fi
fi
[ -n "$VK" ] || { echo "no VK entered — aborting" >&2; exit 1; }
printf '%s' "$VK" > "$CFGDIR/asbru-vk"; chmod 600 "$CFGDIR/asbru-vk"

# --- lean, identity-free system prompt (the billing fix) --------------------
cat > "$CFGDIR/core.md" <<'PROMPT'
Help the user with software engineering tasks. Use the available tools to read
and edit files, run commands, search the codebase, and verify your work — prefer
acting and checking over guessing. Be concise and direct; match response length
to the task. Reference code as file_path:line. Follow the conventions of the
surrounding code. Do not add features, refactors, tests, or comments the user did
not ask for. Report outcomes honestly: if something failed or was skipped, say so.
PROMPT

# --- write opencode.json (back up any existing) -----------------------------
[ -f "$CFG" ] && cp "$CFG" "$CFG.bak"
rm -f "$CFGDIR/opencode.jsonc"   # avoid an empty .jsonc shadowing the config
jq -n \
  --argjson models "$MODELS_OBJ" \
  --arg def "asbru/$DEFAULT" --arg small "asbru/$SMALL" \
  --arg base "$ASBRU_URL/v1" \
  --arg vk "{file:$CFGDIR/asbru-vk}" --arg core "{file:$CFGDIR/core.md}" \
  '{
     "$schema":"https://opencode.ai/config.json",
     provider:{ asbru:{
       npm:"@ai-sdk/openai-compatible",
       name:"Asbru (governed: VK + guardrails + accounting)",
       options:{ baseURL:$base, apiKey:$vk },
       models:$models
     }},
     model:$def, small_model:$small,
     agent:{ build:{prompt:$core}, plan:{prompt:$core}, general:{prompt:$core}, explore:{prompt:$core} }
   }' > "$CFG"

echo "  ✓ wrote $CFG"
echo "  ✓ $COUNT models via asbru; default asbru/$DEFAULT, small asbru/$SMALL"
echo "  run: opencode"
