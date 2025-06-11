#!/bin/bash

set -e

# ----------------------------
# Utility Functions
# ----------------------------
log() {
  echo -e "\n\e[1;36m🔹 $1\e[0m"
}

die() {
  echo -e "\e[1;31m❌ $1\e[0m" >&2
  exit 1
}

prompt_confirm() {
  read -rp "$1 (y/N): " response
  [[ "$response" =~ ^([yY][eE]?[sS]?|[yY])$ ]]
}

# ----------------------------
# Initial Setup
# ----------------------------
clear
echo "========================================"
echo "🔧 XLink Kai Automated Installer"
echo "========================================"
echo "This script will help you install, configure, or remove XLink Kai on your system."
echo "It supports Ubuntu Server and Debian 12 (and similar distros)."
echo

CURRENT_HOSTNAME=$(hostname)
INSTALL_DIR="/etc"
CONFIG_FILE="$INSTALL_DIR/kaiengine.conf"
SERVICE_NAME="xlink-kai"

# ----------------------------
# Collect User Options
# ----------------------------
prompt_confirm "Would you like to uninstall XLink Kai and remove its config?" && UNINSTALL=true || UNINSTALL=false
prompt_confirm "Your current hostname is '$CURRENT_HOSTNAME'. Would you like to change it to 'xlinkkai'?" && CHANGE_HOSTNAME=true || CHANGE_HOSTNAME=false
prompt_confirm "Do you want to install and run XLink Kai as a service?" && INSTALL_SERVICE=true || INSTALL_SERVICE=false
prompt_confirm "Would you like to add helpful login info to your SSH Welcome message?" && ADD_MOTD=true || ADD_MOTD=false

# ----------------------------
# Show Summary and Confirm
# ----------------------------
echo "\nYou selected the following options:"
$UNINSTALL && echo " - Uninstall existing XLink Kai install" || echo " - Do NOT uninstall existing install"
$CHANGE_HOSTNAME && echo " - Change hostname to xlinkkai" || echo " - Keep hostname as '$CURRENT_HOSTNAME'"
$INSTALL_SERVICE && echo " - Install and run XLink Kai as a systemd service" || echo " - Do NOT install XLink Kai service"
$ADD_MOTD && echo " - Update login MOTD with XLink Kai info" || echo " - Do NOT modify SSH MOTD"

echo -e "\n⚠️  This script may:
 - Run apt update/upgrade silently
 - Install new packages
 - Modify /etc/hostname and /etc/hosts
 - Write to /etc/motd or /etc/update-motd.d
 - Create a systemd service"

prompt_confirm "Are you sure you want to proceed with these changes?" || die "User aborted."

# ----------------------------
# Uninstall (if chosen)
# ----------------------------
if $UNINSTALL; then
  log "Uninstalling XLink Kai..."
  sudo systemctl stop "$SERVICE_NAME" || true
  sudo systemctl disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  sudo rm -f "$CONFIG_FILE"
  sudo systemctl daemon-reexec || true
  sudo apt-get remove --purge -y xlinkkai || true
  sudo apt-get autoremove -y
  log "XLink Kai has been uninstalled."
  exit 0
fi

# ----------------------------
# Hostname Change (if chosen)
# ----------------------------
if $CHANGE_HOSTNAME; then
  log "Setting hostname to 'xlinkkai'..."
  sudo hostnamectl set-hostname xlinkkai
  echo "127.0.1.1 xlinkkai" | sudo tee -a /etc/hosts > /dev/null
  CURRENT_HOSTNAME="xlinkkai"
fi

# ----------------------------
# Silent Update & Upgrade
# ----------------------------
log "Updating system silently..."
sudo apt-get update -qq > /dev/null
sudo apt-get upgrade -y -qq > /dev/null
log "System update completed."

# ----------------------------
# Install Requirements
# ----------------------------
log "Installing required packages..."
sudo apt-get install -y -qq ca-certificates curl gnupg > /dev/null

# ----------------------------
# Add Repo
# ----------------------------
log "Configuring Team XLink repository..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/teamxlink.gpg
curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null

sudo apt-get update -qq > /dev/null

# ----------------------------
# Install XLink Kai
# ----------------------------
if ! command -v kaiengine &>/dev/null; then
  log "Installing XLink Kai..."
  sudo apt-get install -y xlinkkai
else
  log "XLink Kai is already installed. Skipping."
fi

# ----------------------------
# Service Setup
# ----------------------------
if $INSTALL_SERVICE; then
  log "Setting up systemd service ($SERVICE_NAME)..."
  sudo bash -c "cat > /etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=XLink Kai Engine
After=network.target
Wants=network.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/usr/bin/kaiengine
Restart=always
GuessMainPID=yes
StartLimitInterval=5min
StartLimitBurst=4
StartLimitAction=reboot-force

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"
fi

# ----------------------------
# Add MOTD (if chosen)
# ----------------------------
if $ADD_MOTD; then
  log "Adding helpful info to login MOTD..."
  sudo bash -c "cat > /etc/update-motd.d/99-xlinkkai" <<EOF
#!/bin/sh
IP=\$(hostname -I | awk '{print \$1}')
echo "\n🔗 XLink Kai Web UI: http://\$IP:34522"
echo "📡 Service status: systemctl status $SERVICE_NAME"
echo "♻️  Restart with: systemctl restart $SERVICE_NAME"
EOF
  sudo chmod +x /etc/update-motd.d/99-xlinkkai
fi

# ----------------------------
# Final Summary
# ----------------------------
IP_ADDRESS=$(hostname -I | awk '{print $1}')
[ -z "$IP_ADDRESS" ] && IP_ADDRESS="192.168.1.10"

echo -e "\n========================================"
echo "✅ Installation Complete"
echo "Visit the Web UI: http://$IP_ADDRESS:34522"
echo "Hostname: $CURRENT_HOSTNAME"
$INSTALL_SERVICE && echo "Service name: $SERVICE_NAME (enabled)"
echo "Use: systemctl status $SERVICE_NAME"
echo "     systemctl restart $SERVICE_NAME"
echo "========================================"
echo "For help: https://github.com/theretrobristolian/xlinkkai"
echo "Discord: https://discord.gg/dZRpsxyp"
echo "Special thanks to user @CrunchBite"
echo "========================================"
