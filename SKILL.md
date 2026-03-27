---
name: feishu-bot-installer
description: Create or bind a Feishu/Lark OpenClaw bot from the command line using the official openclaw-lark installer, then bind that bot to either a new dedicated agent or an existing agent. Use when the user wants to create a Feishu bot, show a QR code for authorization, decide whether the bot should use isolated memory, or wire the bot into a specific OpenClaw agent.
metadata:
  short-description: Create and bind Feishu bots for OpenClaw
---

# Feishu Bot Installer

Use this skill for the official Feishu plugin onboarding flow plus multi-bot, multi-agent binding.

## What this skill covers

- Checks whether `openclaw-lark` is already installed
- Starts the official `@larksuite/openclaw-lark` installer in a TTY
- Shows the QR code in terminal output so the user can scan it
- Configures additional Feishu bot accounts under `channels.feishu.accounts`
- Sets the recommended multi-bot session isolation mode
- Verifies that each `App ID -> accountId -> agentId` mapping is exactly what you expect
- Binds the bot to either:
  - a new dedicated agent, or
  - an existing agent

## Official scheme vs this skill

The official scheme is better for full multi-bot deployments because it includes:

- `channels.feishu.accounts` for multiple bot credentials
- `session.dmScope = "per-account-channel-peer"` for per-bot DM isolation
- account-level routing via `bindings`
- optional peer-level routing for special users or groups

This skill should include those official pieces. The simplified version was enough for one bot, but not enough for a clean public multi-bot setup.

## Decision rule: new agent vs existing agent

Choose a **new agent** when:

- this bot should have its own memory and persona
- this bot serves a separate role, team, or workflow
- you want to avoid cross-channel context mixing

Choose an **existing agent** when:

- the bot should behave like the same assistant you already use elsewhere
- you want shared memory across channels
- you intentionally want Feishu and other channels to use one common agent

Default recommendation:

- public or role-specific bots: create a **new agent**
- private personal assistant bots: bind to an **existing agent** only if shared memory is intended

## Workflow

1. Install the skill package.
   - Run [install_skill.sh](./scripts/install_skill.sh).

2. For the safest multi-bot flow, prefer the all-in-one helper.
   - Run [create_additional_feishu_bot.sh](./scripts/create_additional_feishu_bot.sh).
   - It archives the current default bot, launches the official QR flow, binds the new default bot to the target agent, and prints the final mapping.

3. Start bot creation manually when you need lower-level control.
   - If a default Feishu bot is already in use and you are about to create a second bot, first archive the current default bot into `channels.feishu.accounts` with [configure_feishu_account.sh](./scripts/configure_feishu_account.sh) `--account-id <id> --from-default`.
   - Then run [create_feishu_bot.sh](./scripts/create_feishu_bot.sh).
   - If the official installer asks whether to reuse an existing bot, answer `n` to create a new one unless the user explicitly wants reuse.

4. Ask the user to scan the QR code.
   - The installer prints the QR code directly in the terminal.

5. Bind the bot to an agent after creation.
   - If this is an additional bot, first register it in `channels.feishu.accounts` with [configure_feishu_account.sh](./scripts/configure_feishu_account.sh).
   - New dedicated agent:
     - [bind_feishu_agent.sh](./scripts/bind_feishu_agent.sh) `--new-agent openmoss`
   - Existing agent:
     - [bind_feishu_agent.sh](./scripts/bind_feishu_agent.sh) `--agent main`

6. Verify the mapping before you start chatting.
   - Run [verify_feishu_mapping.sh](./scripts/verify_feishu_mapping.sh).
   - Check that the output matches your intended mapping:
     - which bot is top-level `default`
     - which bot lives under `accounts.<accountId>`
     - which `accountId` routes to which `agentId`
   - This prevents the exact failure mode where the right bot exists but the wrong `App ID` is attached to the wrong `accountId`.

## Commands

Install the skill:

```bash
./scripts/install_skill.sh
```

Create a bot locally:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/create_feishu_bot.sh
```

Create a bot on a remote host:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/create_feishu_bot.sh mark@192.168.0.100
```

Safest end-to-end additional-bot flow on a remote host:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/create_additional_feishu_bot.sh mark@192.168.0.100 \
  --archive-default-as openmoss \
  --archive-default-agent openmoss \
  --new-default-agent feishu-test-3 \
  --archive-default-name "Openmoss协作团队"
```

Bind the default Feishu bot to a new agent:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/bind_feishu_agent.sh --new-agent openmoss
```

Register an additional Feishu bot account and enable recommended isolation:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/configure_feishu_account.sh --account-id work --app-id cli_xxx --app-secret secret_xxx --bot-name "工作机器人"
```

Archive the current default bot before creating a second bot:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/configure_feishu_account.sh --account-id bozai --from-default --bot-name "Bozai"
```

Bind a Feishu account to an existing agent:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/bind_feishu_agent.sh --account-id default --agent main
```

Verify your final mapping:

```bash
$CODEX_HOME/skills/feishu-bot-installer/scripts/verify_feishu_mapping.sh
```

## Notes

- The official CLI currently provides `install`, `info`, `doctor`, `update`, and `self-update`, but not a standalone `create-bot-only` command.
- If `openclaw-lark` is already installed, this skill skips the assumption that setup is missing, but still uses the official install/configure flow to create or bind the bot.
- The official installer writes the newly created bot into the top-level default Feishu config. When creating a second bot, archive the old default first if you want to keep both bots.
- The safest path for third and later bots is `create_additional_feishu_bot.sh`, because it bundles archive, create, bind, and verify into one flow.
- For true multi-bot isolation, prefer `session.dmScope = "per-account-channel-peer"`.
- For additional bots, store their credentials under `channels.feishu.accounts.<accountId>` and route by that `accountId`.
- After any create/rebind step, verify the final mapping. The most common mistake is mixing up `App ID`, `accountId`, and `agentId`.
- The binding helper updates `~/.openclaw/openclaw.json`, replaces the matching Feishu binding for the target `accountId`, and restarts the gateway by default.
