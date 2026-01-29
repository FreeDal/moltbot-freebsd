#!/bin/sh
#
# Clawdbot FreeBSD Installation Script
# 
# Usage: 
#   sh install-clawdbot-freebsd.sh
#
# This script installs Clawdbot and all required dependencies on FreeBSD.
# Run as root or with sudo/doas.

set -e

CLAWDBOT_VERSION="latest"
CLAWDBOT_USER="clawdbot"
CLAWDBOT_HOME="/var/db/clawdbot"
CLAWDBOT_CONFIG="/usr/local/etc/clawdbot"

echo "=========================================="
echo "Clawdbot FreeBSD Installer"
echo "=========================================="
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Detect FreeBSD version
FREEBSD_VERSION=$(freebsd-version -u | cut -d'-' -f1)
echo "Detected FreeBSD ${FREEBSD_VERSION}"

# Step 1: Install system packages
echo ""
echo "[1/6] Installing system packages..."
pkg install -y \
    node22 \
    npm-node22 \
    git \
    rust \
    gcc \
    python311 \
    pkgconf \
    vips

# Step 2: Install Clawdbot via npm
echo ""
echo "[2/6] Installing Clawdbot via npm..."
npm install -g clawdbot

# Step 3: Install build dependencies for native modules
echo ""
echo "[3/6] Installing Node.js build dependencies..."
cd /usr/local/lib/node_modules/clawdbot
npm install node-addon-api node-gyp --save-dev

# Step 4: Build clipboard module for FreeBSD
echo ""
echo "[4/6] Building clipboard native module..."
cd /usr/local/lib/node_modules/clawdbot/node_modules/@mariozechner/clipboard
npm install @napi-rs/cli
npx napi build --platform --release

# Step 5: Rebuild sharp for FreeBSD
echo ""
echo "[5/6] Rebuilding sharp image processing module..."
cd /usr/local/lib/node_modules/clawdbot
npm rebuild sharp

# Step 6: Create user and directories
echo ""
echo "[6/6] Setting up user and directories..."

# Create clawdbot user if it doesn't exist
if ! pw user show "${CLAWDBOT_USER}" >/dev/null 2>&1; then
    pw useradd "${CLAWDBOT_USER}" -m -d "${CLAWDBOT_HOME}" -s /usr/sbin/nologin -c "Clawdbot AI Assistant"
    echo "Created user: ${CLAWDBOT_USER}"
fi

# Create config directory
mkdir -p "${CLAWDBOT_CONFIG}"
chown "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_CONFIG}"

# Create workspace directory
mkdir -p "${CLAWDBOT_HOME}"
chown "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_HOME}"

# Create log directory
touch /var/log/clawdbot.log
chown "${CLAWDBOT_USER}:${CLAWDBOT_USER}" /var/log/clawdbot.log

# Install rc.d script
cat > /usr/local/etc/rc.d/clawdbot << 'RCEOF'
#!/bin/sh

# PROVIDE: clawdbot
# REQUIRE: LOGIN DAEMON NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="clawdbot"
rcvar="${name}_enable"

load_rc_config $name

: ${clawdbot_enable:="NO"}
: ${clawdbot_user:="clawdbot"}
: ${clawdbot_config:="/usr/local/etc/clawdbot/config.yaml"}
: ${clawdbot_workspace:="/var/db/clawdbot"}
: ${clawdbot_logfile:="/var/log/clawdbot.log"}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
clawdbot_cmd="/usr/local/bin/clawdbot"

command_args="-f -p ${pidfile} -o ${clawdbot_logfile} \
    /usr/bin/env HOME=${clawdbot_workspace} \
    ${clawdbot_cmd} gateway start --config ${clawdbot_config}"

start_precmd="${name}_prestart"

clawdbot_prestart()
{
    if [ ! -d "${clawdbot_workspace}" ]; then
        mkdir -p "${clawdbot_workspace}"
        chown "${clawdbot_user}:${clawdbot_user}" "${clawdbot_workspace}"
    fi
    if [ ! -f "${clawdbot_logfile}" ]; then
        touch "${clawdbot_logfile}"
        chown "${clawdbot_user}:${clawdbot_user}" "${clawdbot_logfile}"
    fi
}

run_rc_command "$1"
RCEOF

chmod +x /usr/local/etc/rc.d/clawdbot

# Verify installation
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""

INSTALLED_VERSION=$(clawdbot --version 2>/dev/null || echo "unknown")
echo "Clawdbot version: ${INSTALLED_VERSION}"
echo ""
echo "Next steps:"
echo ""
echo "1. Run the setup wizard:"
echo "   clawdbot wizard"
echo ""
echo "2. Or create config manually at:"
echo "   ${CLAWDBOT_CONFIG}/config.yaml"
echo ""
echo "3. Enable and start the service:"
echo "   sysrc clawdbot_enable=YES"
echo "   service clawdbot start"
echo ""
echo "4. Check logs:"
echo "   tail -f /var/log/clawdbot.log"
echo ""
