# Archive — searchable, never authoritative

This folder is the workspace's probabilistic memory tier: finished projects,
old drafts, superseded notes, imported dumps (exports, transcripts, old wikis).

Rules (from `[01] system/SYSTEM-RULES.md`):

- The AI agent searches here **only after** `[02] knowledge/` and the active project
  come up empty.
- Anything found here is treated as possibly stale and labeled unverified —
  with one exception: `ARCHIVED.md` files are factual records of final
  component pins (repo + SHA); cite them as records.
- Nothing here overrides `[02] knowledge/` — a conflict gets flagged, not merged.
- Anything here that proves correct and reusable gets **promoted** to
  `[02] knowledge/` via `_TEMPLATE.md` (born `draft`; a human approves).

Projects arrive here ONLY via `devbox run archive <project>` — never a plain
`mv`. The verb detaches component submodules safely and records their final
pins in the project's `ARCHIVED.md`; a hand-move corrupts submodule state
for every clone of the workspace. To reconstruct an archived project's
product state: check out a pre-archive workspace commit, or fetch each repo
at the SHA recorded in ARCHIVED.md.

No naming discipline required inside archive — that's the point. Dump freely;
search probabilistically.
