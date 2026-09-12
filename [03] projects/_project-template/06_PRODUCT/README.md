# 06_PRODUCT — component submodule container

The work product (code, art, creative, business) lives in its own clean
repositories, mounted here as git submodules — one per component.

**Hard rule: this directory is always a plain container. It is never itself
a submodule.** A monorepo is just the one-component case:

    06_PRODUCT/
    └── main/          ← submodule (the monorepo)

A modular codebase gets one component per repo:

    06_PRODUCT/
    ├── frontend/      ← submodule
    ├── api-spec/      ← submodule
    └── infra/         ← submodule

## Attach a component

1. Create the component repo at your forge **with an initial commit** (use
   the forge's "initialize with README" option). `git submodule add` of a
   commitless repo fails on its unborn HEAD and leaves a half-attached
   state. If that already happened: `cd` into the half-clone, commit and
   push something, `cd` back to the workspace root, and re-run the same
   `git submodule add` **in place — do not delete the directory** (git
   adopts the existing checkout; if it refuses, add `--force`).
2. From the workspace root (must be a git repo, committed):

       git submodule add --name "<project-name>/<component>" <repo-url> \
         "[03] projects/<project-name>/06_PRODUCT/<component>"

   (`--name` keeps the submodule's internal name free of the bracketed
   folder path — git tooling handles clean names much better.)

Component URLs should be real fetchable remotes — a pin other machines
cannot fetch is not provenance. Local-path URLs are additionally blocked by modern
git unless each command carries `-c protocol.file.allow=always` (e.g.
`git -c protocol.file.allow=always submodule add ...` / `... submodule
update --init`) or you set it once with
`git config --global protocol.file.allow always`; repo-local config does
NOT unblock the clone subprocess. Use local paths only for deliberate
local-only experiments, never for real product repos.

## Rules (from [01] system/SYSTEM-RULES.md, Rules 6–7)

- Component repos carry none of the workspace's cruft and never reference
  the workspace. One-way dependency.
- Work in a component happens on a work branch only; merging to its main is
  PR-only (enable branch protection at the forge).
- Pins are managed by git: commit the advanced gitlink deliberately, and
  only after the pinned commit is merged and pushed — an unpushed pin
  breaks `submodule update` on every other clone (`devbox run doctor`
  warns about those).
- Retire the whole project only via `devbox run archive <project>` — never
  plain-`mv` this directory or its parent while submodules are attached.

This README stays committed as the container's documentation.
