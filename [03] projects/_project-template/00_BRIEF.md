# Project Brief: <project-name>

## Goal
What done looks like, in one or two sentences.

## Deliverable
Exact artifact expected, and where it lands:
- Repo-shaped work → PR into a component under `06_PRODUCT/`, then commit
  the advanced pin in the workspace
- Non-repo work → `05_FINAL/` + a copy in `[04] outputs/`

## Knowledge to load
Which `[02] knowledge/` files apply to this project:
- `how-i-work.md`
- (add specific concept files)

## Product components
Component submodules under `06_PRODUCT/` (see its README to attach).
`06_PRODUCT/` is always the container, never itself a submodule; a monorepo
is the one-component case (`main/`).

| Component | Repo URL | Work branch |
|---|---|---|
<!-- example: | main | git@forge:me/my-product.git | work/<project-name> | -->

## Constraints
- Deadline, length, format, hard requirements.

## Workflow
1. `01_SOURCES/` — raw inputs, dated (`YYYY-MM-DD_source-name_raw.md`)
2. `02_NOTES/` — synthesis and thinking
3. `03_DRAFTS/` — dated, versioned drafts (`YYYY-MM-DD_topic_draft-v1.md`)
4. `04_VISUALS/` — images, diagrams
5. `05_FINAL/` — the finished deliverable(s)
6. `06_PRODUCT/` — component submodules (work branch + PR only, per component)
