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

  # Stop if domain is empty (should not happen since we check before calling)
  if [ -z "$domain" ]; then
    return
  fi

  # Stop Nginx temporarily for standalone Certbot (avoids port conflicts)
  systemctl stop nginx > /dev/null 2>&1

  # Obtain/renew SSL cert with Certbot standalone mode (no email required)
  certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$domain" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Failed to obtain SSL certificate. Check domain DNS and ensure no conflicts during validation."
    exit 1
  fi

  # Create Nginx config (listen only on custom UI port for HTTPS, proxy to fixed internal port)
  cat << EOF > /etc/nginx/sites-available/wg-easy
server {
    listen $ui_port ssl;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://localhost:51822;  # Fixed internal port for wg-easy
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

  # Enable the site
  ln -sf /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/
  nginx -t > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed."
    exit 1
  fi

  # Restart Nginx
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
    echo "2) Manage Users"
    echo ""
    echo "3) Modify"
    echo ""
    echo "4) Exit"
    echo ""
    read -p "Enter your choice: " choice
    case $choice in
      1)
        # Uninstall
        cd /opt/wg-easy
        docker-compose down > /dev/null 2>&1
        docker rm wg-easy > /dev/null 2>&1
        docker network rm wg > /dev/null 2>&1
        rm -rf /opt/wg-easy
        # Remove Nginx config if exists
        rm -f /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/wg-easy
        systemctl restart nginx > /dev/null 2>&1
        echo ""
        echo "wg-easy uninstalled successfully!"
        echo ""
        exit 0
        ;;
      2)
        # Manage Users (unchanged from your original)
        cd /opt/wg-easy
        WG_JSON="/opt/wg-easy/wg0.json"
        EXPIRY_FILE="/opt/wg-easy/client_expiry.txt"
        while true; do
          echo ""
          echo "User Management Menu:"
          echo ""
          echo "1) List Clients"
          echo ""
          echo "2) Set Expiry"
          echo ""
          echo "3) Remove Expiry"
          echo ""
          echo "4) Extend Expiry"
          echo ""
          echo "5) Back"
          echo ""
          read -p "Enter your choice: " user_choice
          case $user_choice in
            1)
              # List Clients
              echo ""
              echo "Clients:"
              echo ""
              if [ ! -s "$WG_JSON" ] || [ "$(jq '.clients | length' "$WG_JSON")" -eq 0 ]; then
                echo "No clients found."
              else
                i=1
                jq -r '.clients | to_entries | .[] | .value.name' "$WG_JSON" | while IFS= read -r client_name; do
                  if [ -n "$client_name" ]; then
                    escaped_client_name=$(printf '%q' "$client_name")
                    expiry=""
                    if [ -f "$EXPIRY_FILE" ]; then
                      expiry=$(grep "^$escaped_client_name," "$EXPIRY_FILE" | cut -d',' -f2)
                    fi
                    if [ -n "$expiry" ]; then
                      echo "$i) $client_name (Expires: $expiry)"
                    else
                      echo "$i) $client_name (No expiry)"
                    fi
                    ((i++))
                  fi
                done
              fi
              echo ""
              ;;
            2)
              # Set Expiry
              echo ""
              echo "Available clients:"
              if [ ! -s "$WG_JSON" ] || [ "$(jq '.clients | length' "$WG_JSON")" -eq 0 ]; then
                echo "No clients found."
                continue
              fi
              jq -r '.clients | to_entries | .[] | "\(.value.name)"' "$WG_JSON" | cat -n
              echo ""
              read -p "Enter client number to set expiry (or 0 to cancel): " client_num
              if [ "$client_num" -eq 0 ]; then
                continue
              fi
              client_name=$(jq -r '.clients | to_entries | .['$((client_num-1))'].value.name' "$WG_JSON")
              if [ -z "$client_name" ]; then
                echo "Invalid client number."
                continue
              fi
              expiry_date=$(date -d "+30 days" +%Y-%m-%d)
              escaped_client_name=$(printf '%q' "$client_name")
              if [ -f "$EXPIRY_FILE" ] && grep -q "^$escaped_client_name," "$EXPIRY_FILE"; then
                sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
              fi
              echo "$client_name,$expiry_date" >> "$EXPIRY_FILE"
              echo "Expiry set for $client_name to $expiry_date (30 days from now)!"
              ;;
            3)
              # Remove Expiry
              echo ""
              echo "Available clients with expiry:"
              if [ ! -f "$EXPIRY_FILE" ] || [ ! -s "$EXPIRY_FILE" ]; then
                echo "No clients with expiry found."
                continue
              fi
              grep -v '^$' "$EXPIRY_FILE" | cut -d',' -f1 | cat -n
              echo ""
              read -p "Enter client number to remove expiry (or 0 to cancel): " client_num
              if [ "$client_num" -eq 0 ]; then
                continue
              fi
              client_name=$(grep -v '^$' "$EXPIRY_FILE" | cut -d',' -f1 | sed -n "${client_num}p")
              if [ -z "$client_name" ]; then
                echo "Invalid client number."
                continue
              fi
              escaped_client_name=$(printf '%q' "$client_name")
              sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
              echo "Expiry removed for $client_name!"
              ;;
            4)
              # Extend Expiry
              echo ""
              echo "Available clients with expiry:"
              if [ ! -f "$EXPIRY_FILE" ] || [ ! -s "$EXPIRY_FILE" ]; then
                echo "No clients with expiry found."
                continue
              fi
              grep -v '^$' "$EXPIRY_FILE" | cut -d',' -f1 | cat -n
              echo ""
              read -p "Enter client number to extend expiry (or 0 to cancel): " client_num
              if [ "$client_num" -eq 0 ]; then
                continue
              fi
              client_name=$(grep -v '^$' "$EXPIRY_FILE" | cut -d',' -f1 | sed -n "${client_num}p")
              if [ -z "$client_name" ]; then
                echo "Invalid client number."
                continue
              fi
              expiry_date=$(date -d "+30 days" +%Y-%m-%d)
              escaped_client_name=$(printf '%q' "$client_name")
              sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
              client_name=$(echo "$client_name" | sed 's/\\//g')
              echo "$client_name,$expiry_date" >> "$EXPIRY_FILE"
              echo "Expiry extended for $client_name to $expiry_date (30 days from now)!"
              ;;
            5)
              # Back
              break
              ;;
            *)
              echo "Invalid choice."
              ;;
          esac
        done
        ;;
      3)
        # Modify
        cd /opt/wg-easy
        current_ui_port=$(grep -oP '"\K[0-9]+:51821/tcp' docker-compose.yml | cut -d':' -f1)
        current_wg_port=$(grep -oP '"\K[0-9]+:51820/udp' docker-compose.yml | cut -d':' -f1)
        current_domain=$(grep -oP 'server_name \K[^;]+' /etc/nginx/sites-available/wg-easy 2>/dev/null || echo "")
        echo ""
        read -p "Enter new domain (or press enter to keep [$current_domain], leave blank for no domain/insecure HTTP): " new_domain
        [ -z "$new_domain" ] && new_domain=$current_domain
        echo ""
        read -p "Enter new web UI port (or press enter to keep [$current_ui_port]): " new_ui_port
        [ -z "$new_ui_port" ] && new_ui_port=$current_ui_port
        echo ""
        read -p "Enter new WireGuard port (or press enter to keep [$current_wg_port]): " new_wg_port
        [ -z "$new_wg_port" ] && new_wg_port=$current_wg_port
        echo ""
        # Auto-fetch new IP
        new_ip=$(curl -s https://api.ipify.org)
        if [ -z "$new_ip" ]; then
          echo "Failed to detect public IP."
          exit 1
        fi
        if ! [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Invalid IP format."
          exit 1
        fi
        # Determine Docker UI port mapping based on domain (secure vs insecure)
        if [ -n "$new_domain" ]; then
          ui_mapping="- \"127.0.0.1:51822:51821/tcp\""  # Internal for SSL/Nginx
        else
          ui_mapping="- \"$new_ui_port:51821/tcp\""  # Public for insecure HTTP
          # Remove any existing Nginx config if switching to no domain
          rm -f /etc/nginx/sites-available/wg-easy /etc/nginx/sites-enabled/wg-easy
          systemctl restart nginx > /dev/null 2>&1
        fi
        # Update docker-compose.yml
        cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - INSECURE=true
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
      - "$new_wg_port:51820/udp"
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
        # Validate docker-compose.yml
        docker-compose config > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo "Invalid docker-compose.yml syntax."
          exit 1
        fi
        # Restart service
        docker-compose down > /dev/null 2>&1
        docker-compose up -d > /dev/null 2>&1
        # Reconfigure Nginx only if domain is provided
        if [ -n "$new_domain" ]; then
          configure_nginx "$new_domain" "$new_ui_port" "$new_ip"
        fi
        echo ""
        echo "wg-easy configuration updated successfully!"
        echo ""
        if [ -n "$new_domain" ]; then
          echo "Web UI: https://$new_domain:$new_ui_port"
        else
          echo "Web UI: http://$new_ip:$new_ui_port (insecure - no SSL)"
        fi
        echo "WireGuard port: $new_wg_port/UDP"
        echo ""
        echo "Notes:"
        echo "- If you changed the WireGuard port, verify client configs from the UI use the new port (edit Endpoint to $new_ip:$new_wg_port if needed)."
        echo "- Access is via custom port only (no port 80/443 usage)."
        echo ""
        exit 0
        ;;
      4)
        # Exit
        exit 0
        ;;
      *)
        echo "Invalid choice."
        ;;
    esac
  done
