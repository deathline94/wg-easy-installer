# wg-easy Installer Script

A simple and automated installer script for setting up **[wg-easy](https://github.com/wg-easy/wg-easy)**, a user-friendly WireGuard VPN solution. This script simplifies the installation, configuration, and management of wg-easy on your Linux server, with features like client expiry management and custom port support.

## Installation

To install wg-easy using the we-easy-installer, run the following command as root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/we-easy-installer/blob/master/wg-easy-install.sh)
```

This will:
- Check for required dependencies (`curl`, `docker.io`, `docker-compose`, `apache2-utils`, `jq`) and install them if missing.
- Prompt for web UI port (default: `51821`), WireGuard port (default: `51820`), and admin password (random if not specified).
- Set up wg-easy in `/opt/wg-easy` with Docker Compose.
- Configure a daily cron job for client expiry checks.

## Features

- **Easy Installation**: Automatically installs and configures wg-easy with a single command, including all dependencies.
- **Uninstallation**: Removes wg-easy, Docker container, network, and configuration files with one menu option.
- **Modify Configuration**: Update web UI port, WireGuard port, admin password, and public IP without reinstalling.
- **User Management**:
  - **List Clients**: Displays all clients from `wg0.json` with their expiry dates (if set).
  - **Set Expiry**: Assigns an expiry date (YYYY-MM-DD) to a client, stored in `client_expiry.txt`.
  - **Remove Expiry**: Clears expiry for a client.
- **Custom WireGuard Port**: Supports any WireGuard port (not just `51820`), with proper Docker port mapping.
- **Client Expiry Enforcement**: Daily cron job checks `client_expiry.txt` and removes expired clients from `wg0.json`, restarting the service.
- **Minimal Dependencies**: Uses only essential tools, with no unnecessary logging or bloat.
- **Hysteria-Inspired Style**: Clean, animated CLI interface with `print_with_delay` for a polished experience.

## Usage

1. **Run the Script**:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/we-easy-installer/blob/master/wg-easy-install.sh)
   ```

2. **Follow Prompts** (for new installs):
   - Enter web UI port (default: `51821`).
   - Enter WireGuard port (default: `51820`).
   - Enter admin password (or leave blank for a random one).

3. **Main Menu** (if already installed):
   - **Uninstall**: Removes wg-easy and all files.
   - **Manage Users**: Access the user management menu.
   - **Modify**: Update ports, password, or IP.
   - **Exit**: Close the script.

4. **User Management Menu**:
   - **List Clients**: View all clients and their expiry status.
   - **Set Expiry**: Assign an expiry date to a client.
   - **Remove Expiry**: Clear a client’s expiry.
   - **Back**: Return to the main menu.

5. **Access Web UI**:
   - URL: `http://<PUBLIC_IP>:<UI_PORT>`
   - Use the admin password provided during installation.
   - Add/remove clients via the UI and download their configs.

6. **Notes**:
   - Ensure `<WG_PORT>/UDP` and `<UI_PORT>/TCP` are open in your firewall.
   - If using a custom WireGuard port, verify client configs from the UI use the correct port (edit `Endpoint` to `<PUBLIC_IP>:<WG_PORT>` if needed).

## Credits

- **Original wg-easy Project**: This installer is built around the awesome **[wg-easy](https://github.com/wg-easy/wg-easy)** project, which provides the core WireGuard VPN functionality. Huge thanks to the wg-easy team for their work!
- **Developed by**: **[@deathline94](https://github.com/deathline94)**


---

Enjoy a seamless WireGuard VPN setup with **we-easy-installer**! If you find this project useful, please give it a **⭐** on GitHub.
