#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-both}" # both | host | project

if [[ "$MODE" != "both" && "$MODE" != "host" && "$MODE" != "project" ]]; then
  echo "Usage: $0 [both|host|project]" >&2
  exit 2
fi

step() { printf "==> %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1" >&2; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

project_root="${PROJECT_ROOT:-}"
if [[ -z "$project_root" ]]; then
  if command -v git >/dev/null 2>&1; then
    project_root="$(git -C "$repo_root" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
    if [[ -z "$project_root" ]]; then
      project_root="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || true)"
    fi
  fi
fi
project_root="${project_root:-$(pwd)}"

codex_home="${CODEX_HOME:-$HOME/.codex}"

sync_codex() {
  local src="$project_root/.codex"
  if [[ ! -d "$src" ]]; then
    warn "Project .codex not found at $src (skip Codex sync)"
    return
  fi

mkdir -p "$codex_home/skills" "$codex_home/prompts"

if [[ -d "$src/skills" ]]; then
    step "Sync Codex skills from $src/skills -> $codex_home/skills"
    cp -R "$src/skills/." "$codex_home/skills/"
  else
    warn "No .codex/skills in project (skip)"
  fi

  if [[ -d "$src/prompts" ]]; then
    step "Sync Codex prompts (prefixed) from $src/prompts -> $codex_home/prompts"
    for f in "$src/prompts/"*; do
      [[ -f "$f" ]] || continue
      cp "$f" "$codex_home/prompts/wegent_$(basename "$f")"
    done
  else
    warn "No .codex/prompts in project (skip)"
  fi
}

patch_codex_mcp() {
  local cfg="$codex_home/config.toml"
  if [[ ! -f "$cfg" ]]; then
    warn "Codex config not found: $cfg (skip MCP patch)"
    return
  fi

  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found (skip Codex MCP servers)"
    return
  fi

  local changed=0
  local npx_path
  npx_path="$(command -v npx)"

  ensure_server() {
    local name="$1"
    local args="$2"
    if grep -q "\\[mcp_servers\\.${name}\\]" "$cfg"; then
      return 0
    fi
    printf "\n[mcp_servers.%s]\ncommand = '%s'\nargs = %s\n" "$name" "$npx_path" "$args" >>"$cfg"
    changed=1
  }

  ensure_server "chrome-devtools" '["-y", "chrome-devtools-mcp@latest"]'
  ensure_server "playwright" '["-y", "@playwright/mcp@latest"]'
  ensure_server "context7" '["-y", "@upstash/context7-mcp"]'

  if [[ "$changed" -eq 1 ]]; then
    step "Patched Codex MCP servers in: $cfg"
  fi
}

install_claude_plugin() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not found (skip Claude plugin)"
    return
  fi

  step "Add Claude marketplace from local path: $repo_root"
  (cd "$repo_root" && claude plugin marketplace add ./ >/dev/null 2>&1) || true

  step "Install Claude plugin: wegent-devkit@wegent-agent-kit (scope=user)"
  claude plugin install --scope user "wegent-devkit@wegent-agent-kit" >/dev/null 2>&1 || true
}

configure_claude_mcp_project() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not found (skip Claude MCP)"
    return
  fi

  step "Configure Claude MCP servers (scope=project): playwright, context7"
  (
    cd "$project_root"
    claude mcp add --scope project playwright -- npx -y @playwright/mcp@latest >/dev/null 2>&1 || true
    claude mcp add --scope project context7 -- npx -y @upstash/context7-mcp >/dev/null 2>&1 || true
  )
}

step "Mode: $MODE"
step "ProjectRoot: $project_root"
step "CodexHome: $codex_home"

if [[ "$MODE" == "both" || "$MODE" == "host" ]]; then
  sync_codex
  patch_codex_mcp
  install_claude_plugin
fi

if [[ "$MODE" == "both" || "$MODE" == "project" ]]; then
  configure_claude_mcp_project
fi

step "Done"
