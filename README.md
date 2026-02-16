# OpenClaw FreeBSD Installer

One-line installer for [OpenClaw](https://github.com/openclaw/openclaw) (formerly Moltbot/Clawdbot) on FreeBSD 14.x.

Handles all the native module compilation that typically breaks on BSD — no manual intervention needed.

## Quick Install

We recommend downloading and reviewing the script first:

```sh
fetch https://bsdmacao.org/install/openclaw.sh
less openclaw.sh
sh openclaw.sh
```

Or if you prefer a one-liner:

```sh
fetch -o - https://bsdmacao.org/install/openclaw.sh | sh
```

## What It Does

1. **Installs system packages** — Node.js 22, npm, Rust, gcc, Python, vips
2. **Installs build tools** — node-gyp, node-addon-api
3. **Installs OpenClaw** — via `npm install -g openclaw`
4. **Builds native modules** — clipboard (Rust/napi-rs), sharp (libvips)
5. **Creates system user** — `openclaw` with home at `/var/db/openclaw`
6. **Installs rc.d service** — FreeBSD-native service management

## Post-Install Setup

```sh
# 1. Initialize (as openclaw user)
su -l openclaw -c 'openclaw onboard --mode local --workspace /var/db/openclaw/workspace'

# 2. Configure AI provider
su -l openclaw -c 'openclaw configure'

# 3. Enable and start service
sysrc openclaw_enable=YES
service openclaw start

# 4. Check logs
tail -f /var/log/openclaw.log
```

## Requirements

- FreeBSD 14.x (tested on 14.3-RELEASE)
- Root access
- Internet connection
- ~2GB disk space (packages + build)

## File Locations

| Path | Purpose |
|------|---------|
| `/usr/local/bin/openclaw` | OpenClaw binary |
| `/usr/local/lib/node_modules/openclaw` | Installed package |
| `/var/db/openclaw` | User home & workspace |
| `/var/db/openclaw/.openclaw/openclaw.json` | Configuration |
| `/var/log/openclaw.log` | Service logs |
| `/usr/local/etc/rc.d/openclaw` | Service script |

## Service Management

```sh
service openclaw start     # Start the gateway
service openclaw stop      # Stop the gateway
service openclaw restart   # Restart
service openclaw status    # Check if running
```

## Troubleshooting

### Clipboard module build fails

```sh
cd /usr/local/lib/node_modules/openclaw/node_modules/@mariozechner/clipboard
npm install @napi-rs/cli
npx napi build --platform --release
```

### Sharp module issues

```sh
cd /usr/local/lib/node_modules/openclaw
npm rebuild sharp
```

### Permission issues

```sh
chown -R openclaw:openclaw /var/db/openclaw
```

### Config file location

The config lives at `/var/db/openclaw/.openclaw/openclaw.json`.

## Upgrading from Moltbot/Clawdbot

If you have an existing moltbot or clawdbot installation:

```sh
# Stop old service
service moltbot stop  # or: service clawdbot stop

# Run the new installer
fetch -o - https://bsdmacao.org/install/openclaw.sh | sh

# Migrate config (if needed)
cp -r /var/db/moltbot/.clawdbot/* /var/db/openclaw/.openclaw/
chown -R openclaw:openclaw /var/db/openclaw

# Start new service
sysrc openclaw_enable=YES
service openclaw start
```

## About

Built by [BSD Macao](https://bsdmacao.org) — a FreeBSD group in Hong Kong/Macau.

- **Website:** https://bsdmacao.org
- **Issues:** https://github.com/FreeDal/moltbot-freebsd/issues
- **OpenClaw Docs:** https://docs.openclaw.ai

## License

MIT
