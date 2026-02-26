#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# springboot-skill installer
# Installs skills into AI agent directories at project or user level
# Supports: Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot
#
# Works two ways:
#   1. Local:  ./install.sh ~/projects/my-api
#   2. Remote: curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api
# ============================================================

GITHUB_REPO="https://github.com/rajeshanji8/springboot-skill.git"
AI_AGENTS=("claude" "codex" "gemini" "cursor" "copilot")
INSTALL_LEVEL="project"
SELECTED_AGENTS=()
WITH_INSTRUCTIONS=false

MARKER_START="<!-- springboot-skill:start -->"
MARKER_END="<!-- springboot-skill:end -->"

usage() {
  cat <<EOF

Usage: $0 [PROJECT_PATH] [OPTIONS]

Install springboot-skill for AI coding agents.

OPTIONS:
  --project              Install at project level (default)
  --user                 Install at user level (~/.claude, ~/.codex, etc.)
  --agent AGENT          Install for specific agent(s): claude, codex, gemini, cursor, copilot, or 'all'
                         Can be specified multiple times. Default: all agents
  --with-instructions    (Copilot only) Also append to copilot-instructions.md and add path-specific
                         .instructions.md files for extra rule enforcement. Uses marker comments
                         for clean uninstall. Safe to run multiple times.
  --uninstall            Remove installed skill from agent directories
  -h, --help             Show this help message

EXAMPLES:
  # --- Skill only (default, safe, portable) ---
  $0 ~/projects/my-api
  $0 --agent copilot ~/projects/my-api

  # --- Skill + Copilot instruction reinforcement ---
  $0 --with-instructions ~/projects/my-api

  # --- Other examples ---
  $0 --user                                 # Install for all agents at user level
  $0 --agent claude                         # Install for Claude only at project level
  $0 --uninstall                            # Remove skill from all agents at project level

  # --- Remote (one-liner from GitHub — no clone needed) ---
  curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api
  curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --with-instructions ~/projects/my-api
  curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --uninstall

EOF
  exit 0
}

# --------------- PARSE ARGS ---------------
PROJECT_PATH=""
UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      INSTALL_LEVEL="project"
      shift
      ;;
    --user)
      INSTALL_LEVEL="user"
      shift
      ;;
    --agent)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent requires an argument"
        exit 1
      fi
      if [[ "$2" == "all" ]]; then
        SELECTED_AGENTS=("${AI_AGENTS[@]}")
      elif [[ "$2" =~ ^(claude|codex|gemini|cursor|copilot)$ ]]; then
        SELECTED_AGENTS+=("$2")
      else
        echo "Error: Invalid agent '$2'. Must be one of: claude, codex, gemini, cursor, copilot, all"
        exit 1
      fi
      shift 2
      ;;
    --with-instructions)
      WITH_INSTRUCTIONS=true
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$1"
        shift
      else
        echo "Error: Unknown option '$1'"
        usage
      fi
      ;;
  esac
done

# Default to all agents if none specified
if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
  SELECTED_AGENTS=("${AI_AGENTS[@]}")
fi

# Remove duplicates
SELECTED_AGENTS=($(printf "%s\n" "${SELECTED_AGENTS[@]}" | sort -u))

# --------------- RESOLVE SOURCE ---------------
# Try local first (running from cloned repo), fall back to GitHub clone
CLEANUP_TEMP=false

if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "bash" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Piped from curl — BASH_SOURCE is not a real path
  SCRIPT_DIR=""
fi

if [[ -n "$SCRIPT_DIR" ]] && [[ -d "${SCRIPT_DIR}/skills" ]]; then
  SOURCE_SKILLS_DIR="${SCRIPT_DIR}/skills"
