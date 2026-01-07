---
name: wegent-contrib
description: Use this skill when the user is working on Wegent and mentions branching strategy, commits, tests, lint, secrets, or contributor rules (e.g., "develop 分支", "feature/*", "跑测试", "npm run lint", "不要提交 token").
version: 1.0.0
---

# Wegent Contributor Rules (Quick Card)

## Language & Style

- Talk in Chinese by default.
- Code comments must be in English.

## Branching (Mandatory)

- Never push directly to `main`.
- Feature work: branch from `develop` using `feature/*`, then open PR back to `develop`.

## Before You Commit

- Run the relevant test suite(s) for the area you changed.
- If frontend changed, run `cd frontend && npm run lint`.

## Secrets

- Never commit tokens/keys.
- Put local config in `.env` / `.env.local` or deployment secrets.

