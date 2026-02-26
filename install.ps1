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
    [string[]]$Agent,  # Pass multiple: -Agent claude,codex

    [switch]$User,

    [switch]$WithInstructions,

    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$GitHubRepo = "https://github.com/rajeshanji8/springboot-skill.git"
$AllAgents = @("claude", "codex", "gemini", "cursor", "copilot")
$CleanupTemp = $false
$TempDir = $null

$MarkerStart = "<!-- springboot-skill:start -->"
$MarkerEnd = "<!-- springboot-skill:end -->"

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
        # Clean up Copilot instruction snippets/files added by -WithInstructions
        if ($ag -eq "copilot") {
            # Remove marker block from copilot-instructions.md
            $copilotInstr = Join-Path $agentDir "copilot-instructions.md"
            if ((Test-Path $copilotInstr) -and (Select-String -Path $copilotInstr -Pattern $MarkerStart -Quiet)) {
                $content = Get-Content $copilotInstr -Raw
                $pattern = "(?s)$([regex]::Escape($MarkerStart)).*?$([regex]::Escape($MarkerEnd))\r?\n?"
                $content = [regex]::Replace($content, $pattern, "")
                if ([string]::IsNullOrWhiteSpace($content)) {
                    Remove-Item $copilotInstr -Force
                    Write-Host "  Removed copilot-instructions.md (was empty after cleanup)" -ForegroundColor Green
                } else {
                    Set-Content -Path $copilotInstr -Value $content.TrimEnd() -NoNewline
                    Write-Host "  Removed spring-boot snippet from copilot-instructions.md" -ForegroundColor Green
                }
            }
            # Remove path-specific instruction files (only ours)
            $instrDir = Join-Path $agentDir "instructions"
            foreach ($fname in @("java-spring.instructions.md", "pom.instructions.md", "docker.instructions.md", "test.instructions.md", "properties.instructions.md", "liquibase.instructions.md")) {
                $f = Join-Path $instrDir $fname
                if (Test-Path $f) {
                    Remove-Item $f -Force
                    Write-Host "  Removed $fname" -ForegroundColor Green
                }
            }
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

        # -WithInstructions: append snippet + copy path-specific files (Copilot only)
        if ($ag -eq "copilot" -and $WithInstructions) {
            $templatesDir = Join-Path $ScriptDir "templates"
            if (Test-Path $templatesDir) {
                # Append snippet to copilot-instructions.md (idempotent)
                $copilotInstr = Join-Path $agentDir "copilot-instructions.md"
                $snippetFile = Join-Path $templatesDir "copilot-instructions-snippet.md"
                if (Test-Path $snippetFile) {
                    if ((Test-Path $copilotInstr) -and (Select-String -Path $copilotInstr -Pattern $MarkerStart -Quiet)) {
                        Write-Host "  Spring Boot snippet already present in copilot-instructions.md, skipping" -ForegroundColor Yellow
                    } else {
                        if (-not (Test-Path (Split-Path $copilotInstr))) {
                            New-Item -ItemType Directory -Path (Split-Path $copilotInstr) -Force | Out-Null
                        }
                        # Append with blank line separator
                        if ((Test-Path $copilotInstr) -and ((Get-Item $copilotInstr).Length -gt 0)) {
                            Add-Content -Path $copilotInstr -Value ""
                        }
                        $snippet = Get-Content $snippetFile -Raw
                        Add-Content -Path $copilotInstr -Value $snippet
                        Write-Host "  Appended spring-boot snippet to copilot-instructions.md" -ForegroundColor Green
                    }
                }

                # Copy path-specific .instructions.md files (skip if they already exist)
                $instrSourceDir = Join-Path $templatesDir "instructions"
                if (Test-Path $instrSourceDir) {
                    $instrTargetDir = Join-Path $agentDir "instructions"
                    if (-not (Test-Path $instrTargetDir)) {
                        New-Item -ItemType Directory -Path $instrTargetDir -Force | Out-Null
                    }
                    Get-ChildItem $instrSourceDir -Filter "*.instructions.md" | ForEach-Object {
                        $targetFile = Join-Path $instrTargetDir $_.Name
                        if (-not (Test-Path $targetFile)) {
                            Copy-Item $_.FullName $targetFile
                            Write-Host "  Installed $($_.Name) into $instrTargetDir" -ForegroundColor Green
                        } else {
                            Write-Host "  Skipped $($_.Name) (already exists)" -ForegroundColor Yellow
                        }
                    }
                }
            } else {
                Write-Host "  templates/ directory not found — skipping instruction files" -ForegroundColor Yellow
            }
        }
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
    if ($WithInstructions -and ($SelectedAgents -contains "copilot")) {
        Write-Host ""
        Write-Host "Copilot extras (via -WithInstructions):"
        Write-Host "  .github/copilot-instructions.md        # Appended spring-boot snippet"
        Write-Host "  .github/instructions/                   # Path-specific rules"
        Write-Host "  ├── java-spring.instructions.md         # Fires on *.java files"
        Write-Host "  ├── pom.instructions.md                 # Fires on pom.xml"
        Write-Host "  ├── docker.instructions.md              # Fires on Dockerfile"
        Write-Host "  ├── test.instructions.md                # Fires on *Test.java, *IT.java"
        Write-Host "  ├── properties.instructions.md          # Fires on application*.properties"
        Write-Host "  └── liquibase.instructions.md           # Fires on db/changelog/**"
    } elseif ($SelectedAgents -contains "copilot") {
        Write-Host ""
        Write-Host "Tip: For extra Copilot compliance, re-run with -WithInstructions"
        Write-Host "     to add always-on rules and path-specific instruction files."
        Write-Host "     See templates/README.md for details."
    }
}

# Cleanup temp directory if we cloned from GitHub
if ($CleanupTemp -and $TempDir -and (Test-Path $TempDir)) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
