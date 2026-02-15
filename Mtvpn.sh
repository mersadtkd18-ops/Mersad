#!/bin/bash
# VPN Optimization Script - Auto CPU Detection
# اجرا با دسترسی root

# تعداد هسته‌ها
CPU_COUNT=$(nproc)
echo "==> تعداد هسته‌ها: $CPU_COUNT"

# 🔹 محاسبه ماسک RPS
# هر بیت یک CPU
# مثال: 3 هسته -> 111 (binary) = 7
#        8 هسته -> 11111111 (binary) = ff
if [ "$CPU_COUNT" -le 32 ]; then
    # حداکثر 32 بیت
    RPS_MASK=$(( (1 << CPU_COUNT) - 1 ))
else
    echo "⚠️ بیش از 32 هسته، فقط 32 هسته اول استفاده می‌شوند."
    RPS_MASK=$(( (1 << 32) - 1 ))
fi

# تبدیل به hex
RPS_MASK_HEX=$(printf '%x\n' $RPS_MASK)
echo "==> ماسک RPS انتخاب شده (hex): $RPS_MASK_HEX"

# 1️⃣ تنظیم RPS روی همه RX queue ها
for i in /sys/class/net/eth0/queues/rx-*/rps_cpus; do
    echo $RPS_MASK_HEX > $i
done
echo "✅ RPS تنظیم شد."

# 2️⃣ تنظیم RFS
echo 65536 > /proc/sys/net/core/rps_sock_flow_entries
for i in /sys/class/net/eth0/queues/rx-*/rps_flow_cnt; do
    echo 4096 > $i
done
echo "✅ RFS تنظیم شد."

# 3️⃣ فعال کردن BBR
grep -q "bbr" /proc/sys/net/ipv4/tcp_congestion_control
if [ $? -ne 0 ]; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi
echo "✅ BBR فعال شد."
sysctl net.ipv4.tcp_congestion_control

# 4️⃣ فعال کردن TSO / GSO / GRO
ethtool -K eth0 tso on gso on gro on
echo "✅ TSO/GSO/GRO فعال شد."

echo "🎉 همه بهینه‌سازی‌ها اعمال شد."
echo "💡 بعد از ریبوت، دوباره این اسکریپت را اجرا کنید تا تنظیمات حفظ شوند."
