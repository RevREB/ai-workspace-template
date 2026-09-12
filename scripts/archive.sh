#!/usr/bin/env bash
# archive — retire a completed project into [99] archive/ safely.
#
#   devbox run archive <project-name>
#
# NEVER plain-'mv' a project that has component submodules: it breaks the
# worktree link, leaves stale .gitmodules entries that kill
# 'git submodule update --init' on every fresh clone, and makes
# 'git add -A' fatal. This script does it properly: records final pins in
# ARCHIVED.md, detaches each component (deinit + git rm + module prune),
# then git-mv's the project folder into [99] archive/ and stages it all.
# Provenance survives: pre-archive workspace commits still hold the live
# pins, and ARCHIVED.md holds URL+SHA for manual fetch.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

# Remove a [submodule "<name>"] ... block from a config-format file by exact
# header match. Needed because git's own tooling cannot address subsection
# names that start with '[' (which ours do when a submodule name inherited
# the bracketed path). Used on .gitmodules AND .git/config — deinit leaves
# stale url/active entries behind for such names.
strip_config_section() {
  local file="$1" name="$2" tmp
  [ -f "$file" ] || return 0
  tmp=$(mktemp)
  awk -v hdr="[submodule \"$name\"]" '
    $0 == hdr { skip=1; next }
    /^\[/    { skip=0 }
    !skip     { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file" && chmod 644 "$file"
}

project="${1:-}"
[ -n "$project" ] || fail "usage: archive <project-name>"
[[ "$project" =~ ^[A-Za-z0-9._-]+$ ]] || fail "project name must match [A-Za-z0-9._-]+"

proj_dir="[03] projects/$project"
dest="[99] archive/$project"
[ -d "$proj_dir" ] || fail "no such project: $proj_dir"
if [ -e "$dest" ]; then
  fail "already exists: $dest"
fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "workspace is not a git repo — nothing to archive safely (run 'git init' + see README)"

note="$proj_dir/ARCHIVED.md"
{
  echo "# Archived: $project ($(date +%F))"
  echo
  echo "Final component pins at archive time. To reconstruct: check out a"
  echo "pre-archive workspace commit (pins were live there), or fetch each"
  echo "repo at the recorded SHA."
  echo
  echo "| Component | Repo | Final commit |"
  echo "|---|---|---|"
} > "$note"

# Detach every component submodule registered under this project.
detached=0
if [ -f .gitmodules ]; then
  # -z: NUL-delimited "key\nvalue" records — our submodule names contain
  # spaces, so space-separated --get-regexp output is unparseable.
  while IFS= read -r -d '' rec; do
    key=${rec%%$'\n'*}
    path=${rec#*$'\n'}
    case "$path" in "$proj_dir/06_PRODUCT/"*) ;; *) continue ;; esac
    sec=${key#submodule.}; sec=${sec%.path}
    comp=$(basename "$path")
    case "$sec$comp" in
      *'"'*|*'\'*) fail "component name '$comp' (submodule '$sec') contains a quote or backslash — rename it before archiving (git escapes these in config headers and safe removal cannot be guaranteed)" ;;
    esac
    sha=$(git ls-files -s -- ":(literal)$path" | awk '{print $2}')
    url=$(git config -f .gitmodules --get "submodule.$sec.url" 2>/dev/null || echo "?")
    echo "| $comp | $url | ${sha:-unpinned} |" >> "$note"
    git submodule deinit -f -- ":(literal)$path" >/dev/null 2>&1 || true
    if [ -n "$sha" ]; then
      git rm -q -f -- ":(literal)$path"
    else
      # registered but never pinned — no index entry for git rm to remove
      rm -rf "$path"
      warn "component '$comp' was registered but never pinned — removed its directory; nothing was in the index"
    fi
    rm -rf ".git/modules/$sec"
    strip_config_section .gitmodules "$sec"
    strip_config_section .git/config "$sec"
    git add -- ":(literal).gitmodules"   # stage now, or the next git rm refuses
    detached=$((detached+1))
    ok "component '$comp' detached (final pin ${sha:-none} recorded in ARCHIVED.md)"
  done < <(git config -f .gitmodules -z --get-regexp '^submodule\..*\.path$' || true)
fi
[ "$detached" -eq 0 ] && echo "note: no component submodules were registered for this project"
if [ "$detached" -gt 0 ] && [ -f .gitmodules ]; then
  if git config -f .gitmodules --get-regexp '^submodule\.' >/dev/null 2>&1; then
    git add -- ":(literal).gitmodules"
  else
    git rm -q -f .gitmodules   # last submodule gone — drop the empty file
  fi
fi

git add -- ":(literal)$note"
git mv "$proj_dir" "$dest" \
  || fail "git mv failed — is the project tracked? ('git add' it, commit, then archive)"
ok "project moved to $dest"
echo "archive: $project staged — commit the workspace to seal it"
