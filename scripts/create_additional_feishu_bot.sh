#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create_additional_feishu_bot.sh [user@host] --archive-default-as <accountId> --archive-default-agent <agentId> --new-default-agent <agentId> [--archive-default-name <name>]

Examples:
  create_additional_feishu_bot.sh --archive-default-as openmoss --archive-default-agent openmoss --new-default-agent feishu-test-3
  create_additional_feishu_bot.sh mark@192.168.0.100 --archive-default-as openmoss --archive-default-agent openmoss --new-default-agent feishu-test-3 --archive-default-name "Openmoss协作团队"

This is the safest multi-bot workflow:
1. Archive the current top-level default bot into channels.feishu.accounts.<accountId>
2. Launch the official QR-based bot creation flow
3. Bind the newly created default bot to the target agent
4. Print the final mapping summary
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
ARCHIVE_DEFAULT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive-default-as) ARCHIVE_ACCOUNT_ID="${2:?missing account id}"; shift 2 ;;
    --archive-default-agent) ARCHIVE_AGENT_ID="${2:?missing agent id}"; shift 2 ;;
    --new-default-agent) NEW_DEFAULT_AGENT_ID="${2:?missing agent id}"; shift 2 ;;
    --archive-default-name) ARCHIVE_DEFAULT_NAME="${2:?missing bot name}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$ARCHIVE_ACCOUNT_ID" || -z "$ARCHIVE_AGENT_ID" || -z "$NEW_DEFAULT_AGENT_ID" ]]; then
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

run_remote_py() {
  local host="$1"
  local py="$2"
  ssh "$host" 'python3 - <<'"'"'PY'"'"'
'"$py"'
PY'
}

