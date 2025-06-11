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
  read -rp "$1 (Y/N): " response
  [[ "$response" =~ ^([yY][eE]?[sS]?|[yY])$ ]]
}

# ----------------------------
# Clear screen & show header
# ----------------------------
clear
echo -e "\e[1;36m"
echo "  __   __   _ _ _       _        _  _   _   _     "
echo "  \\ \\ / /__| (_) | ___ | | ___  | || | | | | |___ "
echo "   \\ V / -_) | | |/ -_)| |/ _ \\ | __ | | |_| (_-< "
echo "    \\_/\\___|_|_|_|\\___||_|\\___/ |_||_|  \\___//__/ "
echo "                                                  "
echo "           XLink Kai Automated Installer           "
echo -e "\e[0m"

echo -e "\e[90m"
echo "============================================================"
echo "This script helps you install, configure, or remove XLink Kai"
echo "Supported systems: Ubuntu Server, Debian 12, RetroNAS, etc."
echo
echo "Options include:"
echo " - Uninstall existing install"
echo " - Change hostname to 'xlinkkai'"
echo " - Install and run XLink Kai as a systemd service"
echo " - Add helpful MOTD on SSH login"
echo
echo "You will be prompted for all options up front."
echo "A summary will be shown before proceeding."
echo "============================================================"
echo -e "\e[0m"

# ----------------------------
# Variables & Defaults
# ----------------------------
CURRENT_HOSTNAME=$(hostname)
INSTALL_DIR="/etc"
CONFIG_FILE="$INSTALL_DIR/kaiengine.conf"
SERVICE_NAME="xlink-kai"

# ----------------------------
# Collect User Options
# ----------------------------
if prompt_confirm "Would you like to uninstall XLink Kai and remove its config?"; then
  UNINSTALL=true
else
  UNINSTALL=false
fi

if prompt_confirm "Your current hostname is '$CURRENT_HOSTNAME'. Would you like to change it to 'xlinkkai'?"; then
  CHANGE_HOSTNAME=true
else
  CHANGE_HOSTNAME=false
fi

if prompt_confirm "Do you want to install and run XLink Kai as a systemd service?"; then
  INSTALL_SERVICE=true
else
  INSTALL_SERVICE=false
fi

if prompt_confirm "Would you like to add helpful login info to your SSH Welcome message?"; then
  ADD_MOTD=true
else
  ADD_MOTD=false
fi

# ----------------------------
# Show Summary & Confirm
# ----------------------------
echo -e "\n\e[1;33mYou selected the following options:\e[0m"
$UNINSTALL && echo " - Uninstall existing XLink Kai install" || echo " - Do NOT uninstall existing install"
$CHANGE_HOSTNAME && echo " - Change hostname to 'xlinkkai'" || echo " - Keep hostname as '$CURRENT_HOSTNAME'"
$INSTALL_SERVICE && echo " - Install and run XLink Kai as a systemd service" || echo " - Do NOT install service"
$ADD_MOTD && echo " - Add helpful MOTD on SSH login" || echo " - Do NOT modify SSH MOTD"

echo -e "\n\e[1;31m⚠️  Warning: This script will perform system changes including:\e[0m"
echo " - Running apt update/upgrade silently"
echo " - Installing or removing packages"
echo " - Modifying /etc/hostname and /etc/hosts"
echo " - Creating or removing a systemd service"
echo " - Writing to MOTD files for SSH logins"

if ! prompt_confirm "Are you sure you want to proceed with these changes?"; then
  die "User aborted."
fi

# ----------------------------
# Uninstall
# ----------------------------
if $UNINSTALL; then
  log "Uninstalling XLink Kai..."
  sudo systemctl stop "$SERVICE_NAME" || true
  sudo systemctl disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  sudo rm -f "$CONFIG_FILE"
  sudo systemctl daemon-reload || true
  sudo apt-get remove --purge -y xlinkkai || true
  sudo apt-get autoremove -y
  log "XLink Kai has been uninstalled."
  exit 0
fi

# ----------------------------
# Change Hostname
# ----------------------------
if $CHANGE_HOSTNAME; then
  log "Changing hostname to 'xlinkkai'..."
  sudo hostnamectl set-hostname xlinkkai
  # Remove old 127.0.1.1 entries for previous hostname to avoid duplicates
  sudo sed -i "/127.0.1.1\s\+$CURRENT_HOSTNAME/d" /etc/hosts
  echo "127.0.1.1 xlinkkai" | sudo tee -a /etc/hosts > /dev/null
  CURRENT_HOSTNAME="xlinkkai"
fi

# ----------------------------
# Silent system update/upgrade
# ----------------------------
log "Updating system packages silently..."
sudo apt-get update -qq > /dev/null
sudo apt-get upgrade -y -qq > /dev/null
log "System update and upgrade completed."

# ----------------------------
# Install prerequisites
# ----------------------------
log "Installing required packages..."
sudo apt-get install -y -qq ca-certificates curl gnupg > /dev/null

# ----------------------------
# Add Team XLink repository
# ----------------------------
log "Adding Team XLink repository and keys..."
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
  log "XLink Kai already installed. Skipping installation."
fi

# ----------------------------
# Setup systemd service
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
# Add MOTD snippet
# ----------------------------
if $ADD_MOTD; then
  log "Adding helpful info to SSH login MOTD..."
  sudo bash -c "cat > /etc/update-motd.d/99-xlinkkai" <<EOF
#!/bin/sh
IP=\$(hostname -I | awk '{print \$1}')
echo ""
echo "🔗 XLink Kai Web UI: http://\$IP:34522"
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

echo -e "\n\e[1;32m========================================"
echo "✅ Installation Complete"
echo -e "\e[0mVisit the Web UI: \e[1;36mhttp://$IP_ADDRESS:34522\e[0m"
echo -e "\e[0mHostname: \e[1;36m$CURRENT_HOSTNAME\e[0m"
$INSTALL_SERVICE && echo -e "Service name: \e[1;36m$SERVICE_NAME\e[0m (enabled)"
echo -e "Use: \e[1;33msystemctl status $SERVICE_NAME\e[0m"
echo -e "     \e[1;33msystemctl restart $SERVICE_NAME\e[0m"
echo -e "========================================"
echo "For help: https://github.com/theretrobristolian/xlinkkai"
echo "Discord: https://discord.gg/dZRpsxyp"
echo "Special thanks to user @CrunchBite"
echo -e "========================================\e[0m"
