#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  verify_feishu_mapping.sh [--config <path>]

Examples:
  verify_feishu_mapping.sh
  verify_feishu_mapping.sh --config ~/.openclaw/openclaw.json

Prints the effective Feishu bot mapping so you can verify:
  default bot App ID -> default accountId -> agentId
  accounts.<accountId>.appId -> agentId
EOF
}

CONFIG_PATH="${HOME}/.openclaw/openclaw.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_PATH="${2:?missing config path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

node - "$CONFIG_PATH" <<'EOF'
const fs = require('fs');

const [configPath] = process.argv.slice(2);
const raw = fs.readFileSync(configPath, 'utf8');
const cfg = JSON.parse(raw);
const fei = cfg?.channels?.feishu || {};
const bindings = Array.isArray(cfg?.bindings) ? cfg.bindings : [];
const accounts = fei.accounts || {};

function findAgent(accountId) {
  const binding = bindings.find((b) => b?.match?.channel === 'feishu' && ((b?.match?.accountId ?? 'default') === accountId));
  return binding?.agentId || '(unbound)';
}

console.log('Feishu mapping summary');
console.log(`- default: ${fei.appId || '(missing appId)'} -> accountId=default -> agentId=${findAgent('default')}`);

for (const [accountId, account] of Object.entries(accounts)) {
  console.log(`- ${accountId}: ${account?.appId || '(missing appId)'} -> accountId=${accountId} -> agentId=${findAgent(accountId)}`);
}

console.log('');
console.log('Tips');
console.log('- Confirm the App ID shown in Feishu Open Platform matches the line you expect.');
console.log('- Confirm the bot you are chatting with routes to the intended agentId.');
console.log('- If you created a second bot, make sure the old default bot was archived into accounts.<accountId>.');
EOF
