#!/bin/bash
# Stable VPN Optimization Script
# Focus: Low Latency + Telegram Stability

echo "==== VPN Stable Optimization ===="

# Detect interface automatically
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Interface detected: $IFACE"

# Detect CPU count
CPU_COUNT=$(nproc)
echo "CPU cores: $CPU_COUNT"

# Generate proper RPS mask
if [ "$CPU_COUNT" -le 32 ]; then
    RPS_MASK=$(( (1 << CPU_COUNT) - 1 ))
else
    RPS_MASK=$(( (1 << 32) - 1 ))
fi

RPS_MASK_HEX=$(printf '%x\n' $RPS_MASK)
echo "RPS mask: $RPS_MASK_HEX"

# Apply RPS safely
for i in /sys/class/net/$IFACE/queues/rx-*/rps_cpus; do
    echo $RPS_MASK_HEX > $i
done

# Moderate RFS (not aggressive)
echo 32768 > /proc/sys/net/core/rps_sock_flow_entries
for i in /sys/class/net/$IFACE/queues/rx-*/rps_flow_cnt; do
    echo 2048 > $i
done

# Clean old sysctl duplicates
sed -i '/vpn_stable_start/,/vpn_stable_end/d' /etc/sysctl.conf

# Add stable sysctl config
cat >> /etc/sysctl.conf <<EOF
# vpn_stable_start
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fin_timeout=20
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=4096
# vpn_stable_end
EOF

sysctl -p

# Enable offloading safely
ethtool -K $IFACE tso on gso on gro on 2>/dev/null

echo "==== Optimization Applied Successfully ===="
echo "Reboot not required."