else
  # No local skills/ found — clone from GitHub
  echo "No local skills/ directory found. Downloading from GitHub..."
  if ! command -v git &>/dev/null; then
    echo "Error: git is required for remote install. Install git or clone the repo manually."
    exit 1
  fi
  TEMP_DIR="$(mktemp -d)"
  CLEANUP_TEMP=true
  trap 'rm -rf "$TEMP_DIR"' EXIT
  git clone --depth 1 --quiet "$GITHUB_REPO" "$TEMP_DIR"
  SOURCE_SKILLS_DIR="${TEMP_DIR}/skills"
  SCRIPT_DIR="${TEMP_DIR}"
fi

# Verify source skills directory exists
if [[ ! -d "${SOURCE_SKILLS_DIR}/spring-boot" ]]; then
  echo "Error: skills/spring-boot not found at ${SOURCE_SKILLS_DIR}"
  exit 1
fi

# Default project path to cwd
if [[ -z "$PROJECT_PATH" ]]; then
  PROJECT_PATH="$(pwd)"
else
  PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
    echo "Error: $PROJECT_PATH does not exist"
    exit 1
  }
fi

# --------------- MAIN ---------------
echo ""
echo "Spring Boot Skill Installer"
echo "==========================="
echo "Source:  ${SCRIPT_DIR}"
echo "Level:  ${INSTALL_LEVEL}"
if [[ "${INSTALL_LEVEL}" == "project" ]]; then
  echo "Project: ${PROJECT_PATH}"
fi
echo "Agents: ${SELECTED_AGENTS[*]}"
echo ""

# Map agent name to its dot-directory (copilot uses .github)
agent_dir_name() {
  if [[ "$1" == "copilot" ]]; then echo ".github"; else echo ".$1"; fi
}

