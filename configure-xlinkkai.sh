#!/bin/bash

set -e

# ----------------------------
# Utility Functions
# ----------------------------
log() {
  echo -e "\n\e[1;32m🔹 $1\e[0m"  # Green for logs
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
echo -e "\e[1;32m"  # Green for ASCII art
cat << "EOF"
__  ___     _       _      _  __     _ 
\ \/ / |   (_)_ __ | | __ | |/ /__ _(_)
 \  /| |   | | '_ \| |/ / | ' // _` | |
 /  \| |___| | | | |   <  | . \ (_| | |
/_/\_\_____|_|_| |_|_|\_\ |_|\_\__,_|_|
EOF
echo -e "\e[1;37mAutomated installer - provided by The Retro Bristolian"
echo "GitHub: https://github.com/theretrobristolian/xlinkkai"
echo -e "\e[0m"

echo -e "\e[37m============================================================"
echo "This script helps you install, configure, or remove XLink Kai"
echo "Supported systems: Ubuntu Server, Debian 12, RetroNAS, etc."
echo
echo "Options include:"
echo " - Change hostname to 'xlinkkai'"
echo " - Install XLink Kai package"
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

# Detect if XLink Kai is installed
if command -v kaiengine >/dev/null 2>&1; then
  XLINK_INSTALLED=true
else
  XLINK_INSTALLED=false
fi

# ----------------------------
# Collect User Options
# ----------------------------

# Prompt uninstall only if installed
if $XLINK_INSTALLED; then
  if prompt_confirm "XLink Kai is currently installed. Would you like to uninstall it?"; then
    UNINSTALL=true
  else
    UNINSTALL=false
  fi
else
  UNINSTALL=false
fi

if prompt_confirm "Your current hostname is '$CURRENT_HOSTNAME'. Would you like to change it to 'xlinkkai'?"; then
  CHANGE_HOSTNAME=true
else
  CHANGE_HOSTNAME=false
fi

if prompt_confirm "Do you want to install the XLink Kai package?"; then
  INSTALL_PACKAGE=true
else
  INSTALL_PACKAGE=false
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

echo -e "\n\e[38;5;214mYou selected the following options:\e[0m"  # Orange color
$UNINSTALL && echo " - Uninstall existing XLink Kai install" || echo " - Do NOT uninstall existing install"
$CHANGE_HOSTNAME && echo " - Change hostname to 'xlinkkai'" || echo " - Keep hostname as '$CURRENT_HOSTNAME'"
$INSTALL_PACKAGE && echo " - Install XLink Kai package" || echo " - Do NOT install package"
$INSTALL_SERVICE && echo " - Install and run XLink Kai as a systemd service" || echo " - Do NOT install/run service"
$ADD_MOTD && echo " - Add helpful MOTD on SSH login" || echo " - Do NOT modify SSH MOTD"

echo -e "\n\e[1;31m⚠️  Warning: The script will make the following changes:\e[0m"

if $UNINSTALL; then
  echo " - Uninstall XLink Kai and remove configuration files"
else
  if $CHANGE_HOSTNAME; then
    echo " - Change system hostname to 'xlinkkai'"
  fi
  if $INSTALL_PACKAGE; then
    echo " - Install or update XLink Kai package"
  fi
  if $INSTALL_SERVICE; then
    echo " - Set up systemd service for XLink Kai"
  fi
  if $ADD_MOTD; then
    echo " - Add or update MOTD login message with XLink Kai info"
  fi
fi

if ! $UNINSTALL && ! $CHANGE_HOSTNAME && ! $INSTALL_PACKAGE && ! $INSTALL_SERVICE && ! $ADD_MOTD; then
  echo " - No changes will be made."
fi

if ! prompt_confirm "Are you sure you want to proceed with these changes?"; then
  die "User aborted."
fi

# ----------------------------
# Actions
# ----------------------------

if $UNINSTALL; then
  log "Stopping and disabling XLink Kai service..."
  sudo systemctl stop $SERVICE_NAME || true
  sudo systemctl disable $SERVICE_NAME || true

  log "Removing XLink Kai package..."
  sudo apt-get remove --purge -y xlinkkai || true

  log "Removing configuration files..."
  sudo rm -f $CONFIG_FILE
  sudo rm -f /etc/systemd/system/$SERVICE_NAME.service

  log "Uninstallation complete."
  exit 0
fi

if $CHANGE_HOSTNAME; then
  log "Changing hostname to 'xlinkkai'..."
  echo "xlinkkai" | sudo tee /etc/hostname
  sudo hostnamectl set-hostname xlinkkai
  log "Hostname changed."
fi

if $INSTALL_PACKAGE; then
  log "Installing XLink Kai package..."
  sudo apt-get update
  sudo apt-get install -y xlinkkai
fi

if $INSTALL_SERVICE; then
  log "Setting up systemd service for XLink Kai..."

  SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
  sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=XLink Kai Engine
Wants=network.target
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/usr/bin/kaiengine
Restart=always
GuessMainPID=yes
StartLimitInterval=5min
StartLimitBurst=4
StartLimitAction=reboot-force
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME
  sudo systemctl restart $SERVICE_NAME

  log "XLink Kai service installed and started."
fi

if $ADD_MOTD; then
  log "Updating SSH login MOTD..."
  MOTD_FILE="/etc/update-motd.d/99-xlinkkai-info"
  sudo tee $MOTD_FILE > /dev/null <<EOF
#!/bin/sh
echo ""
echo "Welcome to XLink Kai Server!"
echo "Visit https://github.com/theretrobristolian/xlinkkai for more info."
echo ""
EOF
  sudo chmod +x $MOTD_FILE
  log "MOTD updated."
fi

log "All done! Enjoy your XLink Kai setup."

exit 0
