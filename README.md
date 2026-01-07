# wegent-agent-kit

这个仓库用于给 **Wegent** 的开发环境做“一键初始化”：

- **Codex CLI**：同步本仓库(宿主项目)的 `.codex/skills` / `.codex/prompts` 到本机 `$CODEX_HOME`（默认 `~/.codex`），并补齐常用 MCP server 配置。
- **Claude Code**：安装一个本地 marketplace + plugin（含 MCP 配置、skills、slash commands）。

> 约定：不写入任何密钥/令牌；需要鉴权的 MCP 统一通过环境变量注入。

## 快速开始（Windows / PowerShell）

在 Wegent 仓库根目录执行：

```powershell
pwsh -File tools/wegent-agent-kit/scripts/install.ps1 -Mode both
```

只做项目级（Claude MCP 配置）：

```powershell
pwsh -File tools/wegent-agent-kit/scripts/install.ps1 -Mode project
```

只做主机级（Codex 同步 + Codex MCP + Claude plugin 安装）：

```powershell
pwsh -File tools/wegent-agent-kit/scripts/install.ps1 -Mode host
```

## macOS / Linux

```bash
./tools/wegent-agent-kit/scripts/install.sh both
```

## Claude Code：插件内容

Marketplace：`wegent-agent-kit`  
Plugin：`wegent-devkit`

插件提供：
- MCP：`playwright`、`context7`
- Skills：贡献规范/测试命令/分支策略等速查
- Commands：`/wegent-help`

## Codex：同步与 MCP

脚本会从 **宿主项目**（即包含该 submodule 的仓库）读取 `.codex/skills` 与 `.codex/prompts`，并同步到用户目录：
- skills：按目录名原样同步（例如 `wegent-task-inspect`）
- prompts：默认加前缀 `wegent_`（避免与其他项目 prompt 重名）

并尝试在 `~/.codex/config.toml` 追加缺失的 MCP servers：
- `chrome-devtools`
- `playwright`
- `context7`