for agent in "${SELECTED_AGENTS[@]}"; do
  DIR_NAME="$(agent_dir_name "$agent")"
  if [[ "${INSTALL_LEVEL}" == "user" ]]; then
    AGENT_DIR="${HOME}/${DIR_NAME}"
  else
    AGENT_DIR="${PROJECT_PATH}/${DIR_NAME}"
  fi

  SKILLS_DIR="${AGENT_DIR}/skills"

  if $UNINSTALL; then
    if [[ -d "${SKILLS_DIR}/spring-boot" ]]; then
      rm -rf "${SKILLS_DIR}/spring-boot"
      echo "✓ Removed spring-boot skill for ${agent} from ${SKILLS_DIR}"
    else
      echo "⚠ No spring-boot skill found for ${agent} at ${SKILLS_DIR}"
    fi
    # Clean up Copilot instruction snippets/files added by --with-instructions
    if [[ "$agent" == "copilot" ]]; then
      # Remove marker block from copilot-instructions.md
      COPILOT_INSTR="${AGENT_DIR}/copilot-instructions.md"
      if [[ -f "$COPILOT_INSTR" ]] && grep -q "$MARKER_START" "$COPILOT_INSTR" 2>/dev/null; then
        # Remove everything between markers (inclusive)
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$COPILOT_INSTR"
        rm -f "${COPILOT_INSTR}.bak"
        # Remove file if it's now empty (only whitespace)
        if [[ ! -s "$COPILOT_INSTR" ]] || [[ -z "$(tr -d '[:space:]' < "$COPILOT_INSTR")" ]]; then
          rm -f "$COPILOT_INSTR"
          echo "✓ Removed copilot-instructions.md (was empty after cleanup)"
        else
          echo "✓ Removed spring-boot snippet from copilot-instructions.md"
        fi
      fi
      # Remove path-specific instruction files (only ours)
      INSTR_DIR="${AGENT_DIR}/instructions"
      for fname in java-spring.instructions.md pom.instructions.md docker.instructions.md test.instructions.md properties.instructions.md liquibase.instructions.md; do
        [[ -f "${INSTR_DIR}/${fname}" ]] && rm -f "${INSTR_DIR}/${fname}" && echo "✓ Removed ${fname}"
      done
    fi
  else
    echo "Installing for ${agent} at ${INSTALL_LEVEL} level..."
    mkdir -p "${SKILLS_DIR}"
    rm -rf "${SKILLS_DIR}/spring-boot"
    cp -r "${SOURCE_SKILLS_DIR}/spring-boot" "${SKILLS_DIR}/"
    echo "✓ Installed spring-boot skill for ${agent} into ${SKILLS_DIR}/spring-boot"

    # --with-instructions: append snippet + copy path-specific files (Copilot only)
    if [[ "$agent" == "copilot" ]] && $WITH_INSTRUCTIONS; then
      TEMPLATES_DIR="${SCRIPT_DIR}/templates"
      if [[ -d "$TEMPLATES_DIR" ]]; then
        # Append snippet to copilot-instructions.md (idempotent — skip if markers already present)
        COPILOT_INSTR="${AGENT_DIR}/copilot-instructions.md"
        SNIPPET="${TEMPLATES_DIR}/copilot-instructions-snippet.md"
        if [[ -f "$SNIPPET" ]]; then
          if [[ -f "$COPILOT_INSTR" ]] && grep -q "$MARKER_START" "$COPILOT_INSTR" 2>/dev/null; then
            echo "⚠ Spring Boot snippet already present in copilot-instructions.md, skipping"
          else
            mkdir -p "$(dirname "$COPILOT_INSTR")"
            # Append with a blank line separator
            if [[ -f "$COPILOT_INSTR" ]] && [[ -s "$COPILOT_INSTR" ]]; then
              echo "" >> "$COPILOT_INSTR"
            fi
            cat "$SNIPPET" >> "$COPILOT_INSTR"
            echo "✓ Appended spring-boot snippet to copilot-instructions.md"
          fi
        fi

        # Copy path-specific .instructions.md files (skip if they already exist)
        if [[ -d "${TEMPLATES_DIR}/instructions" ]]; then
          mkdir -p "${AGENT_DIR}/instructions"
          for instrFile in "${TEMPLATES_DIR}/instructions/"*.instructions.md; do
            [[ -f "$instrFile" ]] || continue
            BASENAME="$(basename "$instrFile")"
            TARGET_FILE="${AGENT_DIR}/instructions/${BASENAME}"
            if [[ ! -f "$TARGET_FILE" ]]; then
              cp "$instrFile" "$TARGET_FILE"
              echo "✓ Installed ${BASENAME} into ${AGENT_DIR}/instructions/"
            else
              echo "⚠ Skipped ${BASENAME} (already exists)"
            fi
          done
        fi
      else
        echo "⚠ templates/ directory not found — skipping instruction files"
      fi
    fi
  fi
done

echo ""
echo "Done!"
if ! $UNINSTALL; then
  echo ""
  echo "Installed structure:"
  echo "  .<agent>/skills/spring-boot/"
  echo "  ├── SKILL.md              # Entry point (agent reads this first)"
  echo "  └── references/           # Detailed guides (read on demand)"
  if $WITH_INSTRUCTIONS && printf '%s\n' "${SELECTED_AGENTS[@]}" | grep -q '^copilot$'; then
    echo ""
    echo "Copilot extras (via --with-instructions):"
    echo "  .github/copilot-instructions.md        # Appended spring-boot snippet"
    echo "  .github/instructions/                   # Path-specific rules"
    echo "  ├── java-spring.instructions.md         # Fires on *.java files"
    echo "  ├── pom.instructions.md                 # Fires on pom.xml"
    echo "  ├── docker.instructions.md              # Fires on Dockerfile"
    echo "  ├── test.instructions.md                # Fires on *Test.java, *IT.java"
    echo "  ├── properties.instructions.md          # Fires on application*.properties"
    echo "  └── liquibase.instructions.md           # Fires on db/changelog/**"
  elif printf '%s\n' "${SELECTED_AGENTS[@]}" | grep -q '^copilot$'; then
    echo ""
    echo "Tip: For extra Copilot compliance, re-run with --with-instructions"
    echo "     to add always-on rules and path-specific instruction files."
    echo "     See templates/README.md for details."
  fi
fi