fi

# Install required packages if not already installed
install_required_packages

# Step 1: Check OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"
if [ "$OS" != "Linux" ]; then
  echo "Unsupported OS"
  exit 1
fi
case "$ARCH" in
  x86_64|amd64|arm64) ;; # Supported architectures
  *) echo "Unsupported architecture"; exit 1;;
esac

# Step 2: Auto-fetch public IP
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
  echo "Failed to detect public IP."
  exit 1
fi
if ! [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid IP format."
  exit 1
fi

# Step 3: Prompt user for input (no email prompt, domain is optional)
echo ""
read -p "Enter domain for SSL (e.g., wg.example.com, or press enter for insecure HTTP on IP): " DOMAIN
echo ""
read -p "Enter web UI port (or press enter for 51821): " UI_PORT
[ -z "$UI_PORT" ] && UI_PORT=51821
echo ""
read -p "Enter WireGuard port (or press enter for 51820): " WG_PORT
[ -z "$WG_PORT" ] && WG_PORT=51820

# Step 4: Setup wg-easy
mkdir -p /opt/wg-easy
cd /opt/wg-easy
chmod -R 755 /opt/wg-easy

# Determine Docker UI port mapping based on domain (secure vs insecure)
if [ -n "$DOMAIN" ]; then
  ui_mapping="- \"127.0.0.1:51822:51821/tcp\""  # Internal for SSL/Nginx
else
  ui_mapping="- \"$UI_PORT:51821/tcp\""  # Public for insecure HTTP
fi

# Create docker-compose.yml
cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - INSECURE=true
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
      - "$WG_PORT:51820/udp"
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

# Step 5: Validate docker-compose.yml
docker-compose config > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Invalid docker-compose.yml syntax."
  exit 1
fi

# Step 6: Enable and start Docker
systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1

# Step 7: Run wg-easy
docker-compose up -d > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Failed to start wg-easy container."
  exit 1
fi

# Step 7.5: Configure Nginx reverse proxy and SSL only if domain provided
if [ -n "$DOMAIN" ]; then
  configure_nginx "$DOMAIN" "$UI_PORT" "$PUBLIC_IP"
fi

# Step 8: Setup expiry check script (unchanged from your original)
cat << 'EOF' > /opt/wg-easy/check-expiry.sh
#!/bin/bash
WG_JSON="/opt/wg-easy/wg0.json"
EXPIRY_FILE="/opt/wg-easy/client_expiry.txt"
CURRENT_DATE=$(date +%Y-%m-%d)
if [ -f "$EXPIRY_FILE" ]; then
  while IFS=, read -r client_name expiry_date; do
    if [ -n "$client_name" ] && [ -n "$expiry_date" ]; then
      if [[ "$CURRENT_DATE" > "$expiry_date" || "$CURRENT_DATE" == "$expiry_date" ]]; then
        escaped_client_name=$(printf '%q' "$client_name")
        client_id=$(jq -r ".clients | to_entries | .[] | select(.value.name == \"$client_name\") | .key" "$WG_JSON")
        if [ -n "$client_id" ]; then
          jq "del(.clients.\"$client_id\")" "$WG_JSON" > tmp.json && mv tmp.json "$WG_JSON"
          sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
          docker-compose -f /opt/wg-easy/docker-compose.yml restart > /dev/null 2>&1
        fi
      fi
    fi
  done < "$EXPIRY_FILE"
fi
EOF
chmod 755 /opt/wg-easy/check-expiry.sh

# Setup cron job for daily expiry check
echo "0 0 * * * /bin/bash /opt/wg-easy/check-expiry.sh" | sudo tee /etc/cron.d/wg-easy-expiry >/dev/null
chmod 644 /etc/cron.d/wg-easy-expiry

# Step 9: Generate and print instructions
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
echo "Server: $PUBLIC_IP:$WG_PORT"
echo "Protocol: UDP"
echo ""
echo "To manage users:"
echo "- Use the web UI to add/remove clients."
echo "- Run this script and select 'Manage Users' to set/remove/extend expiry."
echo "- Client expiry is enforced daily via cron."
echo ""
echo "Notes:"
echo "- Ensure ports $WG_PORT/UDP and $UI_PORT/TCP are open in your firewall."
echo "- If using a custom WireGuard port ($WG_PORT), verify client configs from the UI use the correct port (edit Endpoint to $PUBLIC_IP:$WG_PORT if needed)."
if [ -n "$DOMAIN" ]; then
  echo "- Nginx is set up for reverse proxy and SSL on custom port only; check /etc/nginx/sites-available/wg-easy for config."
fi
echo "- No conflicts with services on port 80 (e.g., Xray)."
echo ""
exit 0
