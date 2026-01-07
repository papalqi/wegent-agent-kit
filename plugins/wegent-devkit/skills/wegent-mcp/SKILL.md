---
name: wegent-mcp
description: Use this skill when the user asks to set up MCP servers for Wegent development, or when troubleshooting missing MCP tools in Claude Code/Codex (e.g., "配置 MCP", "mcp 不可用", "playwright mcp", "context7").
version: 1.0.0
---

# MCP Setup Notes

## Claude Code

This marketplace/plugin provides MCP configs via `plugins/wegent-devkit/.mcp.json`:

- `playwright` (E2E / browser automation)
- `context7` (up-to-date docs lookup)

If the user prefers explicit CLI configuration, they can add servers via:

- `claude mcp add --scope project playwright -- npx -y @playwright/mcp@latest`
- `claude mcp add --scope project context7 -- npx -y @upstash/context7-mcp`

## Codex CLI

Codex MCP servers are configured in `~/.codex/config.toml` under `[mcp_servers.*]`.
The installer script can append common servers if missing.

