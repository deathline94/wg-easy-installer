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
    REQUIRED_PACKAGES=("curl" "docker.io" "docker-compose" "apache2-utils" "jq")
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v $pkg &> /dev/null; then
            apt-get update > /dev/null 2>&1
            apt-get install -y $pkg > /dev/null 2>&1
        fi
    done
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
                docker network rm wg-easy_default > /dev/null 2>&1
                rm -rf /opt/wg-easy
                echo ""
                echo "wg-easy uninstalled successfully!"
                echo ""
                exit 0
                ;;
            2)
                # Manage Users
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
                            # Update or add expiry in client_expiry.txt
                            escaped_client_name=$(printf '%q' "$client_name")
                            if [ -f "$EXPIRY_FILE" ] && grep -q "^$escaped_client_name," "$EXPIRY_FILE"; then
                                sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
                            fi
                            echo "$escaped_client_name,$expiry_date" >> "$EXPIRY_FILE"
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
                            if [ -k "$client_name" ]; then
                                echo "Invalid client number."
                                continue
                            fi
                            # Remove from expiry file
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
                            # Update expiry in client_expiry.txt
                            escaped_client_name=$(printf '%q' "$client_name")
                            sed -i "/^$escaped_client_name,/d" "$EXPIRY_FILE"
                            echo "$escaped_client_name,$expiry_date" >> "$EXPIRY_FILE"
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
                # Get current settings from docker-compose.yml
                current_ui_port=$(grep -oP '"\K[0-9]+:51821/tcp' docker-compose.yml | cut -d':' -f1)
                current_wg_port=$(grep -oP '"\K[0-9]+:[0-9]+/udp' docker-compose.yml | cut -d':' -f1)
                current_password_hash=$(grep -oP 'PASSWORD_HASH=\K[^ ]+' docker-compose.yml)
                current_ip=$(grep -oP 'WG_HOST=\K[^ ]+' docker-compose.yml)

                # Prompt for new settings
                echo ""
                read -p "Enter new web UI port (or press enter to keep [$current_ui_port]): " new_ui_port
                [ -z "$new_ui_port" ] && new_ui_port=$current_ui_port
                echo ""
                read -p "Enter new WireGuard port (or press enter to keep [$current_wg_port]): " new_wg_port
                [ -z "$new_wg_port" ] && new_wg_port=$current_wg_port
                echo ""
                read -p "Enter new admin password (or press enter to keep current): " new_password
                if [ -n "$new_password" ]; then
                    new_password_hash=$(htpasswd -bnBC 10 "" "$new_password" | tr -d ':\n' | sed 's/\$/$$/g')
                else
                    new_password_hash=$current_password_hash
                fi

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

                # Update docker-compose.yml
                cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - WG_HOST=$new_ip
      - PASSWORD_HASH=$new_password_hash
      - WG_PORT=$new_wg_port
      - WG_DEFAULT_DNS=8.8.8.8
      - WG_DEFAULT_ADDRESS=10.8.0.x
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    volumes:
      - .:/etc/wireguard
    ports:
      - "$new_wg_port:$new_wg_port/udp"
      - "$new_ui_port:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
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

                echo ""
                echo "wg-easy configuration updated successfully!"
                echo ""
                echo "Web UI: http://$new_ip:$new_ui_port"
                echo "Admin password: [As provided or unchanged]"
                echo "WireGuard port: $new_wg_port/UDP"
                echo ""
                echo "Notes:"
                echo "- If you changed the WireGuard port, verify client configs from the UI use the new port (edit Endpoint to $new_ip:$new_wg_port if needed)."
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

# Step 3: Prompt user for input
echo ""
read -p "Enter web UI port (or press enter for 51821): " UI_PORT
[ -z "$UI_PORT" ] && UI_PORT=51821

echo ""
read -p "Enter WireGuard port (or press enter for 51820): " WG_PORT
[ -z "$WG_PORT" ] && WG_PORT=51820

echo ""
read -p "Enter admin password for web UI (or press enter for random): " ADMIN_PASSWORD
[ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)
# Generate bcrypt hash for password and escape $ characters
PASSWORD_HASH=$(htpasswd -bnBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n' | sed 's/\$/$$/g')

# Step 4: Setup wg-easy
mkdir -p /opt/wg-easy
cd /opt/wg-easy
chmod -R 755 /opt/wg-easy

# Create docker-compose.yml
cat << EOF > docker-compose.yml
version: "3.8"
services:
  wg-easy:
    environment:
      - WG_HOST=$PUBLIC_IP
      - PASSWORD_HASH=$PASSWORD_HASH
      - WG_PORT=$WG_PORT
      - WG_DEFAULT_DNS=8.8.8.8
      - WG_DEFAULT_ADDRESS=10.8.0.x
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    volumes:
      - .:/etc/wireguard
    ports:
      - "$WG_PORT:$WG_PORT/udp"
      - "$UI_PORT:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
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

# Step 8: Setup expiry check script
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
echo "URL: http://$PUBLIC_IP:$UI_PORT"
echo "Admin password: $ADMIN_PASSWORD"
echo ""
echo "WireGuard details:"
echo ""
echo "Server: $PUBLIC_IP:$WG_PORT"
echo "Protocol: UDP"
echo ""
echo "To manage users:"
echo "- Use the web UI at http://$PUBLIC_IP:$UI_PORT to add/remove clients."
echo "- Run this script and select 'Manage Users' to set/remove/extend expiry."
echo "- Client expiry is enforced daily via cron."
echo ""
echo "Notes:"
echo "- Ensure ports $WG_PORT/UDP and $UI_PORT/TCP are open in your firewall."
echo "- If using a custom WireGuard port ($WG_PORT), verify client configs from the UI use the correct port (edit Endpoint to $PUBLIC_IP:$WG_PORT if needed)."
echo ""
exit 0
