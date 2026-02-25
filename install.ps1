# ============================================================
# springboot-skill installer (PowerShell)
# Installs skills into AI agent directories at project or user level
# Supports: Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot
#
# Works two ways:
#   1. Local:  .\install.ps1 C:\projects\my-api
#   2. Remote: irm https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.ps1 | iex
# ============================================================

param(
    [Parameter(Position=0)]
    [string]$ProjectPath,

    [ValidateSet("claude", "codex", "gemini", "cursor", "copilot", "all")]
    [string[]]$Agent,

    [switch]$User,

    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$GitHubRepo = "https://github.com/rajeshanji8/springboot-skill.git"
$AllAgents = @("claude", "codex", "gemini", "cursor", "copilot")
$CleanupTemp = $false
$TempDir = $null

# --------------- RESOLVE SOURCE ---------------
$ScriptDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $null
}

$SourceSkillsDir = if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "skills"))) {
    Join-Path $ScriptDir "skills"
} else {
    # No local skills/ found — clone from GitHub
    Write-Host "No local skills/ directory found. Downloading from GitHub..." -ForegroundColor Yellow
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: git is required for remote install. Install git or clone the repo manually." -ForegroundColor Red
        exit 1
    }
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "springboot-skill-$(Get-Random)"
    $CleanupTemp = $true
    git clone --depth 1 --quiet $GitHubRepo $TempDir
    $ScriptDir = $TempDir
    Join-Path $TempDir "skills"
}

# Verify source
if (-not (Test-Path (Join-Path $SourceSkillsDir "spring-boot"))) {
    Write-Host "Error: skills/spring-boot not found at $SourceSkillsDir" -ForegroundColor Red
    if ($CleanupTemp -and $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
    exit 1
}

# Resolve agents
$SelectedAgents = if ($Agent) {
    if ($Agent -contains "all") { $AllAgents } else { $Agent | Sort-Object -Unique }
} else {
    $AllAgents
}

# Resolve project path
if (-not $ProjectPath) {
    $ProjectPath = Get-Location
} else {
    $ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop
}

$InstallLevel = if ($User) { "user" } else { "project" }

# --------------- MAIN ---------------
Write-Host ""
Write-Host "Spring Boot Skill Installer" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host "Source:  $ScriptDir"
Write-Host "Level:  $InstallLevel"
if (-not $User) {
    Write-Host "Project: $ProjectPath"
}
Write-Host "Agents: $($SelectedAgents -join ', ')"
Write-Host ""

foreach ($ag in $SelectedAgents) {
    # copilot uses .github directory; others use .<agent>
    $dirName = if ($ag -eq "copilot") { ".github" } else { ".$ag" }

    if ($User) {
        $agentDir = Join-Path $env:USERPROFILE $dirName
    } else {
        $agentDir = Join-Path $ProjectPath $dirName
    }

    $skillsDir = Join-Path $agentDir "skills"
    $targetDir = Join-Path $skillsDir "spring-boot"

    if ($Uninstall) {
        if (Test-Path $targetDir) {
            Remove-Item $targetDir -Recurse -Force
            Write-Host "  Removed spring-boot skill for $ag from $skillsDir" -ForegroundColor Green
        } else {
            Write-Host "  No spring-boot skill found for $ag at $skillsDir" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Installing for $ag at $InstallLevel level..."
        if (-not (Test-Path $skillsDir)) {
            New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
        }
        if (Test-Path $targetDir) {
            Remove-Item $targetDir -Recurse -Force
        }
        Copy-Item (Join-Path $SourceSkillsDir "spring-boot") $targetDir -Recurse
        Write-Host "  Installed spring-boot skill for $ag into $targetDir" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

if (-not $Uninstall) {
    Write-Host ""
    Write-Host "Installed structure:"
    Write-Host "  .<agent>/skills/spring-boot/"
    Write-Host "  ├── SKILL.md              # Entry point (agent reads this first)"
    Write-Host "  └── references/           # Detailed guides (read on demand)"
}

# Cleanup temp directory if we cloned from GitHub
if ($CleanupTemp -and $TempDir -and (Test-Path $TempDir)) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
