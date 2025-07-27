<div align="center">
  <h1>🔒 WG-Easy Installer</h1>
  <p><strong>The easiest way to run WireGuard VPN + Web-based Admin UI</strong></p>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Shell Script](https://img.shields.io/badge/Language-Shell-89e051.svg)](https://github.com/deathline94/wg-easy-installer)
  [![GitHub stars](https://img.shields.io/github/stars/deathline94/wg-easy-installer.svg?style=social&label=Star)](https://github.com/deathline94/wg-easy-installer/stargazers)
  
  <p>🚀 <strong>One-line installation</strong> • 🔐 <strong>SSL support</strong> • 👥 <strong>User management</strong> • ⏰ <strong>Client expiry</strong></p>
</div>

---

## 📖 About

WG-Easy Installer is a comprehensive automation script that simplifies the deployment of [wg-easy](https://github.com/wg-easy/wg-easy), a beautiful web interface for WireGuard VPN. This installer handles everything from dependency installation to SSL configuration, making it perfect for both beginners and advanced users.

### ✨ Key Features

- **🚀 One-Command Installation** - Deploy WireGuard VPN in seconds
- **🔐 SSL/TLS Support** - Automatic SSL certificates with Let's Encrypt
- **🌐 Custom Domain Support** - Professional setup with your own domain
- **👥 Advanced User Management** - Built-in client expiry system
- **🔧 Easy Configuration** - Modify settings without reinstalling
- **🛡️ Security First** - No port conflicts, proper firewall handling
- **📱 Responsive Web UI** - Modern interface for all devices
- **🔄 Auto-Updates** - Daily client expiry enforcement via cron
- **📦 Zero Dependencies** - Installs everything automatically

---

## 🚀 Quick Start

### One-Line Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/deathline94/wg-easy-installer/master/wg-easy-install.sh)
```

That's it! The script will guide you through the setup process.

### What Happens During Installation?

1. **Dependency Check** - Installs required packages (Docker, Nginx, Certbot, etc.)
2. **Configuration** - Prompts for domain, ports, and other settings
3. **SSL Setup** - Automatically configures SSL certificates if domain provided
4. **WireGuard Deployment** - Sets up containerized WireGuard with Docker Compose
5. **User Management** - Configures client expiry system with cron jobs

---

## 🛠️ Configuration Options

### Basic Setup (HTTP)
- **Domain**: Leave blank for IP-based access
- **Web UI Port**: Default `51821` (customizable)
- **WireGuard Port**: Default `51820` (customizable)
- **Access**: `http://YOUR_IP:UI_PORT`

### Professional Setup (HTTPS)
- **Domain**: Your domain (e.g., `vpn.example.com`)
- **SSL**: Automatic Let's Encrypt certificates
- **Access**: `https://vpn.example.com:UI_PORT`

---

## 📋 Management Interface

Once installed, run the script again to access the management menu:

### Main Menu Options

| Option | Description |
|--------|-------------|
| **Uninstall** | Complete removal of WG-Easy and all configurations |
| **Manage Users** | Access user management system |
| **Modify** | Update configuration without reinstalling |
| **Exit** | Close the management interface |

### User Management Features

| Feature | Description |
|---------|-------------|
| **List Clients** | View all clients with expiry status |
| **Set Expiry** | Assign 30-day expiry to clients |
| **Remove Expiry** | Clear client expiry dates |
| **Extend Expiry** | Add another 30 days to existing clients |

---

## 🔧 Advanced Features

### Automatic Client Expiry
- **Daily Checks**: Automated cron job removes expired clients
- **Flexible Management**: Set, remove, or extend expiry dates
- **Zero Downtime**: Automatic service restart after changes

### SSL Configuration
- **Let's Encrypt Integration**: Free SSL certificates
- **Auto-Renewal**: Certificates renew automatically
- **Custom Ports**: No conflicts with existing services
- **Nginx Reverse Proxy**: Professional-grade setup

### Docker Integration
- **Containerized**: Isolated and secure deployment
- **IPv6 Support**: Full dual-stack networking
- **Resource Management**: Optimized container configuration
- **Easy Updates**: Simple container version management

---

## 🌐 Accessing Your VPN

### Web Interface
After installation, access your VPN management interface:

- **With Domain**: `https://yourdomain.com:UI_PORT`
- **Without Domain**: `http://YOUR_IP:UI_PORT`

### Adding Clients
1. Open the web interface
2. Click "Add Client"
3. Download the configuration file
4. Import into your WireGuard client

### Supported Clients
- **Mobile**: iOS, Android
- **Desktop**: Windows, macOS, Linux
- **Router**: pfSense, OPNsense, OpenWrt

---

## 🔒 Security Considerations

### Firewall Requirements
Ensure these ports are open:
```bash
# WireGuard traffic
sudo ufw allow [WG_PORT]/udp

# Web interface
sudo ufw allow [UI_PORT]/tcp
```

### Best Practices
- Use strong, unique passwords for the admin interface
- Regularly review and remove unused clients
- Enable client expiry for temporary access
- Monitor logs for suspicious activity
- Keep the system updated

---

## 📊 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 18.04+ / Debian 9+ / CentOS 7+
- **RAM**: 512MB
- **Storage**: 1GB free space
- **Network**: Public IP address

### Recommended Setup
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 1GB+
- **CPU**: 1 vCPU
- **Storage**: 5GB+ SSD

---

## 🛠️ Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Check what's using the port
sudo netstat -tlnp | grep :51821

# Kill the process if needed
sudo kill -9 [PID]
```

#### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew
```

#### Docker Issues
```bash
# Restart Docker service
sudo systemctl restart docker

# Check container logs
docker logs wg-easy
```

### Log Locations
- **WG-Easy Logs**: `docker logs wg-easy`
- **Nginx Logs**: `/var/log/nginx/error.log`
- **Certbot Logs**: `/var/log/letsencrypt/letsencrypt.log`

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup
```bash
git clone https://github.com/deathline94/wg-easy-installer.git
cd wg-easy-installer
# Make your changes and test
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **[WG-Easy Project](https://github.com/wg-easy/wg-easy)** - The amazing WireGuard web interface this installer is built around
- **[WireGuard](https://www.wireguard.com/)** - The revolutionary VPN technology
- **Community Contributors** - Thank you for your feedback and contributions!

---

## ⭐ Support the Project

If you find this project useful, please consider:

- ⭐ **Starring** the repository
- 🐛 **Reporting** bugs and issues
- 💡 **Suggesting** new features
- 🤝 **Contributing** code improvements

---

<div align="center">
  <p><strong>Made with ❤️ by <a href="https://github.com/deathline94">@deathline94</a></strong></p>
  <p>🔒 <em>Secure • Simple • Professional</em></p>
</div>
