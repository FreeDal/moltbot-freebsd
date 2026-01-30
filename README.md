# Moltbot FreeBSD Installer

One-line installer for [Moltbot](https://github.com/clawdbot/clawdbot) (formerly Clawdbot) on FreeBSD 14.x.

Handles all the native module compilation that typically breaks on BSD — no manual intervention needed.

## Quick Install

```sh
fetch -o - https://bsdmacao.org/install/moltbot.sh | sh
```

Or download first and review:

```sh
fetch https://bsdmacao.org/install/moltbot.sh
less moltbot.sh
sh moltbot.sh
```

## What It Does

1. **Installs system packages** — Node.js 22, npm, Rust, gcc, Python, vips
2. **Installs build tools** — node-gyp, node-addon-api
3. **Installs Moltbot** — via `npm install -g clawdbot`
4. **Builds native modules** — clipboard (Rust/napi-rs), sharp (libvips)
5. **Creates system user** — `moltbot` with home at `/var/db/moltbot`
6. **Installs rc.d service** — FreeBSD-native service management

## Post-Install Setup

```sh
# 1. Initialize (as moltbot user)
su -l moltbot -c 'moltbot onboard --mode local --workspace /var/db/moltbot/workspace'

# 2. Configure AI provider
su -l moltbot -c 'moltbot configure'

# 3. Enable and start service
sysrc moltbot_enable=YES
service moltbot start

# 4. Check logs
tail -f /var/log/moltbot.log
```

## Requirements

- FreeBSD 14.x (tested on 14.3-RELEASE)
- Root access
- Internet connection
- ~2GB disk space (packages + build)

## File Locations

| Path | Purpose |
|------|---------|
| `/usr/local/bin/moltbot` | Symlink to clawdbot binary |
| `/usr/local/lib/node_modules/clawdbot` | Installed package |
| `/var/db/moltbot` | User home & workspace |
| `/var/db/moltbot/.clawdbot/clawdbot.json` | Configuration |
| `/var/log/moltbot.log` | Service logs |
| `/usr/local/etc/rc.d/moltbot` | Service script |

## Service Management

```sh
service moltbot start     # Start the gateway
service moltbot stop      # Stop the gateway
service moltbot restart   # Restart
service moltbot status    # Check if running
```

## Troubleshooting

### Clipboard module build fails

```sh
cd /usr/local/lib/node_modules/clawdbot/node_modules/@mariozechner/clipboard
npm install @napi-rs/cli
npx napi build --platform --release
```

### Sharp module issues

```sh
cd /usr/local/lib/node_modules/clawdbot
npm rebuild sharp
```

### Permission issues

```sh
chown -R moltbot:moltbot /var/db/moltbot
```

### Config file location

The config lives at `/var/db/moltbot/.clawdbot/clawdbot.json` (note: uses `clawdbot` naming internally as the npm package hasn't been renamed yet).

## About

Built by [BSD Macao](https://bsdmacao.org) — a FreeBSD group in Hong Kong/Macau.

- **Website:** https://bsdmacao.org
- **Issues:** https://github.com/FreeDal/moltbot-freebsd/issues
- **Moltbot Docs:** https://docs.molt.bot

## License

MIT
