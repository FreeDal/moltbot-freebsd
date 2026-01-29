#!/bin/sh
# FreeBSD Server Documentation Generator
# Outputs system information to /tmp/server_documentation.txt
# Use: Run on any FreeBSD server, then feed output to AI for TOOLS.md updates

OUTPUT="/tmp/server_documentation.txt"

# Clear/create output file
> "$OUTPUT"

echo "Gathering system information... this may take a moment."

{
echo "========================================"
echo "FreeBSD Server Documentation"
echo "Generated: $(date)"
echo "========================================"
echo ""

echo "========================================"
echo "SYSTEM OVERVIEW"
echo "========================================"
echo ""
echo "Hostname: $(hostname)"
echo "OS: $(freebsd-version)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""
echo "CPU Information:"
sysctl -n hw.model
echo "CPU Cores: $(sysctl -n hw.ncpu)"
echo ""
echo "Memory:"
echo "Total RAM: $(( $(sysctl -n hw.physmem) / 1024 / 1024 / 1024 )) GB"
echo ""
echo "Uptime:"
uptime
echo ""

echo "========================================"
echo "STORAGE CONFIGURATION"
echo "========================================"
echo ""
echo "--- ZFS Pools ---"
echo ""
zpool list 2>/dev/null || echo "(no ZFS pools)"
echo ""
echo "--- ZFS Pool Status ---"
echo ""
zpool status 2>/dev/null || echo "(no ZFS pools)"
echo ""
echo "--- ZFS Pool IO Stats ---"
echo ""
zpool iostat 2>/dev/null || echo "(no ZFS pools)"
echo ""
echo "--- ZFS Datasets ---"
echo ""
zfs list 2>/dev/null || echo "(no ZFS datasets)"
echo ""
echo "--- ZFS Dataset Properties (mountpoint, compression, used, available) ---"
echo ""
zfs list -o name,mountpoint,compression,used,avail 2>/dev/null || echo "(no ZFS datasets)"
echo ""
echo "--- Disk Layout (GEOM) ---"
echo ""
geom disk list
echo ""
echo "--- GPT Partitions ---"
echo ""
gpart show -l 2>/dev/null || gpart show
echo ""

echo "========================================"
echo "NETWORK CONFIGURATION"
echo "========================================"
echo ""
echo "--- Network Interfaces ---"
echo ""
ifconfig -a
echo ""
echo "--- Routing Table ---"
echo ""
netstat -rn
echo ""
echo "--- DNS Configuration ---"
echo ""
echo "Contents of /etc/resolv.conf:"
cat /etc/resolv.conf 2>/dev/null || echo "(file not found)"
echo ""
if [ -f /etc/resolvconf.conf ]; then
    echo "Contents of /etc/resolvconf.conf:"
    cat /etc/resolvconf.conf
    echo ""
fi
echo "--- rc.conf Network Settings ---"
echo ""
grep -E '^(ifconfig_|defaultrouter|gateway_enable|ipv6|hostname|cloned_interfaces|create_args)' /etc/rc.conf 2>/dev/null || echo "(no network settings found)"
echo ""

echo "========================================"
echo "FIREWALL (PF)"
echo "========================================"
echo ""
if service pf status >/dev/null 2>&1; then
    echo "PF Status: Enabled"
    echo ""
    echo "--- PF Rules (/etc/pf.conf) ---"
    echo ""
    cat /etc/pf.conf 2>/dev/null || echo "(file not found)"
    echo ""
    echo "--- PF Active Rules ---"
    echo ""
    pfctl -sr 2>/dev/null || echo "(unable to read rules)"
    echo ""
    echo "--- PF NAT Rules ---"
    echo ""
    pfctl -sn 2>/dev/null || echo "(unable to read NAT rules)"
    echo ""
else
    echo "PF Status: Disabled or not installed"
    echo ""
fi

echo "========================================"
echo "JAIL CONFIGURATION"
echo "========================================"
echo ""
echo "--- Running Jails ---"
echo ""
jls 2>/dev/null || echo "(no jails running)"
echo ""

# Check for BastilleBSD
if command -v bastille >/dev/null 2>&1; then
    echo "--- BastilleBSD Configuration ---"
    echo ""
    echo "Bastille Version: $(bastille --version 2>/dev/null || echo 'unknown')"
    echo ""
    if [ -f /usr/local/etc/bastille/bastille.conf ]; then
        echo "Contents of bastille.conf:"
        cat /usr/local/etc/bastille/bastille.conf
        echo ""
    fi
    echo "--- Bastille Jail List ---"
    echo ""
    bastille list all 2>/dev/null || bastille list 2>/dev/null || echo "(unable to list jails)"
    echo ""
    echo "--- Bastille Releases ---"
    echo ""
    bastille list release 2>/dev/null || echo "(unable to list releases)"
    echo ""
    echo "--- Jail rc.conf Files ---"
    echo ""
    for jail_path in /usr/local/bastille/jails/*/root/etc/rc.conf; do
        if [ -f "$jail_path" ]; then
            jail_name=$(echo "$jail_path" | sed 's|.*/jails/||;s|/root/etc/rc.conf||')
            echo "=== $jail_name ==="
            cat "$jail_path"
            echo ""
        fi
    done
    echo "--- Bastille Fstab Mounts ---"
    echo ""
    for fstab in /usr/local/bastille/jails/*/fstab; do
        if [ -f "$fstab" ]; then
            jail_name=$(echo "$fstab" | sed 's|.*/jails/||;s|/fstab||')
            echo "=== $jail_name ==="
            cat "$fstab"
            echo ""
        fi
    done
fi

# Check for iocage
if command -v iocage >/dev/null 2>&1; then
    echo "--- iocage Jails ---"
    echo ""
    iocage list 2>/dev/null || echo "(unable to list iocage jails)"
    echo ""
fi

echo "========================================"
echo "BHYVE VIRTUAL MACHINES"
echo "========================================"
echo ""
if command -v vm >/dev/null 2>&1; then
    echo "--- vm-bhyve VMs ---"
    echo ""
    vm list 2>/dev/null || echo "(unable to list VMs)"
    echo ""
    echo "--- vm-bhyve Switches ---"
    echo ""
    vm switch list 2>/dev/null || echo "(unable to list switches)"
    echo ""
else
    echo "vm-bhyve not installed"
    echo ""
fi

# Check for raw bhyve VMs
if pgrep -q bhyve 2>/dev/null; then
    echo "--- Running bhyve Processes ---"
    echo ""
    ps aux | grep bhyve | grep -v grep
    echo ""
fi

echo "========================================"
echo "ENABLED SERVICES"
echo "========================================"
echo ""
echo "--- rc.conf Services ---"
echo ""
grep -E '_enable=' /etc/rc.conf 2>/dev/null | sort
echo ""
echo "--- Running Services ---"
echo ""
service -e 2>/dev/null || echo "(unable to list services)"
echo ""

echo "========================================"
echo "SCHEDULED TASKS (CRON)"
echo "========================================"
echo ""
echo "--- System Crontab (/etc/crontab) ---"
echo ""
cat /etc/crontab 2>/dev/null || echo "(file not found)"
echo ""
echo "--- Root Crontab ---"
echo ""
crontab -l 2>/dev/null || echo "(no crontab for root)"
echo ""
echo "--- /etc/cron.d/ ---"
echo ""
if [ -d /etc/cron.d ]; then
    for f in /etc/cron.d/*; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            cat "$f"
            echo ""
        fi
    done
else
    echo "(directory not found)"
fi
echo ""

echo "========================================"
echo "USER ACCOUNTS"
echo "========================================"
echo ""
echo "--- Local Users (UID >= 1000 and root) ---"
echo ""
awk -F: '($3 >= 1000 || $3 == 0) {printf "%-15s UID:%-6s Shell:%s\n", $1, $3, $7}' /etc/passwd
echo ""
echo "--- Groups ---"
echo ""
cat /etc/group
echo ""

echo "========================================"
echo "SYSTEM CONFIGURATION FILES"
echo "========================================"
echo ""
echo "--- /etc/rc.conf ---"
echo ""
cat /etc/rc.conf 2>/dev/null || echo "(file not found)"
echo ""
echo "--- /etc/sysctl.conf ---"
echo ""
cat /etc/sysctl.conf 2>/dev/null || echo "(file not found)"
echo ""
echo "--- /boot/loader.conf ---"
echo ""
cat /boot/loader.conf 2>/dev/null || echo "(file not found)"
echo ""

echo "========================================"
echo "INSTALLED PACKAGES"
echo "========================================"
echo ""
echo "--- Installed Packages ---"
echo ""
pkg info 2>/dev/null || echo "(pkg not available)"
echo ""

echo "========================================"
echo "BOOT ENVIRONMENTS"
echo "========================================"
echo ""
if command -v bectl >/dev/null 2>&1; then
    bectl list 2>/dev/null || echo "(unable to list boot environments)"
else
    echo "bectl not available"
fi
echo ""

echo "========================================"
echo "END OF DOCUMENTATION"
echo "========================================"

} >> "$OUTPUT" 2>&1

echo "Documentation complete. Output saved to: $OUTPUT"
echo "File size: $(ls -lh "$OUTPUT" | awk '{print $5}')"
