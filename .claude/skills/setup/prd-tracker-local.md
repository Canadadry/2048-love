# Issue tracker: Local Markdown

PRDs for this repo live as flat markdown files in `docs/prd/`.

## Conventions

- New (untriaged) PRDs go in `docs/prd/triage/<slug>.md` — no number prefix, no subdirectory
- Accepted/done PRDs are numbered and moved to `docs/prd/<NNN>-<slug>.md` (e.g. `002-slide-animation.md`)
- There are no per-feature subdirectories and no separate issue files
- Triage state is recorded in the frontmatter `status:` field (see `triage-labels.md` for valid values)

## When a skill says "publish to the issue tracker"

Create a new file at `docs/prd/triage/<slug>.md` with `status: needs-triage` in the frontmatter.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the slug directly.
