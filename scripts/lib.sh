#!/usr/bin/env bash
# Shared helpers for workspace scripts (vendor-neutral — no AI-CLI specifics).

ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# has_line PATTERN  — reads stdin, true if an exact line matches
has_line() { grep -qxF "$1"; }
