---
description: Wegent 开发速查（分支/测试/lint/常用命令）
argument-hint: ""
allowed-tools: [Read, Glob, Grep, Bash]
---

# Wegent 开发速查

## 分支策略（强制）

- 禁止直接推送 `main`
- 新功能：从 `develop` 拉 `feature/*`，PR 回 `develop`
- 仅修复：可直接提交到 `develop`（按团队规则执行）

## 提交前必跑

- `cd backend && uv run pytest`
- `cd executor && uv run pytest`
- `cd executor_manager && uv run pytest`
- `cd shared && uv run pytest`
- 前端有改动：`cd frontend && npm run lint`

## 常用启动

- `./start.sh --no-rag`

## 重要约束

- 对话中文；代码注释英文
- 不提交任何密钥/令牌（放 `.env` 或部署环境）

