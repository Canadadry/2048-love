---
name: git-commit
description: Clean git commit workflow — run tests, select relevant files from git status based on current work, propose a conventional commit message for confirmation, then commit. Use when the user wants to commit, says "commit", "git commit", or "commit clean".
---

# git-commit

## Workflow

### 1. Run tests
Run the project test suite. If tests fail, stop and report — do not proceed to commit.

For this project: `make test`

### 2. PRD graduation (if applicable)
If a PRD was just implemented, mark it done and move it out of triage:

1. Set `status: done` in the PRD frontmatter.
2. Move the file from `docs/prd/triage/` to `docs/prd/`.
3. Rename it with the next sequential number prefix: check existing files in `docs/prd/` (e.g. `001-mvp.md`, `002-slide-animation.md`) and use the next number (zero-padded to 3 digits).

Example: `docs/prd/triage/some-feature.md` → `docs/prd/003-some-feature.md`

### 3. Inspect status
Run `git status` to see all changed files. Do NOT run `git add .` or `git add -A`.

### 4. Select files
Based on the current conversation context (what was just built or fixed), select only the files that belong to this unit of work. Leave unrelated changes unstaged.

Rules:
- One commit = one intention. If files belong to different concerns, split into separate commits.
- Never stage: `.env`, secrets, generated binaries, or files unrelated to the current task.
- When unsure whether a file belongs, leave it out and mention it.

### 5. Propose and confirm
Present the proposed staging and message — then **wait for the user's go-ahead** before committing.

Format:
```
Files: handler/create.go, testdata/01_create_and_get.yaml
Message: feat: add create_adr and get_adr tools
```

Do not show file contents. The user can inspect diffs themselves.

### 6. Commit
On confirmation: `git add <files>` then commit with the agreed message.

Do NOT add `Co-Authored-By` trailers to commit messages.

## Commit message format

```
<type>: <short description>
```

| Type | When |
|------|------|
| `feat:` | New user-visible behavior |
| `fix:` | Bug correction |
| `test:` | Adding or updating tests only |
| `refactor:` | Code restructuring, no behavior change |
| `chore:` | Tooling, deps, config, CI |
| `docs:` | Documentation only |

- Subject line: 50 chars max, imperative mood ("add", not "added")
- No period at the end
- If a commit genuinely requires "and" in the message, it should be two commits
