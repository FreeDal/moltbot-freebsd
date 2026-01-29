#!/bin/sh
#
# Moltbot FreeBSD Installation Script
# 
# Usage: 
#   sh install-moltbot-freebsd.sh
#
# This script installs Moltbot and all required dependencies on FreeBSD.
# Run as root or with sudo/doas.

set -e

MOLTBOT_VERSION="latest"
MOLTBOT_USER="moltbot"
MOLTBOT_HOME="/var/db/moltbot"
MOLTBOT_CONFIG="/usr/local/etc/moltbot"

echo "=========================================="
echo "Moltbot FreeBSD Installer"
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

# Step 2: Install Moltbot via npm
echo ""
echo "[2/6] Installing Moltbot via npm..."
npm install -g moltbot

# Step 3: Install build dependencies for native modules
echo ""
echo "[3/6] Installing Node.js build dependencies..."
cd /usr/local/lib/node_modules/moltbot
npm install node-addon-api node-gyp --save-dev

# Step 4: Build clipboard module for FreeBSD
echo ""
echo "[4/6] Building clipboard native module..."
cd /usr/local/lib/node_modules/moltbot/node_modules/@mariozechner/clipboard
npm install @napi-rs/cli
npx napi build --platform --release

# Step 5: Rebuild sharp for FreeBSD
echo ""
echo "[5/6] Rebuilding sharp image processing module..."
cd /usr/local/lib/node_modules/moltbot
npm rebuild sharp

# Step 6: Create user and directories
echo ""
echo "[6/6] Setting up user and directories..."

# Create moltbot user if it doesn't exist
if ! pw user show "${MOLTBOT_USER}" >/dev/null 2>&1; then
    pw useradd "${MOLTBOT_USER}" -m -d "${MOLTBOT_HOME}" -s /usr/sbin/nologin -c "Moltbot AI Assistant"
    echo "Created user: ${MOLTBOT_USER}"
fi

# Create config directory
mkdir -p "${MOLTBOT_CONFIG}"
chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_CONFIG}"

# Create workspace directory
mkdir -p "${MOLTBOT_HOME}"
chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_HOME}"

# Create log directory
touch /var/log/moltbot.log
chown "${MOLTBOT_USER}:${MOLTBOT_USER}" /var/log/moltbot.log

# Install rc.d script
cat > /usr/local/etc/rc.d/moltbot << 'RCEOF'
#!/bin/sh

# PROVIDE: moltbot
# REQUIRE: LOGIN DAEMON NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="moltbot"
rcvar="${name}_enable"

load_rc_config $name

: ${moltbot_enable:="NO"}
: ${moltbot_user:="moltbot"}
: ${moltbot_config:="/usr/local/etc/moltbot/config.yaml"}
: ${moltbot_workspace:="/var/db/moltbot"}
: ${moltbot_logfile:="/var/log/moltbot.log"}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
moltbot_cmd="/usr/local/bin/moltbot"

command_args="-f -p ${pidfile} -o ${moltbot_logfile} \
    /usr/bin/env HOME=${moltbot_workspace} \
    ${moltbot_cmd} gateway start --config ${moltbot_config}"

start_precmd="${name}_prestart"

moltbot_prestart()
{
    if [ ! -d "${moltbot_workspace}" ]; then
        mkdir -p "${moltbot_workspace}"
        chown "${moltbot_user}:${moltbot_user}" "${moltbot_workspace}"
    fi
    if [ ! -f "${moltbot_logfile}" ]; then
        touch "${moltbot_logfile}"
        chown "${moltbot_user}:${moltbot_user}" "${moltbot_logfile}"
    fi
}

run_rc_command "$1"
RCEOF

chmod +x /usr/local/etc/rc.d/moltbot

# Verify installation
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""

INSTALLED_VERSION=$(moltbot --version 2>/dev/null || echo "unknown")
echo "Moltbot version: ${INSTALLED_VERSION}"
echo ""
echo "Next steps:"
echo ""
echo "1. Run the setup wizard:"
echo "   moltbot wizard"
echo ""
echo "2. Or create config manually at:"
echo "   ${MOLTBOT_CONFIG}/config.yaml"
echo ""
echo "3. Enable and start the service:"
echo "   sysrc moltbot_enable=YES"
echo "   service moltbot start"
echo ""
echo "4. Check logs:"
echo "   tail -f /var/log/moltbot.log"
echo ""
