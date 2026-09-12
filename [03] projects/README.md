# [03] projects — how to start one

1. Copy `_project-template/` to a descriptive kebab-case name in this folder.
2. Fill in the copy's `00_BRIEF.md` (goal, deliverable, knowledge to load,
   component table). Delete nothing else — the numbered dirs are the workflow.
3. Attach product components per `06_PRODUCT/README.md` (forge repo with an
   initial commit, then `git submodule add`).
4. Work: `01_SOURCES` → `02_NOTES` → `03_DRAFTS` → `04_VISUALS`; repo-shaped
   results go through component PRs, then commit the advanced pin in the
   workspace.
5. Retire with `devbox run archive <project>` — never plain-`mv`.

`_project-template/` itself is scaffolding: never work inside it.
