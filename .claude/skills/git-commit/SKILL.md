---
name: git-commit
description: Clean git commit workflow — run tests, select relevant files from git status based on current work, propose a conventional commit message for confirmation, then commit. Use when the user wants to commit, says "commit", "git commit", or "commit clean".
---

# git-commit

## Workflow

### 1. Run tests
Run the project test suite. If tests fail, stop and report — do not proceed to commit.

For this project: `go test ./...`

### 2. Inspect status
Run `git status` to see all changed files. Do NOT run `git add .` or `git add -A`.

### 3. Select files
Based on the current conversation context (what was just built or fixed), select only the files that belong to this unit of work. Leave unrelated changes unstaged.

Rules:
- One commit = one intention. If files belong to different concerns, split into separate commits.
- Never stage: `.env`, secrets, generated binaries, or files unrelated to the current task.
- When unsure whether a file belongs, leave it out and mention it.

### 4. Propose and confirm
Present the proposed staging and message — then **wait for the user's go-ahead** before committing.

Format:
```
Files: handler/create.go, testdata/01_create_and_get.yaml
Message: feat: add create_adr and get_adr tools
```

Do not show file contents. The user can inspect diffs themselves.

### 5. Commit
On confirmation: `git add <files>` then commit with the agreed message.

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
