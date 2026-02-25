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

usage() {
  cat <<EOF

Usage: $0 [PROJECT_PATH] [OPTIONS]

Install springboot-skill for AI coding agents.

OPTIONS:
  --project              Install at project level (default)
  --user                 Install at user level (~/.claude, ~/.codex, etc.)
  --agent AGENT          Install for specific agent(s): claude, codex, gemini, cursor, copilot, or 'all'
                         Can be specified multiple times. Default: all agents
  --uninstall            Remove installed skill from agent directories
  -h, --help             Show this help message

EXAMPLES:
  # --- Local (after cloning the repo) ---
  $0                                        # Install for all agents at project level (cwd)
  $0 ~/projects/my-api                      # Install for all agents in specific project
  $0 --user                                 # Install for all agents at user level
  $0 --agent claude                         # Install for Claude only at project level
  $0 --agent claude --agent codex           # Install for Claude and Codex
  $0 --user --agent gemini                  # Install for Gemini at user level
  $0 --uninstall                            # Remove skill from all agents at project level
  $0 --uninstall --agent claude             # Remove skill from Claude only

  # --- Remote (one-liner from GitHub — no clone needed) ---
  curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api
  curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --user --agent claude
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
  else
    echo "Installing for ${agent} at ${INSTALL_LEVEL} level..."
    mkdir -p "${SKILLS_DIR}"
    rm -rf "${SKILLS_DIR}/spring-boot"
    cp -r "${SOURCE_SKILLS_DIR}/spring-boot" "${SKILLS_DIR}/"
    echo "✓ Installed spring-boot skill for ${agent} into ${SKILLS_DIR}/spring-boot"
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
fi
