#!/bin/sh
#
# Moltbot FreeBSD Installation Script
# https://bsdmacao.org
# 
# Usage: 
#   fetch -o - https://bsdmacao.org/install/moltbot.sh | sh
#
# Installs Moltbot and all required dependencies on FreeBSD 14+

set -e

# Colors (will show as codes if terminal doesn't support)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOLTBOT_USER="moltbot"
MOLTBOT_HOME="/var/db/moltbot"

printf "\n"
printf "${BLUE}==========================================${NC}\n"
printf "${BLUE}  Moltbot FreeBSD Installer${NC}\n"
printf "${BLUE}  https://bsdmacao.org${NC}\n"
printf "${BLUE}==========================================${NC}\n"
printf "\n"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    printf "${RED}Error: This script must be run as root${NC}\n"
    exit 1
fi

# Check FreeBSD version
FREEBSD_MAJOR=$(freebsd-version -u | cut -d'.' -f1)
if [ "$FREEBSD_MAJOR" -lt 14 ]; then
    printf "${YELLOW}Warning: This script is tested on FreeBSD 14+${NC}\n"
    printf "Detected: $(freebsd-version -u)\n"
    printf "Continuing anyway...\n"
fi

printf "Detected FreeBSD $(freebsd-version -u)\n"
printf "\n"

# Step 1: Install system packages
printf "${YELLOW}[1/7]${NC} Installing system packages...\n"
env ASSUME_ALWAYS_YES=yes pkg bootstrap >/dev/null 2>&1 || true
pkg install -y \
    node22 \
    npm-node22 \
    git \
    rust \
    gcc \
    python311 \
    pkgconf \
    vips >/dev/null 2>&1

printf "${GREEN}✓${NC} System packages installed\n"

# Step 2: Install node-gyp globally first (needed for native module builds)
printf "${YELLOW}[2/7]${NC} Installing Node.js build tools...\n"
npm install -g --force node-gyp node-addon-api >/dev/null 2>&1 || true
printf "${GREEN}✓${NC} Build tools installed\n"

# Note: npm package is still 'clawdbot', will be renamed to 'moltbot' eventually
NPM_PKG="clawdbot"
PKG_DIR="/usr/local/lib/node_modules/${NPM_PKG}"

# Step 3: Install Moltbot via npm (may have warnings about native modules, that's OK)
printf "${YELLOW}[3/7]${NC} Installing Moltbot via npm (this takes a minute)...\n"
npm install -g --force ${NPM_PKG} 2>&1 | grep -v "^npm " || true

# Check if installed (even with errors)
if [ ! -d "${PKG_DIR}" ]; then
    printf "${RED}Error: Moltbot installation failed${NC}\n"
    exit 1
fi
printf "${GREEN}✓${NC} Moltbot package installed\n"

# Step 4: Install build dependencies in package directory
printf "${YELLOW}[4/7]${NC} Installing native module dependencies...\n"
cd "${PKG_DIR}"
npm install node-addon-api node-gyp --save-dev >/dev/null 2>&1
printf "${GREEN}✓${NC} Dependencies installed\n"

# Step 5: Build clipboard module for FreeBSD
printf "${YELLOW}[5/7]${NC} Building clipboard native module (this takes ~2 minutes)...\n"
cd "${PKG_DIR}/node_modules/@mariozechner/clipboard"
npm install @napi-rs/cli >/dev/null 2>&1
npx napi build --platform --release 2>&1 | grep -E "(Compiling|Finished|error)" || true
printf "${GREEN}✓${NC} clipboard.freebsd-x64.node built\n"

# Step 6: Rebuild sharp for FreeBSD
printf "${YELLOW}[6/7]${NC} Rebuilding sharp image processing module...\n"
cd "${PKG_DIR}"
npm rebuild sharp >/dev/null 2>&1
printf "${GREEN}✓${NC} sharp rebuilt\n"

# Create moltbot symlink to clawdbot binary
if [ -f "/usr/local/bin/clawdbot" ] && [ ! -f "/usr/local/bin/moltbot" ]; then
    ln -s /usr/local/bin/clawdbot /usr/local/bin/moltbot
fi

# Step 7: Create user and directories
printf "${YELLOW}[7/7]${NC} Setting up user and directories...\n"

# Create moltbot user if it doesn't exist
if ! pw user show "${MOLTBOT_USER}" >/dev/null 2>&1; then
    pw useradd "${MOLTBOT_USER}" -m -d "${MOLTBOT_HOME}" -s /bin/sh -c "Moltbot AI Assistant"
fi

# Create directories
mkdir -p "${MOLTBOT_HOME}"
chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_HOME}"
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
: ${moltbot_home:="/var/db/moltbot"}
: ${moltbot_logfile:="/var/log/moltbot.log"}
: ${moltbot_port:="18789"}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
moltbot_cmd="/usr/local/bin/moltbot"

command_args="-f -p ${pidfile} -u ${moltbot_user} -o ${moltbot_logfile} \
    /usr/bin/env HOME=${moltbot_home} \
    ${moltbot_cmd} gateway run --port ${moltbot_port}"

start_precmd="${name}_prestart"

moltbot_prestart()
{
    if [ ! -d "${moltbot_home}" ]; then
        mkdir -p "${moltbot_home}"
        chown "${moltbot_user}:${moltbot_user}" "${moltbot_home}"
    fi
    if [ ! -f "${moltbot_logfile}" ]; then
        touch "${moltbot_logfile}"
        chown "${moltbot_user}:${moltbot_user}" "${moltbot_logfile}"
    fi
    if [ ! -f "${moltbot_home}/.clawdbot/clawdbot.json" ]; then
        echo "Warning: Run 'su -l ${moltbot_user} -c \"moltbot onboard --mode local\"' first"
        return 1
    fi
}

run_rc_command "$1"
RCEOF

chmod +x /usr/local/etc/rc.d/moltbot
printf "${GREEN}✓${NC} Service script installed\n"

# Verify installation
INSTALLED_VERSION=$(moltbot --version 2>/dev/null || echo "unknown")

printf "\n"
printf "${GREEN}==========================================${NC}\n"
printf "${GREEN}  Installation Complete!${NC}\n"
printf "${GREEN}==========================================${NC}\n"
printf "\n"
printf "Moltbot version: ${BLUE}${INSTALLED_VERSION}${NC}\n"
printf "\n"
printf "${YELLOW}Next steps:${NC}\n"
printf "\n"
printf "1. Initialize Moltbot (as moltbot user):\n"
printf "   ${BLUE}su -l moltbot -c 'moltbot onboard --mode local --workspace /var/db/moltbot/workspace'${NC}\n"
printf "\n"
printf "2. Configure your AI provider (Claude API key, etc.):\n"
printf "   ${BLUE}su -l moltbot -c 'moltbot configure'${NC}\n"
printf "\n"
printf "3. Enable and start the service:\n"
printf "   ${BLUE}sysrc moltbot_enable=YES${NC}\n"
printf "   ${BLUE}service moltbot start${NC}\n"
printf "\n"
printf "4. Check logs:\n"
printf "   ${BLUE}tail -f /var/log/moltbot.log${NC}\n"
printf "\n"
printf "Docs: https://docs.molt.bot\n"
printf "BSD Macao: https://bsdmacao.org\n"
printf "\n"