archive_and_bind_remote() {
  local host="$1"
  local account_id="$2"
  local agent_id="$3"
  local bot_name="$4"
  local py
  py=$(cat <<PY
import json, pathlib, shutil, time
p = pathlib.Path.home() / ".openclaw" / "openclaw.json"
cfg = json.loads(p.read_text())
backup = p.with_name("openclaw.json.pre-additional-bot-archive-" + time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(p, backup)
fei = cfg.setdefault("channels", {}).setdefault("feishu", {})
accounts = fei.setdefault("accounts", {})
accounts["$account_id"] = {
    **accounts.get("$account_id", {}),
    "enabled": True,
    "appId": fei.get("appId"),
    "appSecret": fei.get("appSecret"),
}
if "$bot_name":
    accounts["$account_id"]["name"] = "$bot_name"
    accounts["$account_id"]["botName"] = "$bot_name"
cfg.setdefault("session", {})["dmScope"] = "per-account-channel-peer"
bindings = [b for b in cfg.get("bindings", []) if not (b.get("match", {}).get("channel") == "feishu" and (b.get("match", {}).get("accountId") or "default") == "$account_id")]
bindings.append({"type": "route", "agentId": "$agent_id", "match": {"channel": "feishu", "accountId": "$account_id"}})
cfg["bindings"] = bindings
p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\\n")
print(backup)
PY
)
  run_remote_py "$host" "$py"
}

archive_and_bind_local() {
  local account_id="$1"
  local agent_id="$2"
  local bot_name="$3"
  python3 - <<PY
import json, pathlib, shutil, time
p = pathlib.Path.home() / ".openclaw" / "openclaw.json"
cfg = json.loads(p.read_text())
backup = p.with_name("openclaw.json.pre-additional-bot-archive-" + time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(p, backup)
fei = cfg.setdefault("channels", {}).setdefault("feishu", {})
accounts = fei.setdefault("accounts", {})
accounts["$account_id"] = {
    **accounts.get("$account_id", {}),
    "enabled": True,
    "appId": fei.get("appId"),
    "appSecret": fei.get("appSecret"),
}
if "$bot_name":
    accounts["$account_id"]["name"] = "$bot_name"
    accounts["$account_id"]["botName"] = "$bot_name"
cfg.setdefault("session", {})["dmScope"] = "per-account-channel-peer"
bindings = [b for b in cfg.get("bindings", []) if not (b.get("match", {}).get("channel") == "feishu" and (b.get("match", {}).get("accountId") or "default") == "$account_id")]
bindings.append({"type": "route", "agentId": "$agent_id", "match": {"channel": "feishu", "accountId": "$account_id"}})
cfg["bindings"] = bindings
p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\\n")
print(backup)
PY
}

bind_new_default_remote() {
  local host="$1"
  local agent_id="$2"
  ssh "$host" "python3 - <<'PY'
import json, pathlib, shutil, time
p = pathlib.Path.home() / '.openclaw' / 'openclaw.json'
cfg = json.loads(p.read_text())
backup = p.with_name('openclaw.json.pre-additional-bot-bind-' + time.strftime('%Y%m%d-%H%M%S'))
shutil.copy2(p, backup)
bindings = [b for b in cfg.get('bindings', []) if not (b.get('match', {}).get('channel') == 'feishu' and (b.get('match', {}).get('accountId') or 'default') == 'default')]
bindings.append({'type': 'route', 'agentId': '$agent_id', 'match': {'channel': 'feishu', 'accountId': 'default'}})
cfg['bindings'] = bindings
p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + '\\n')
print(backup)
PY"
  ssh "$host" 'zsh -lc "openclaw gateway restart >/dev/null"'
}

bind_new_default_local() {
  local agent_id="$1"
  python3 - <<PY
import json, pathlib, shutil, time
p = pathlib.Path.home() / ".openclaw" / "openclaw.json"
cfg = json.loads(p.read_text())
backup = p.with_name("openclaw.json.pre-additional-bot-bind-" + time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(p, backup)
bindings = [b for b in cfg.get("bindings", []) if not (b.get("match", {}).get("channel") == "feishu" and (b.get("match", {}).get("accountId") or "default") == "default")]
bindings.append({"type": "route", "agentId": "$agent_id", "match": {"channel": "feishu", "accountId": "default"}})
cfg["bindings"] = bindings
p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\\n")
print(backup)
PY
  openclaw gateway restart >/dev/null
}

verify_remote() {
  local host="$1"
  ssh "$host" 'node - <<'"'"'EOF'"'"'
const fs = require("fs");
const path = require("path");
const p = path.join(process.env.HOME, ".openclaw", "openclaw.json");
const cfg = JSON.parse(fs.readFileSync(p, "utf8"));
const fei = cfg?.channels?.feishu || {};
const accounts = fei.accounts || {};
const bindings = Array.isArray(cfg?.bindings) ? cfg.bindings : [];
const findAgent = (accountId) => {
  const b = bindings.find((x) => x?.match?.channel === "feishu" && ((x?.match?.accountId ?? "default") === accountId));
  return b?.agentId || "(unbound)";
};
console.log("Feishu mapping summary");
console.log(`- default: ${fei.appId || "(missing appId)"} -> accountId=default -> agentId=${findAgent("default")}`);
for (const [accountId, account] of Object.entries(accounts)) {
  console.log(`- ${accountId}: ${account?.appId || "(missing appId)"} -> accountId=${accountId} -> agentId=${findAgent(accountId)}`);
}
EOF'
}

verify_local() {
  zsh "$SCRIPT_DIR/verify_feishu_mapping.sh"
}

if [[ -n "$TARGET" ]]; then
  archive_and_bind_remote "$TARGET" "$ARCHIVE_ACCOUNT_ID" "$ARCHIVE_AGENT_ID" "$ARCHIVE_DEFAULT_NAME"
  zsh "$SCRIPT_DIR/create_feishu_bot.sh" "$TARGET"
  bind_new_default_remote "$TARGET" "$NEW_DEFAULT_AGENT_ID"
  verify_remote "$TARGET"
else
  archive_and_bind_local "$ARCHIVE_ACCOUNT_ID" "$ARCHIVE_AGENT_ID" "$ARCHIVE_DEFAULT_NAME"
  zsh "$SCRIPT_DIR/create_feishu_bot.sh"
  bind_new_default_local "$NEW_DEFAULT_AGENT_ID"
  verify_local
fi
