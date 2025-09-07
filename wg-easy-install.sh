#!/bin/bash

# Function to print characters with delay
print_with_delay() {
  text="$1"
  delay="$2"
  for ((i = 0; i < ${#text}; i++)); do
    echo -n "${text:$i:1}"
    sleep $delay
  done
  echo
}

# Introduction animation
echo ""
echo ""
print_with_delay "wg-easy-installer by DEATHLINE | @NamelesGhoul" 0.1
echo ""
echo ""

# Check for and install required packages
install_required_packages() {
  REQUIRED_PACKAGES=("curl" "docker.io" "docker-compose" "apache2-utils" "jq" "nginx" "certbot" "python3-certbot-nginx")
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! command -v $pkg &> /dev/null; then
      apt-get update > /dev/null 2>&1
      apt-get install -y $pkg > /dev/null 2>&1
    fi
  done
}

# Function to configure Nginx reverse proxy with SSL (custom port only, no 80/443)
configure_nginx() {
  local domain="$1"
  local ui_port="$2"
  local public_ip="$3"

  if [ -z "$domain" ]; then
    return
  fi

  systemctl stop nginx > /dev/null 2>&1

  certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$domain" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Failed to obtain SSL certificate. Check domain DNS and ensure no conflicts during validation."
    exit 1
  fi

  cat << EOF > /etc/nginx/sites-available/wg-easy
server {
    listen $ui_port ssl;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://localhost:51822;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

  ln -sf /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/
  nginx -t > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed."
    exit 1
  fi

  systemctl restart nginx > /dev/null 2>&1
}

# Main menu loop for existing installation
if [ -d "/opt/wg-easy" ]; then
  while true; do
    echo "wg-easy is already installed."
    echo ""
    echo "Choose an option:"
    echo ""
    echo "1) Uninstall"
    echo ""
    echo "2) Toggle SSL Mode (switch between domain/SSL and no-domain/insecure HTTP)"
    echo ""
    echo "3) Modify Ports"
    echo ""
    echo "4) Exit"
    echo ""
    read -p "Enter your choice: " choice
    case $choice in
      1)
        cd /opt/wg-easy
        docker-compose down > /dev/null 2>&1
        docker rm wg-easy > /dev/null 2>&1
        docker network rm wg > /dev/null 2>&1
        rm -rf /opt/wg-easy
        rm -f /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/wg-easy
        systemctl restart nginx > /dev/null 2>&1
        echo ""
        echo "wg-easy uninstalled successfully!"
        echo ""
        exit 0
        ;;
      2)
        cd /opt/wg-easy
        # Find current ports. Note: Grep must now match the port number on BOTH sides.
        current_ui_port=$(grep -oP '"\K[0-9]+:51821/tcp' docker-compose.yml | cut -d':' -f1)
        current_wg_port=$(grep -oP '"\K[0-9]+:[0-9]+/udp' docker-compose.yml | grep -E '([0-9]+):\1' | cut -d':' -f1)
        [ -z "$current_wg_port" ] && current_wg_port=$(grep -oP '"\K[0-9]+:51820/udp' docker-compose.yml | cut -d':' -f1) # Fallback for old config
        
        current_domain=$(grep -oP 'server_name \K[^;]+' /etc/nginx/sites-available/wg-easy 2>/dev/null || echo "")

        echo ""
        read -p "Enter domain for SSL (or press enter to disable SSL and use insecure HTTP on IP): " new_domain
        [ -z "$new_domain" ] && new_domain=""

        new_ip=$(curl -s https://api.ipify.org)
        if [ -z "$new_ip" ]; then
          echo "Failed to detect public IP."
          exit 1
        fi
        if ! [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Invalid IP format."
          exit 1
        fi
        
        local_host_ip=$new_ip # Use Public IP for WG_HOST if no domain

        if [ -n "$new_domain" ]; then
          ui_mapping="- \"127.0.0.1:51822:51821/tcp\""
          new_ui_port=$current_ui_port
          local_host_ip=$new_domain # Use Domain for WG_HOST
        else
          echo ""
          read -p "Enter new web UI port for insecure mode (default 51821): " new_ui_port
          [ -z "$new_ui_port" ] && new_ui_port=51821
          ui_mapping="- \"$new_ui_port:51821/tcp\""
          rm -f /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/wg-easy
          systemctl restart nginx > /dev/null 2>&1
        fi

        cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - INSECURE=true
      - WG_HOST=$local_host_ip
      - WG_PORT=$current_wg_port
    image: ghcr.io/wg-easy/wg-easy:15.1
    container_name: wg-easy
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - .:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - "$current_wg_port:$current_wg_port/udp"
      $ui_mapping
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
networks:
  wg:
    ipam:
      config:
        - subnet: 10.42.42.0/24
        - subnet: fdcc:ad94:bacf:61a3::/64
EOF

        docker-compose config > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "Invalid docker-compose.yml syntax."
          exit 1
        fi

        docker-compose down > /dev/null 2>&1
        docker-compose up -d > /dev/null 2>&1

        if [ -n "$new_domain" ]; then
          configure_nginx "$new_domain" "$current_ui_port" "$new_ip"
          echo ""
          echo "SSL mode enabled!"
          echo "Web UI: https://$new_domain:$current_ui_port"
        else
          echo ""
          echo "Insecure mode enabled!"
          echo "Web UI: http://$new_ip:$new_ui_port (insecure - no SSL)"
        fi
        echo ""
        exit 0
        ;;
      3)
        cd /opt/wg-easy
        current_ui_port=$(grep -oP '"\K[0-9]+:51821/tcp' docker-compose.yml | cut -d':' -f1)
        current_wg_port=$(grep -oP '"\K[0-9]+:[0-9]+/udp' docker-compose.yml | grep -E '([0-9]+):\1' | cut -d':' -f1)
        [ -z "$current_wg_port" ] && current_wg_port=$(grep -oP '"\K[0-9]+:51820/udp' docker-compose.yml | cut -d':' -f1) # Fallback

        current_domain=$(grep -oP 'server_name \K[^;]+' /etc/nginx/sites-available/wg-easy 2>/dev/null || echo "")

        echo ""
        read -p "Enter new web UI port (or press enter to keep [$current_ui_port]): " new_ui_port
        [ -z "$new_ui_port" ] && new_ui_port=$current_ui_port
        echo ""
        read -p "Enter new WireGuard port (or press enter to keep [$current_wg_port]): " new_wg_port
        [ -z "$new_wg_port" ] && new_wg_port=$current_wg_port
        echo ""

        new_ip=$(curl -s https://api.ipify.org)
        if [ -z "$new_ip" ]; then
          echo "Failed to detect public IP."
          exit 1
        fi
        if ! [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Invalid IP format."
          exit 1
        fi

        if [ -n "$current_domain" ]; then
          ui_mapping="- \"127.0.0.1:51822:51821/tcp\""
          local_host_ip=$current_domain # Use Domain for WG_HOST
        else
          ui_mapping="- \"$new_ui_port:51821/tcp\""
          local_host_ip=$new_ip # Use Public IP for WG_HOST
        fi

        cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - INSECURE=true
      - WG_HOST=$local_host_ip
      - WG_PORT=$new_wg_port
    image: ghcr.io/wg-easy/wg-easy:15.1
    container_name: wg-easy
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - .:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - "$new_wg_port:$new_wg_port/udp"
      $ui_mapping
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
networks:
  wg:
    ipam:
      config:
        - subnet: 10.42.42.0/24
        - subnet: fdcc:ad94:bacf:61a3::/64
EOF

        docker-compose config > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "Invalid docker-compose.yml syntax."
          exit 1
        fi

        docker-compose down > /dev/null 2>&1
        docker-compose up -d > /dev/null 2>&1

        if [ -n "$current_domain" ]; then
          configure_nginx "$current_domain" "$new_ui_port" "$new_ip"
        fi

        echo ""
        echo "Ports updated successfully!"
        echo ""
        if [ -n "$current_domain" ]; then
          echo "Web UI: https://$current_domain:$new_ui_port"
        else
          echo "Web UI: http://$new_ip:$new_ui_port (insecure - no SSL)"
        fi
        echo "WireGuard port: $new_wg_port/UDP"
        echo ""
        echo "Notes:"
        echo "- The client configs generated by the UI will now use host $local_host_ip and port $new_wg_port."
        echo ""
        exit 0
        ;;
      4)
        exit 0
        ;;
      *)
        echo "Invalid choice."
        ;;
    esac
  done
fi

install_required_packages

OS="$(uname -s)"
ARCH="$(uname -m)"
if [ "$OS" != "Linux" ]; then
  echo "Unsupported OS"
  exit 1
fi
case "$ARCH" in
  x86_64|amd64|arm64) ;;
  *) echo "Unsupported architecture"; exit 1;;
esac

PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
  echo "Failed to detect public IP."
  exit 1
fi
if ! [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid IP format."
  exit 1
fi

echo ""
read -p "Enter domain for SSL (e.g., wg.example.com, or press enter for insecure HTTP on IP): " DOMAIN
echo ""
read -p "Enter web UI port (or press enter for 51821): " UI_PORT
[ -z "$UI_PORT" ] && UI_PORT=51821
echo ""
read -p "Enter WireGuard port (or press enter for 51820): " WG_PORT
[ -z "$WG_PORT" ] && WG_PORT=51820

mkdir -p /opt/wg-easy
cd /opt/wg-easy
chmod -R 755 /opt/wg-easy

if [ -n "$DOMAIN" ]; then
  ui_mapping="- \"127.0.0.1:51822:51821/tcp\""
  LOCAL_HOST_IP=$DOMAIN # Use Domain for WG_HOST
else
  ui_mapping="- \"$UI_PORT:51821/tcp\""
  LOCAL_HOST_IP=$PUBLIC_IP # Use Public IP for WG_HOST
fi

cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - INSECURE=true
      - WG_HOST=$LOCAL_HOST_IP
      - WG_PORT=$WG_PORT
    image: ghcr.io/wg-easy/wg-easy:15.1
    container_name: wg-easy
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - .:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - "$WG_PORT:$WG_PORT/udp"
      $ui_mapping
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
networks:
  wg:
    ipam:
      config:
        - subnet: 10.42.42.0/24
        - subnet: fdcc:ad94:bacf:61a3::/64
EOF

docker-compose config > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Invalid docker-compose.yml syntax."
  exit 1
fi

systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1

docker-compose up -d > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Failed to start wg-easy container."
  exit 1
fi

if [ -n "$DOMAIN" ]; then
  configure_nginx "$DOMAIN" "$UI_PORT" "$PUBLIC_IP"
fi

echo ""
echo "wg-easy installation complete!"
echo ""
echo "Web UI access:"
echo ""
if [ -n "$DOMAIN" ]; then
  echo "URL: https://$DOMAIN:$UI_PORT"
else
  echo "URL: http://$PUBLIC_IP:$UI_PORT (WARNING: Insecure - no SSL, as no domain was provided)"
fi
echo ""
echo "WireGuard details:"
echo ""
echo "Server Host: $LOCAL_HOST_IP"
echo "Server Port: $WG_PORT/UDP"
echo ""
echo "Notes:"
echo "- Ensure ports $WG_PORT/UDP and $UI_PORT/TCP are open in your server firewall (and cloud provider firewall)."
echo "- The UI will automatically generate client configs using this host and port."
if [ -n "$DOMAIN" ]; then
  echo "- Nginx is set up for reverse proxy and SSL on custom port only; check /etc/nginx/sites-available/wg-easy for config."
fi
echo ""
exit 0
