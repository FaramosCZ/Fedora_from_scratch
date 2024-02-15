#!/bin/bash

#----------------------------------------

cat << 'EOF' > /usr/local/bin/send_network_info.sh
#!/bin/bash

# Get hostname
hostname=$(hostname)

# Get local LAN IP
lan_ip=$(ip -br a | grep enp | awk '{print $3}')

# Get WiFi IP
wifi_ip=$(ip -br a | grep wl | awk '{print $3}')

sleep 10

# Send data to your webpage
curl -s "https://faramos.php5.cz/hw/?hostname=$hostname&ip_lan=$lan_ip&ip_wifi=$wifi_ip"

EOF

#----------------------------------------

chmod +x /usr/local/bin/send_network_info.sh

#----------------------------------------

cat << 'EOF' > /etc/systemd/system/network-info.service

[Unit]
Description=Send Network Info to Webpage on Network Connection
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/send_network_info.sh

[Install]
WantedBy=multi-user.target

EOF

#----------------------------------------

systemctl daemon-reload
systemctl enable network-info.service

#----------------------------------------
