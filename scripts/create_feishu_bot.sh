#!/bin/zsh
set -euo pipefail

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  cat <<'EOF'
Usage:
  create_feishu_bot.sh [user@host]

Examples:
  create_feishu_bot.sh
  create_feishu_bot.sh mark@192.168.0.100

This launches the official openclaw-lark installer in interactive mode so the
QR code can be scanned from the terminal output.
EOF
  exit 0
fi

TARGET="${1-}"
CHECK_CMD='if [ -d "$HOME/.openclaw/extensions/openclaw-lark" ]; then echo INSTALLED; else echo NOT_INSTALLED; fi'
INSTALL_CMD='npx -y @larksuite/openclaw-lark install'

run_remote() {
  local host="$1"
  ssh "$host" "zsh -lc '$2'"
}

if [[ -n "$TARGET" ]]; then
  STATUS="$(run_remote "$TARGET" "$CHECK_CMD")"
  if [[ "$STATUS" == "INSTALLED" ]]; then
    echo "[feishu-bot-installer] openclaw-lark plugin is already installed on $TARGET."
    echo "[feishu-bot-installer] The official CLI does not expose a create-bot-only command."
    echo "[feishu-bot-installer] Continuing with the official install/configure flow to create or bind a bot."
  else
    echo "[feishu-bot-installer] openclaw-lark plugin is not installed on $TARGET. Starting official install flow."
  fi
  exec ssh -tt "$TARGET" "zsh -lc '$INSTALL_CMD'"
else
  STATUS="$(zsh -lc "$CHECK_CMD")"
  if [[ "$STATUS" == "INSTALLED" ]]; then
    echo "[feishu-bot-installer] openclaw-lark plugin is already installed locally."
    echo "[feishu-bot-installer] The official CLI does not expose a create-bot-only command."
    echo "[feishu-bot-installer] Continuing with the official install/configure flow to create or bind a bot."
  else
    echo "[feishu-bot-installer] openclaw-lark plugin is not installed locally. Starting official install flow."
  fi
  exec zsh -lc "$INSTALL_CMD"
fi
