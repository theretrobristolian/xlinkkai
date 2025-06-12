#!/bin/bash

set -e  # Exit on errors

# ----------------------------
# Utility Functions
# ----------------------------
log() {
  echo -e "\n\e[1;32m🔹 $1\e[0m"  # Green for logs
}

step() {
  echo -e " - $1"
}

die() {
  echo -e "\e[1;31m❌ $1\e[0m" >&2
  exit 1
}

prompt_confirm() {
  while true; do
    read -rp "$1 (Y/N): " response
    case "$response" in
      [yY][eE][sS]|[yY]) return 0 ;;
      [nN][oO]|[nN]) return 1 ;;
      *) echo "Invalid input. Please enter Y or N."; ;;
    esac
  done
}

# ----------------------------
# Privilege & Compatibility Checks
# ----------------------------
if [ "$EUID" -ne 0 ]; then
  die "This script must be run as root. Please use sudo."
fi

if ! grep -iqE 'debian|ubuntu' /etc/os-release; then
  die "This script is only compatible with Debian-based systems."
fi

# ----------------------------
# Clear screen & show header
# ----------------------------
clear
echo -e "\e[37m============================================================"
echo -e "\e[1;32m"  # Green for ASCII art
cat << "EOF"
__  ___     _       _       _  __     _ 
\ \/ / |   (_)_ __ | | __  | |/ /__ _(_)
 \  /| |   | | '_ \| |/ /  | ' // _` | |
 /  \| |___| | | | |   <   | . \ (_| | |
/_/\_\_____|_|_| |_|_|\_\  |_|\_\__,_|_|

EOF
echo -e "\e[37m============================================================"
echo -e "\e[1;37mAutomated installer - provided by The Retro Bristolian"
echo "GitHub: https://github.com/theretrobristolian/xlinkkai"
echo -e "\e[37m============================================================"
echo -e "\e[0m"
echo "This script helps you install, configure, or remove XLink Kai"
echo "Supported systems: Ubuntu Server, Debian 12, RetroNAS, etc."
echo
echo "You will be prompted for all options up front."
echo "A summary will be shown before proceeding."
echo -e "\e[0m"
echo "============================================================"
echo -e "\e[0m"

# ----------------------------
# Variables & Defaults
# ----------------------------
CURRENT_HOSTNAME=$(hostname)
INSTALL_DIR="/etc"
CONFIG_FILE="$INSTALL_DIR/kaiengine.conf"
SERVICE_NAME="xlink-kai"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Detect if XLink Kai is installed
if command -v kaiengine >/dev/null 2>&1; then
  XLINK_INSTALLED=true
else
  XLINK_INSTALLED=false
fi

# Detect if systemd service exists
if [ -f "$SERVICE_FILE" ]; then
  SERVICE_PRESENT=true
else
  SERVICE_PRESENT=false
fi

# ----------------------------
# Collect User Options
# ----------------------------
if $XLINK_INSTALLED; then
  if prompt_confirm "XLink Kai is currently installed. Would you like to uninstall it?"; then
    UNINSTALL=true
  else
    UNINSTALL=false
  fi
else
  UNINSTALL=false
fi

# Only ask about installation if XLink Kai is not already installed
if ! $XLINK_INSTALLED && ! $UNINSTALL; then
  if prompt_confirm "Do you want to install the XLink Kai package?"; then
    INSTALL_PACKAGE=true
  else
    INSTALL_PACKAGE=false
  fi
else
  INSTALL_PACKAGE=false
fi

# Only ask about the service if:
# - XLink is installed
# - The user wants to install XLink
# - Or the service exists independently
if $XLINK_INSTALLED || $INSTALL_PACKAGE || $SERVICE_PRESENT; then
  if $SERVICE_PRESENT; then
    if prompt_confirm "The XLink Kai service is already present. Do you want to uninstall it?"; then
      UNINSTALL_SERVICE=true
    else
      UNINSTALL_SERVICE=false
    fi
  else
    UNINSTALL_SERVICE=false
  fi

  # Only ask to install the service if it's not already present and not being uninstalled
  if ! $SERVICE_PRESENT && ! $UNINSTALL_SERVICE; then
    if prompt_confirm "Do you want to install and run XLink Kai as a systemd service?"; then
      INSTALL_SERVICE=true
    else
      INSTALL_SERVICE=false
    fi
  else
    INSTALL_SERVICE=false
  fi
else
  UNINSTALL_SERVICE=false
  INSTALL_SERVICE=false
fi

if prompt_confirm "Your current hostname is '$CURRENT_HOSTNAME'. Would you like to change it to 'xlinkkai'?"; then
  CHANGE_HOSTNAME=true
else
  CHANGE_HOSTNAME=false
fi

if prompt_confirm "Would you like to add helpful login info to your SSH Welcome message?"; then
  ADD_MOTD=true
else
  ADD_MOTD=false
fi

# ----------------------------
# Show Summary & Confirm
# ----------------------------
echo -e "\n\e[38;5;214mYou selected the following options:\e[0m"  # Orange color
$UNINSTALL && echo " - Uninstall existing XLink Kai install" || echo " - Do NOT uninstall existing install"
$INSTALL_PACKAGE && echo " - Install XLink Kai package" || echo " - Do NOT install package"
$UNINSTALL_SERVICE && echo " - Uninstall XLink Kai systemd service" || echo " - Do NOT uninstall service"
$INSTALL_SERVICE && echo " - Install and run XLink Kai as a systemd service" || echo " - Do NOT install/run service"
$CHANGE_HOSTNAME && echo " - Change hostname to 'xlinkkai'" || echo " - Keep hostname as '$CURRENT_HOSTNAME'"
$ADD_MOTD && echo " - Add helpful MOTD on SSH login" || echo " - Do NOT modify SSH MOTD"

if ! prompt_confirm "Are you sure you want to proceed with these changes?"; then
  die "User aborted."
fi

# ----------------------------
# Actions
# ----------------------------
if $UNINSTALL; then
  log "Uninstalling XLink Kai..."
  step "Stopping and disabling XLink Kai service"
  sudo systemctl stop $SERVICE_NAME || true
  sudo systemctl disable $SERVICE_NAME || true

  step "Removing XLink Kai package"
  sudo apt-get remove --purge -y xlinkkai || true

  step "Removing configuration files"
  sudo rm -f "$CONFIG_FILE"
  log "Uninstallation complete."
fi

if $UNINSTALL_SERVICE; then
  log "Uninstalling XLink Kai service..."
  step "Removing service file"
  sudo systemctl stop $SERVICE_NAME || true
  sudo systemctl disable $SERVICE_NAME || true
  sudo rm -f "$SERVICE_FILE"
  log "Service uninstalled."
fi

if $INSTALL_PACKAGE; then
  log "Installing XLink Kai..."
  step "Updating the system"
  sudo apt-get update -q > /dev/null && sudo apt-get upgrade -y -q > /dev/null
  step "Configuring Team XLink repository..."
  log "Configuring Team XLink repository..."
  sudo mkdir -m 0755 -p /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/teamxlink.gpg
  curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
  sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null
  step "Installing XLink Kai package"
  sudo apt-get install -y xlinkkai || die "Failed to install XLink Kai package. Exiting."
  log "Cleaning up..."
  sudo apt-get autoremove -y
  sudo apt-get clean
fi

if $INSTALL_SERVICE; then
  log "Installing and Configuring XLink Kai as a service..."
  step "Creating systemd service file"
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=XLink Kai Engine
Wants=network.target
After=network.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/usr/bin/kaiengine
Restart=always
StartLimitInterval=5min
StartLimitBurst=4

[Install]
WantedBy=multi-user.target
EOF
  step "Enabling and starting service"
  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME
  sudo systemctl start $SERVICE_NAME
  log "Service installed and running."
fi

if $CHANGE_HOSTNAME; then
  log "Changing hostname..."
  step "Setting hostname to 'xlinkkai'"
  echo "xlinkkai" | sudo tee /etc/hostname
  sudo hostnamectl set-hostname xlinkkai
  log "Hostname changed."
fi

if $ADD_MOTD; then
  log "Updating SSH login MOTD..."
  step "Creating MOTD file"
  MOTD_FILE="/etc/update-motd.d/99-xlinkkai-info"
  sudo tee "$MOTD_FILE" > /dev/null <<EOF
#!/bin/sh
echo ""
echo -e "\n========================================="
echo ""
echo "Welcome to XLink Kai Server!"
echo ""
echo "To access the XLink Kai Web UI, go to:"
echo "  http://$IP_ADDRESS:34522"
echo "  http://xlinkkai:34522"
echo ""
echo "Visit https://github.com/theretrobristolian/xlinkkai for more info."
echo ""
echo -e "\n========================================="
EOF
  sudo chmod +x "$MOTD_FILE"
  log "MOTD updated."
fi

echo -e "\n========================================="
echo "Installation and service setup completed!"
echo "To check the status of the XLink Kai service, run:"
echo "  sudo systemctl status xlink-kai"
echo ""
echo "To access the XLink Kai Web UI, go to:"
echo "  http://$IP_ADDRESS:34522"
echo "  http://xlinkkai:34522"

echo -e "=========================================\n"

log "All done! Enjoy your XLink Kai setup."
exit 0