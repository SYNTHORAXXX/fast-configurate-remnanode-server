#!/bin/bash

#     IP    Docker
#   Ubuntu/Debian

set -e #   

#   root
if [[ $EUID -ne 0 ]]; then
   echo "      root (sudo)"
   exit 1
fi

ech

## 1.  IPSET  
## 1. Настройка IPSET и блокировка
echo "[*] Установка ipset и iptables-persistent"
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
apt-get update && apt-get install -yq ipset iptables-persistent

echo "ipset  UA ..."
#  ,     
ipset create UA hash:net 2>/dev/null || ipset flush UA

echo "[*]  IP  (   )..."
curl -s https://www.ipdeny.com/ipblocks/data/countries/ua.zone | while read ip; do
    if [ -n "$ip" ]; then
        ipset add UA "$ip"
    fi
done

echo "[*]   iptables..."
# ,     ,   
if ! iptables -C INPUT -m set --match-set UA src -j DROP 2>/dev/null; then
    iptables -A INPUT   -m set --match-set UA src -j DROP
    iptables -A OUTPUT  -m set --match-set UA dst -j DROP
    iptables -A FORWARD -m set --match-set UA src -j DROP
    iptables -A FORWARD -m set --match-set UA dst -j DROP
fi

#  
ipset save > /etc/ipset.conf
netfilter-persistent save

## 2.   
echo "крон задача"
cat > /etc/cron.weekly/update-ua-ipset << 'EOF'
#!/bin/bash
ipset flush UA
curl -s https://www.ipdeny.com/ipblocks/data/countries/ua.zone | while read ip; do
    [ -n "$ip" ] && ipset add UA "$ip"
done
ipset save > /etc/ipset.conf
EOF
chmod +x /etc/cron.weekly/update-ua-ipset

## 3.  Logrotate  Docker
echo "ротация логов"
cat > /etc/logrotate.d/docker-remnanode << 'EOF'
/var/lib/docker/containers/*/*.log {
    daily
    rotate 180
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d
}
EOF

#   logrotate
logrotate -d /etc/logrotate.d/docker-remnanode > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[+] Logrotate  ."
else
    echo "[!]    Logrotate."
fi

echo "---  ! ---"
echo " ipset ( 5 ):"
ipset list UA | head -n 10
echo " iptables:"
iptables -L -v | grep UA
