# CLAUDE.md

## Before any task

Start with `git pull` to make sure the working tree is up to date.

Read `README.md` first. It has the project layout, controls, and PRD roadmap — don't guess at any of that from memory.

## Shell usage

Avoid `cd`. Each `cd` prefixed onto a command requires separate authorization and pollutes the permission prompt. Run commands from the repo root using relative or absolute paths instead, or use `make` targets. Only use `cd` when a tool genuinely requires a different working directory for the whole command, and even then keep it to a single command.

## Makefile

Use the `Makefile` targets for testing, running, and building rather than invoking the underlying tools directly. Check the `Makefile` for the current list of targets before reaching for a raw command.
