#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create_hermes_feishu_bot_installer.sh [user@host] --archive-default-as <accountId> --archive-default-agent <agentId> --new-default-agent <agentId>

Examples:
  create_hermes_feishu_bot_installer.sh --archive-default-as legacy-feishu --archive-default-agent main --new-default-agent hermes-feishu-bot-installer
  create_hermes_feishu_bot_installer.sh mark@192.168.0.100 --archive-default-as legacy-feishu --archive-default-agent main --new-default-agent hermes-feishu-bot-installer

This flow preserves the current default Feishu bot and creates a fresh one.
When the QR login flow asks:
1. choose create a new bot
2. do not reuse the existing bot
3. set the bot name to: Hermes-feishu-bot-installer
EOF
}

TARGET=""
if [[ "${1-}" == *@* ]]; then
  TARGET="$1"
  shift
fi

ARCHIVE_ACCOUNT_ID=""
ARCHIVE_AGENT_ID=""
NEW_DEFAULT_AGENT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive-default-as) ARCHIVE_ACCOUNT_ID="${2:?missing account id}"; shift 2 ;;
    --archive-default-agent) ARCHIVE_AGENT_ID="${2:?missing agent id}"; shift 2 ;;
    --new-default-agent) NEW_DEFAULT_AGENT_ID="${2:?missing agent id}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$ARCHIVE_ACCOUNT_ID" || -z "$ARCHIVE_AGENT_ID" || -z "$NEW_DEFAULT_AGENT_ID" ]]; then
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[feishu-bot-installer] Hermes-safe flow starting."
echo "[feishu-bot-installer] Existing default bot will be archived as accountId='$ARCHIVE_ACCOUNT_ID'."
echo "[feishu-bot-installer] New default bot will be bound to agentId='$NEW_DEFAULT_AGENT_ID'."
echo "[feishu-bot-installer] During QR setup, create a NEW bot named: Hermes-feishu-bot-installer"
echo

if [[ -n "$TARGET" ]]; then
  zsh "$SCRIPT_DIR/create_additional_feishu_bot.sh" "$TARGET" \
    --archive-default-as "$ARCHIVE_ACCOUNT_ID" \
    --archive-default-agent "$ARCHIVE_AGENT_ID" \
    --new-default-agent "$NEW_DEFAULT_AGENT_ID" \
    --archive-default-name "Archived default Feishu bot"
else
  zsh "$SCRIPT_DIR/create_additional_feishu_bot.sh" \
    --archive-default-as "$ARCHIVE_ACCOUNT_ID" \
    --archive-default-agent "$ARCHIVE_AGENT_ID" \
    --new-default-agent "$NEW_DEFAULT_AGENT_ID" \
    --archive-default-name "Archived default Feishu bot"
fi
