#!/usr/bin/env bash
# install.sh
# Interactive installation script for polya-sdlc-coder (Linux/macOS)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_OWNER='valvularseparate37-ai'
REPO_NAME='polya-sdlc-coder'
REPO_GIT_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
REPO_ZIP_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/main.zip"

printf '%b=== Polya SDLC Coder - Installer ===%b\n' "$CYAN" "$NC"

read -p "Enter your target project path (default: .): " TARGET_PATH < /dev/tty
TARGET_PATH="${TARGET_PATH:-.}"

if [[ ! -d "$TARGET_PATH" ]]; then
  printf '%bError: Target directory '%s' not found.%b\n' "$RED" "$TARGET_PATH" "$NC"
  exit 1
fi

TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
printf '%bTarget directory: %s%b\n' "$YELLOW" "$TARGET_PATH" "$NC"

TEMP_ROOT="$(mktemp -d -t polya-sdlc.XXXXXX)"
cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

SOURCE_CONTENT_DIR=''

if command -v git >/dev/null 2>&1; then
  printf '%bCloning repository from GitHub (shallow clone)...%b\n' "$CYAN" "$NC"
  REPO_CLONE_DIR="$TEMP_ROOT/repo"
  git clone --depth=1 -q "$REPO_GIT_URL" "$REPO_CLONE_DIR"
  SOURCE_CONTENT_DIR="$REPO_CLONE_DIR"
