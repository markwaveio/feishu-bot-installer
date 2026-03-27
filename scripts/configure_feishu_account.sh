#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  configure_feishu_account.sh --account-id <id> (--app-id <cli_xxx> --app-secret <secret> | --from-default) [--bot-name <name>] [--config <path>] [--no-restart]

Examples:
  configure_feishu_account.sh --account-id work --app-id cli_xxx --app-secret secret_xxx
  configure_feishu_account.sh --account-id support --app-id cli_yyy --app-secret secret_yyy --bot-name "客服机器人"
  configure_feishu_account.sh --account-id bozai --from-default --bot-name "Bozai"
EOF
}

ACCOUNT_ID=""
APP_ID=""
APP_SECRET=""
BOT_NAME=""
CONFIG_PATH="${HOME}/.openclaw/openclaw.json"
RESTART_GATEWAY=1
FROM_DEFAULT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id) ACCOUNT_ID="${2:?missing account id}"; shift 2 ;;
    --app-id) APP_ID="${2:?missing app id}"; shift 2 ;;
    --app-secret) APP_SECRET="${2:?missing app secret}"; shift 2 ;;
    --from-default) FROM_DEFAULT=1; shift ;;
    --bot-name) BOT_NAME="${2:?missing bot name}"; shift 2 ;;
    --config) CONFIG_PATH="${2:?missing config path}"; shift 2 ;;
    --no-restart) RESTART_GATEWAY=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$ACCOUNT_ID" ]]; then
  usage >&2
  exit 1
fi

if [[ "$FROM_DEFAULT" -eq 1 && ( -n "$APP_ID" || -n "$APP_SECRET" ) ]]; then
  echo "Use either --from-default or --app-id/--app-secret." >&2
  exit 1
fi

if [[ "$FROM_DEFAULT" -eq 0 && ( -z "$APP_ID" || -z "$APP_SECRET" ) ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

BACKUP_PATH="${CONFIG_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "[feishu-bot-installer] backup saved to $BACKUP_PATH"

node - "$CONFIG_PATH" "$ACCOUNT_ID" "$APP_ID" "$APP_SECRET" "$BOT_NAME" "$FROM_DEFAULT" <<'EOF'
const fs = require('fs');

const [configPath, accountId, appId, appSecret, botName, fromDefaultRaw] = process.argv.slice(2);
const fromDefault = fromDefaultRaw === '1';
const raw = fs.readFileSync(configPath, 'utf8');
const cfg = JSON.parse(raw);

cfg.session = cfg.session || {};
if (!cfg.session.dmScope) {
  cfg.session.dmScope = 'per-account-channel-peer';
}

cfg.channels = cfg.channels || {};
cfg.channels.feishu = cfg.channels.feishu || {};
cfg.channels.feishu.accounts = cfg.channels.feishu.accounts || {};

const existing = cfg.channels.feishu.accounts[accountId] || {};
const next = {
  ...existing,
  enabled: true,
};

if (fromDefault) {
  if (!cfg.channels.feishu.appId || !cfg.channels.feishu.appSecret) {
    throw new Error('Top-level default Feishu bot is not configured.');
  }
  next.appId = cfg.channels.feishu.appId;
  next.appSecret = cfg.channels.feishu.appSecret;
  if (!botName && cfg.channels.feishu.botName) next.botName = cfg.channels.feishu.botName;
  if (!botName && cfg.channels.feishu.name) next.name = cfg.channels.feishu.name;
} else {
  next.appId = appId;
  next.appSecret = appSecret;
}

cfg.channels.feishu.accounts[accountId] = {
  ...next,
};

if (botName) {
  cfg.channels.feishu.accounts[accountId].botName = botName;
  cfg.channels.feishu.accounts[accountId].name = botName;
}

fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);
EOF

echo "[feishu-bot-installer] configured feishu account '$ACCOUNT_ID'"
echo "[feishu-bot-installer] session.dmScope=$(python3 - <<'EOF'
import json, pathlib
p = pathlib.Path.home() / '.openclaw' / 'openclaw.json'
cfg = json.loads(p.read_text())
print(cfg.get('session', {}).get('dmScope'))
EOF
)"

if [[ "$RESTART_GATEWAY" -eq 1 ]]; then
  openclaw gateway restart
  echo "[feishu-bot-installer] gateway restarted"
else
  echo "[feishu-bot-installer] gateway restart skipped (--no-restart)"
fi
