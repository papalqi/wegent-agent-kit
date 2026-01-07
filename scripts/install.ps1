param(
  [ValidateSet('both', 'host', 'project')]
  [string]$Mode = 'both',

  [ValidateSet('user', 'project', 'local')]
  [string]$ClaudePluginScope = 'user',

  [ValidateSet('user', 'project', 'local')]
  [string]$ClaudeMcpScope = 'project',

  [string]$ProjectRoot,

  [string]$CodexHome,

  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step {
  param([Parameter(Mandatory)] [string]$Message)
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Warn {
  param([Parameter(Mandatory)] [string]$Message)
  Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Resolve-PathSafe {
  param([Parameter(Mandatory)] [string]$Path)
  try {
    return (Resolve-Path -LiteralPath $Path).Path
  } catch {
    return $null
  }
}

function Get-SuperProjectRoot {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { return $null }

  $cwd = Get-Location
  try {
    $root = (git rev-parse --show-superproject-working-tree 2>$null).Trim()
    if ($root) { return $root }
  } catch {}
  try {
    $root = (git rev-parse --show-toplevel 2>$null).Trim()
    if ($root) { return $root }
  } catch {}
  return $cwd.Path
}

function Ensure-Dir {
  param([Parameter(Mandatory)] [string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Copy-FileIfNeeded {
  param(
    [Parameter(Mandatory)] [string]$Source,
    [Parameter(Mandatory)] [string]$Destination,
    [switch]$ForceCopy
  )

  if (-not (Test-Path -LiteralPath $Destination)) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return $true
  }

  if ($ForceCopy) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return $true
  }

  $srcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
  $dstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash
  if ($srcHash -ne $dstHash) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return $true
  }

  return $false
}

function Copy-Tree {
  param(
    [Parameter(Mandatory)] [string]$SourceDir,
    [Parameter(Mandatory)] [string]$DestinationDir,
    [string]$FileNamePrefix = '',
    [switch]$ForceCopy
  )

  if (-not (Test-Path -LiteralPath $SourceDir)) { return }
  Ensure-Dir $DestinationDir

  Get-ChildItem -LiteralPath $SourceDir -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/')

    $targetRelative = $relative
    if ($FileNamePrefix) {
      $leaf = Split-Path -Leaf $relative
      $dir = Split-Path -Parent $relative
      $prefixedLeaf = "$FileNamePrefix$leaf"
      $targetRelative = if ($dir) { Join-Path $dir $prefixedLeaf } else { $prefixedLeaf }
    }

    $dest = Join-Path $DestinationDir $targetRelative
    Ensure-Dir (Split-Path -Parent $dest)
    [void](Copy-FileIfNeeded -Source $_.FullName -Destination $dest -ForceCopy:$ForceCopy)
  }
}

function Ensure-CodexMcpServers {
  param(
    [Parameter(Mandatory)] [string]$CodexConfigPath
  )

  if (-not (Test-Path -LiteralPath $CodexConfigPath)) {
    Write-Warn "Codex config not found: $CodexConfigPath (skip MCP patch)"
    return
  }

  $npx = Get-Command npx -ErrorAction SilentlyContinue
  if (-not $npx) {
    Write-Warn "npx not found in PATH (skip Codex MCP servers)"
    return
  }

  $npxPath = $npx.Source
  $content = Get-Content -LiteralPath $CodexConfigPath -Raw

  $servers = @(
    @{
      Name = 'chrome-devtools'
      Snippet = @"

[mcp_servers.chrome-devtools]
command = '$npxPath'
args = ["-y", "chrome-devtools-mcp@latest"]
"@
    },
    @{
      Name = 'playwright'
      Snippet = @"

[mcp_servers.playwright]
command = '$npxPath'
args = ["-y", "@playwright/mcp@latest"]
"@
    },
    @{
      Name = 'context7'
      Snippet = @"

[mcp_servers.context7]
command = '$npxPath'
args = ["-y", "@upstash/context7-mcp"]
"@
    }
  )

  $changed = $false
  foreach ($server in $servers) {
    $header = "[mcp_servers.$($server.Name)]"
    if ($content -match [regex]::Escape($header)) {
      continue
    }

    $content += $server.Snippet
    $changed = $true
  }

  if (-not $changed) { return }

  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item -LiteralPath $CodexConfigPath -Destination "$CodexConfigPath.bak.$timestamp" -Force
  Set-Content -LiteralPath $CodexConfigPath -Value $content -Encoding UTF8
  Write-Step "Patched Codex MCP servers in: $CodexConfigPath"
}

if (-not $ProjectRoot) {
  $ProjectRoot = Get-SuperProjectRoot
}

$resolvedProjectRoot = Resolve-PathSafe $ProjectRoot
if (-not $resolvedProjectRoot) {
  throw "Project root not found: $ProjectRoot"
}
$ProjectRoot = $resolvedProjectRoot

if (-not $CodexHome) {
  $CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
}

$claude = Get-Command claude -ErrorAction SilentlyContinue

Write-Step "Mode: $Mode"
Write-Step "ProjectRoot: $ProjectRoot"
Write-Step "CodexHome: $CodexHome"

if ($Mode -in @('both', 'host')) {
  $projectCodex = Join-Path $ProjectRoot '.codex'
  if (Test-Path -LiteralPath $projectCodex) {
    Write-Step "Sync Codex skills/prompts from: $projectCodex"

    $srcSkills = Join-Path $projectCodex 'skills'
    $dstSkills = Join-Path $CodexHome 'skills'
    if (Test-Path -LiteralPath $srcSkills) {
      Copy-Tree -SourceDir $srcSkills -DestinationDir $dstSkills -ForceCopy:$Force
    } else {
      Write-Warn "No .codex/skills in project (skip)"
    }

    $srcPrompts = Join-Path $projectCodex 'prompts'
    $dstPrompts = Join-Path $CodexHome 'prompts'
    if (Test-Path -LiteralPath $srcPrompts) {
      Copy-Tree -SourceDir $srcPrompts -DestinationDir $dstPrompts -FileNamePrefix 'wegent_' -ForceCopy:$Force
    } else {
      Write-Warn "No .codex/prompts in project (skip)"
    }
  } else {
    Write-Warn "Project .codex directory not found at $projectCodex (skip Codex sync)"
  }

  Ensure-Dir $CodexHome
  $codexConfig = Join-Path $CodexHome 'config.toml'
  Ensure-CodexMcpServers -CodexConfigPath $codexConfig

  if ($claude) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $marketplaceJson = Join-Path $repoRoot '.claude-plugin\\marketplace.json'
    if (-not (Test-Path -LiteralPath $marketplaceJson)) {
      Write-Warn "Claude marketplace.json not found at $marketplaceJson (skip plugin install)"
    } else {
      $marketplace = Get-Content -LiteralPath $marketplaceJson -Raw | ConvertFrom-Json
      $marketplaceName = $marketplace.name
      if (-not $marketplaceName) { throw "Invalid marketplace.json: missing name" }

      $existing = (claude plugin marketplace list) | Out-String
      if ($existing -notmatch [regex]::Escape($marketplaceName)) {
        Write-Step "Add Claude marketplace: $marketplaceName"
        Push-Location $repoRoot
        try {
          claude plugin marketplace add ./ | Out-Null
        } finally {
          Pop-Location
        }
      }

      Write-Step "Install Claude plugin: wegent-devkit@$marketplaceName (scope=$ClaudePluginScope)"
      try {
        claude plugin install --scope $ClaudePluginScope "wegent-devkit@$marketplaceName" | Out-Null
      } catch {
        Write-Warn "Claude plugin install failed (maybe already installed): $($_.Exception.Message)"
      }
    }
  } else {
    Write-Warn "claude command not found (skip Claude plugin install)"
  }
}

if ($Mode -in @('both', 'project')) {
  if ($claude) {
    Push-Location $ProjectRoot
    try {
      $existing = (claude mcp list) | Out-String

      if ($existing -notmatch 'playwright') {
        Write-Step "Configure Claude MCP: playwright (scope=$ClaudeMcpScope)"
        claude mcp add --scope $ClaudeMcpScope playwright -- npx -y @playwright/mcp@latest | Out-Null
      }

      if ($existing -notmatch 'context7') {
        Write-Step "Configure Claude MCP: context7 (scope=$ClaudeMcpScope)"
        claude mcp add --scope $ClaudeMcpScope context7 -- npx -y @upstash/context7-mcp | Out-Null
      }
    } finally {
      Pop-Location
    }
  } else {
    Write-Warn "claude command not found (skip Claude MCP config)"
  }
}

Write-Step "Done"
