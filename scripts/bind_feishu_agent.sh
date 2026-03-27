#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bind_feishu_agent.sh [--account-id <id>] (--agent <existing-agent> | --new-agent <new-agent>) [--config <path>] [--no-restart]

Examples:
  bind_feishu_agent.sh --agent main
  bind_feishu_agent.sh --new-agent openmoss
  bind_feishu_agent.sh --account-id sales --new-agent sales-bot
EOF
}

ACCOUNT_ID="default"
AGENT_ID=""
NEW_AGENT_ID=""
CONFIG_PATH="${HOME}/.openclaw/openclaw.json"
RESTART_GATEWAY=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id)
      ACCOUNT_ID="${2:?missing account id}"
      shift 2
      ;;
    --agent)
      AGENT_ID="${2:?missing agent id}"
      shift 2
      ;;
    --new-agent)
      NEW_AGENT_ID="${2:?missing new agent id}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:?missing config path}"
      shift 2
      ;;
    --no-restart)
      RESTART_GATEWAY=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$AGENT_ID" && -n "$NEW_AGENT_ID" ]]; then
  echo "Use either --agent or --new-agent, not both." >&2
  exit 1
fi

if [[ -z "$AGENT_ID" && -z "$NEW_AGENT_ID" ]]; then
  echo "You must provide --agent or --new-agent." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

TARGET_AGENT="${AGENT_ID:-$NEW_AGENT_ID}"

if [[ -n "$NEW_AGENT_ID" ]]; then
  echo "[feishu-bot-installer] ensuring agent '$NEW_AGENT_ID' exists..."
  if ! openclaw agents add "$NEW_AGENT_ID" >/dev/null 2>&1; then
    echo "[feishu-bot-installer] openclaw agents add returned non-zero; assuming agent may already exist."
  fi
fi

BACKUP_PATH="${CONFIG_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "[feishu-bot-installer] backup saved to $BACKUP_PATH"

node - "$CONFIG_PATH" "$ACCOUNT_ID" "$TARGET_AGENT" <<'EOF'
const fs = require('fs');

const [configPath, accountId, targetAgent] = process.argv.slice(2);
const raw = fs.readFileSync(configPath, 'utf8');
const cfg = JSON.parse(raw);

cfg.bindings = Array.isArray(cfg.bindings) ? cfg.bindings : [];

const nextBindings = cfg.bindings.filter((binding) => {
  return !(binding?.match?.channel === 'feishu' && (binding?.match?.accountId ?? 'default') === accountId);
});

nextBindings.push({
  match: { channel: 'feishu', accountId },
  agentId: targetAgent,
});

cfg.bindings = nextBindings;

fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);
EOF

echo "[feishu-bot-installer] bound feishu account '$ACCOUNT_ID' to agent '$TARGET_AGENT'"

if [[ "$RESTART_GATEWAY" -eq 1 ]]; then
  openclaw gateway restart
  echo "[feishu-bot-installer] gateway restarted"
else
  echo "[feishu-bot-installer] gateway restart skipped (--no-restart)"
fi
