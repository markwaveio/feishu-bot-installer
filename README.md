# Feishu Bot Installer

Public distributable skill for creating and binding Feishu/OpenClaw bots.

## What it solves

- Create a Feishu bot through the official QR-based installer
- Preserve existing bots before creating another one
- Configure multi-bot accounts under `channels.feishu.accounts`
- Bind each bot to the correct OpenClaw agent
- Verify `App ID -> accountId -> agentId` mapping after every change

## Included scripts

- `scripts/install_skill.sh`
  - Installs this skill into `$CODEX_HOME/skills/feishu-bot-installer`
- `scripts/create_feishu_bot.sh`
  - Runs the official `@larksuite/openclaw-lark` installer
- `scripts/create_additional_feishu_bot.sh`
  - Safe end-to-end flow for the 2nd/3rd/4th bot
- `scripts/configure_feishu_account.sh`
  - Writes a bot into `channels.feishu.accounts.<accountId>`
- `scripts/bind_feishu_agent.sh`
  - Binds a Feishu `accountId` to an OpenClaw agent
- `scripts/verify_feishu_mapping.sh`
  - Prints the final effective mapping

## Quick start

Install the skill:

```bash
zsh ./scripts/install_skill.sh
```

Create the first bot:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/create_feishu_bot.sh
```

Create an additional bot safely:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/create_additional_feishu_bot.sh mark@192.168.0.100 \
  --archive-default-as openmoss \
  --archive-default-agent openmoss \
  --new-default-agent feishu-test-3 \
  --archive-default-name "Openmoss协作团队"
```

Verify the final mapping:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/verify_feishu_mapping.sh
```

## Important note

The official Feishu installer writes the newly created bot into the top-level default Feishu config. If you are creating a second or later bot, archive the current default first or use `create_additional_feishu_bot.sh`.
