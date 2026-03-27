#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DEST="$CODEX_HOME/skills/feishu-bot-installer"

mkdir -p "$DEST/agents" "$DEST/scripts"
cp "$SKILL_ROOT/SKILL.md" "$DEST/SKILL.md"
cp "$SKILL_ROOT/agents/openai.yaml" "$DEST/agents/openai.yaml"
cp "$SKILL_ROOT/scripts/create_feishu_bot.sh" "$DEST/scripts/create_feishu_bot.sh"
cp "$SKILL_ROOT/scripts/create_additional_feishu_bot.sh" "$DEST/scripts/create_additional_feishu_bot.sh"
cp "$SKILL_ROOT/scripts/bind_feishu_agent.sh" "$DEST/scripts/bind_feishu_agent.sh"
cp "$SKILL_ROOT/scripts/configure_feishu_account.sh" "$DEST/scripts/configure_feishu_account.sh"
cp "$SKILL_ROOT/scripts/verify_feishu_mapping.sh" "$DEST/scripts/verify_feishu_mapping.sh"
chmod +x "$DEST/scripts/create_feishu_bot.sh" "$DEST/scripts/create_additional_feishu_bot.sh" "$DEST/scripts/bind_feishu_agent.sh" "$DEST/scripts/configure_feishu_account.sh" "$DEST/scripts/verify_feishu_mapping.sh"

echo "Installed feishu-bot-installer to $DEST"