else
  printf '%bGit not found. Downloading repository ZIP...%b\n' "$YELLOW" "$NC"
  ZIP_FILE="$TEMP_ROOT/archive.zip"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_ZIP_URL" -o "$ZIP_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$ZIP_FILE" "$REPO_ZIP_URL"
  else
    printf '%bError: This script requires git or curl/wget and unzip to download the repository.%b\n' "$RED" "$NC"
    exit 1
  fi

  unzip -q "$ZIP_FILE" -d "$TEMP_ROOT"
  CANDIDATE_DIRS=("$TEMP_ROOT"/*)
  for candidate in "${CANDIDATE_DIRS[@]}"; do
    if [[ -d "$candidate" ]] && [[ -d "$candidate/.agents" ]] && [[ -f "$candidate/AGENTS.md" ]]; then
      SOURCE_CONTENT_DIR="$candidate"
      break
    fi
  done

  if [[ -z "$SOURCE_CONTENT_DIR" ]]; then
    printf '%bError: Failed to locate the downloaded repository contents.%b\n' "$RED" "$NC"
    exit 1
  fi
fi

if [[ ! -d "$SOURCE_CONTENT_DIR/.agents" ]] || [[ ! -f "$SOURCE_CONTENT_DIR/AGENTS.md" ]]; then
  printf '%bError: Expected .agents folder and AGENTS.md in the downloaded repository.%b\n' "$RED" "$NC"
  exit 1
fi

SRC_DIR="$SOURCE_CONTENT_DIR/.agents"
SRC_AGENTS="$SOURCE_CONTENT_DIR/AGENTS.md"

printf '%bReady to install: %s%b\n' "$GREEN" "Polya SDLC Coder" "$NC"

printf '\n%bSelect the AI Assistant platform you want to install in your project:%b\n' "$CYAN" "$NC"
printf '1) %bStandard Platforms%b (GitHub Copilot, Antigravity, OpenCode, CommandCode, Codex, Pi, OMP) -> installs to .agents/\n' "$GREEN" "$NC"
printf '2) %bClaude Code%b -> installs to .claude/\n' "$GREEN" "$NC"
printf '3) %bCursor%b -> installs to .cursor/\n' "$GREEN" "$NC"
printf '4) %bAll Platforms%b (Install to .agents/, .claude/, and .cursor/)\n' "$GREEN" "$NC"
read -p "Enter your platform choice (1-4, default: 1): " CHOICE < /dev/tty
CHOICE="${CHOICE:-1}"

case "$CHOICE" in
  1) DEST_DIRS=(".agents") ;;
  2) DEST_DIRS=(".claude") ;;
  3) DEST_DIRS=(".cursor") ;;
  4) DEST_DIRS=(".agents" ".claude" ".cursor") ;;
  *)
    printf '%bInvalid choice. Process aborted.%b\n' "$RED" "$NC"
    exit 1
    ;;
esac

for DST_DIR_NAME in "${DEST_DIRS[@]}"; do
  DST_DIR="$TARGET_PATH/$DST_DIR_NAME"

  if [[ -d "$DST_DIR" ]]; then
    printf '%bFolder %s already exists in target. Overwrite entire folder? (y/N): %b' "$YELLOW" "$DST_DIR_NAME" "$NC"
    read -r CONFIRM < /dev/tty
    CONFIRM="${CONFIRM:-n}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
      printf '%bSkipping copy of %s...%b\n' "$YELLOW" "$DST_DIR_NAME" "$NC"
      continue
    fi

    rm -rf "$DST_DIR"
  fi

  mkdir -p "$DST_DIR"
  cp -a "$SRC_DIR/." "$DST_DIR/"

  if [[ "$DST_DIR_NAME" != ".agents" ]]; then
    rm -f "$DST_DIR/instructions/memory.instructions.md"
  fi

  printf '%bSuccessfully copied agents configuration to %s%b\n' "$GREEN" "$TARGET_PATH/$DST_DIR_NAME" "$NC"
done

DST_AGENTS="$TARGET_PATH/AGENTS.md"
if [[ -f "$SRC_AGENTS" ]]; then
  if [[ -f "$DST_AGENTS" ]]; then
    printf '%bFile AGENTS.md already exists in target.%b\n' "$YELLOW" "$NC"
    read -p "Do you want to: [k]eep existing, [r]eplace with template, or [m]erge them? (K/r/m): " AGENTS_CHOICE < /dev/tty
    AGENTS_CHOICE="${AGENTS_CHOICE:-k}"

    case "$AGENTS_CHOICE" in
      [Rr])
        cp "$DST_AGENTS" "${DST_AGENTS}.bak"
        cp "$SRC_AGENTS" "$DST_AGENTS"
        printf '%bReplaced AGENTS.md. Backup created at: %s.bak%b\n' "$GREEN" "$DST_AGENTS" "$NC"
        ;;
      [Mm])
        cp "$DST_AGENTS" "${DST_AGENTS}.bak"

        if grep -Eq '# --- MERGED.*TEMPLATE' "$DST_AGENTS" 2>/dev/null; then
          TMP_TRIMMED="$(mktemp)"
          sed '/# --- MERGED.*TEMPLATE/,$d' "$DST_AGENTS" > "$TMP_TRIMMED"
          cp "$TMP_TRIMMED" "$DST_AGENTS"
          rm -f "$TMP_TRIMMED"
        fi

        printf '\n\n# --- MERGED POLYA TEMPLATE (Added on %s) ---\n\n' "$(date +%F)" >> "$DST_AGENTS"
        cat "$SRC_AGENTS" >> "$DST_AGENTS"
        printf '%bMerged new template into AGENTS.md. Backup created at: %s.bak%b\n' "$GREEN" "$DST_AGENTS" "$NC"
        ;;
      *)
        printf '%bSkipping copy of AGENTS.md...%b\n' "$YELLOW" "$NC"
        ;;
    esac
  else
    cp "$SRC_AGENTS" "$TARGET_PATH/"
    printf '%bSuccessfully copied AGENTS.md to %s%b\n' "$GREEN" "$TARGET_PATH" "$NC"
  fi
else
  printf '%bWarning: AGENTS.md not found in the source repository.%b\n' "$YELLOW" "$NC"
fi

printf '\n%b[OK] Installation completed successfully!%b\n' "$GREEN" "$NC"
printf '%b[IMPORTANT]: Please review AGENTS.md in your project to:%b\n' "$YELLOW" "$NC"
printf '%b1. Customize the project name on the first line so that AI agents can recognize your project context.%b\n' "$YELLOW" "$NC"
printf '%b2. Change the language preference in the "## Communication" section if necessary.%b\n' "$YELLOW" "$NC"
printf '%bNext Steps with Pólya SDLC:%b\n' "$CYAN" "$NC"
printf '%b- Start by typing /to-ask-help for interactive Socratic triage guidance and intent routing.%b\n' "$CYAN" "$NC"
printf '%b- Type /to-explore to survey and discover problem spaces (Phase 0).%b\n' "$CYAN" "$NC"
printf '%b- In an existing codebase, run /to-map to document architecture topography into docs/ARCHITECTURE.md.%b\n' "$CYAN" "$NC"
