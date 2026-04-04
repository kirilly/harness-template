# Harness

This is a personal productivity harness — a structured vault for managing projects with AI assistance.

## Structure

- `0-skills/` — Reusable knowledge documents (skills) loaded by Claude when relevant
- `1-todo/` — Planned projects (spec exists, work not started)
- `2-current/` — Active projects (work in progress)
- `3-done/` — Archived projects

## Three-File Model

Every project uses three files:

- `spec.md` — What to build (goal, deliverables, success criteria)
- `progress.md` — What happened (session logs, decisions, status)
- `validation.md` — Did it work (experiments mapped to success criteria)

Templates in `0-skills/templates/`.

## Rules

- Read spec.md before starting work on any project
- Update progress.md after each session
- Never mark an experiment PASS without concrete evidence
- Never commit secrets (.env, .age files, tokens)
