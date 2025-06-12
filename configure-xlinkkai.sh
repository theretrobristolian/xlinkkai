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

# Get the IP address of the VM
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="192.168.1.10" # Example fallback IP
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
echo "You will be prompted for all option questions up front:"
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
    if prompt_confirm "Do you want to run XLink Kai as a systemd service? (Will autostart in the background)"; then
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

if $INSTALL_PACKAGE || $XLINK_INSTALLED; then
  prompt_confirm "Would you like to auto-configure XLink Kai with your credentials?" && AUTO_CONFIGURE=true || AUTO_CONFIGURE=false

  if $AUTO_CONFIGURE; then
    read -rp "Enter your XLink Kai username: " kai_user
    read -rsp "Enter your XLink Kai password: " kai_pass
    echo
  fi
else
  AUTO_CONFIGURE=false
fi

# ----------------------------
# Show Summary & Confirm
# ----------------------------
echo -e "\e[38;5;214mAre you sure you want to proceed with these changes?\e[0m"
if ! prompt_confirm ""; then
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
  step "Updating the system, (This is an Update and Upgrade) (This can take a few minutes)"
  sudo apt-get update -q > /dev/null && sudo apt-get upgrade -y -q > /dev/null
  sudo apt-get install -y ca-certificates curl gnupg -q > /dev/null
  step "Configuring Team XLink repository"
  sudo mkdir -m 0755 -p /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/teamxlink.gpg
  curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
  sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null
  step "Installing XLink Kai package"
  sudo apt-get update -y -q > /dev/null
  sudo apt-get install -y xlinkkai -q > /dev/null || die "Failed to install XLink Kai package. Exiting."
  log "Cleaning up..."
  sudo apt-get autoremove -y -q > /dev/null
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
  sudo systemctl enable $SERVICE_NAME > /dev/null 2>&1
  step "Starting service $SERVICE_NAME"
  sudo systemctl start $SERVICE_NAME > /dev/null 2>&1
  log "Service installed and running."
fi

if $AUTO_CONFIGURE; then
  log "Applying XLink Kai configuration..."
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak" || true

  declare -A config_updates=(
    [kaiUsername]="$kai_user"
    [kaiPassword]="$kai_pass"
    [kaiPort]="30000"
    [kaiAutoLogin]="1"
    [kaiLaunchUI]="1"
    [kaiSkin]="darkmode"
    [kaiPAT]="0"
  )

  for key in "${!config_updates[@]}"; do
    value="${config_updates[$key]}"
    if grep -q "^$key=" "$CONFIG_FILE"; then
      sed -i -E "s|^$key=.*|$key=$value|g" "$CONFIG_FILE"
    else
      echo "$key=$value" >> "$CONFIG_FILE"
    fi
  done

  if systemctl is-active --quiet $SERVICE_NAME; then
    step "Restarting $SERVICE_NAME"
    systemctl restart $SERVICE_NAME
    log "Service restarted successfully."
  fi
fi

if $CHANGE_HOSTNAME; then
  log "Changing hostname..."
  step "Setting hostname to 'xlinkkai'"
  echo "xlinkkai" | sudo tee /etc/hostname > /dev/null
  sudo hostnamectl set-hostname xlinkkai
  log "Hostname changed."
fi

if $ADD_MOTD; then
  log "Updating SSH login MOTD..."
  step "Creating MOTD file"
  MOTD_FILE="/etc/update-motd.d/99-xlinkkai-info"
  sudo tee "$MOTD_FILE" > /dev/null <<EOF
#!/bin/sh
echo "\n========================================="
echo ""
echo "Welcome to XLink Kai Server!"
echo ""
echo "To access the XLink Kai Web UI, go to:"
echo "  http://$IP_ADDRESS:34522"
echo "  http://xlinkkai:34522"
echo ""
echo "Visit https://github.com/theretrobristolian/xlinkkai for more info."
echo ""
echo "\n========================================="
EOF
  sudo chmod +x "$MOTD_FILE"
  log "MOTD updated."
fi

echo -e "\n========================================="
echo "Installation and service setup completed!"
echo ""
echo "To check the status of the XLink Kai service, run:"
echo "  sudo systemctl status xlink-kai"
echo ""
echo "To access the XLink Kai Web UI, go to:"
echo "  http://$IP_ADDRESS:34522"
echo "  http://xlinkkai:34522"
echo -e "=========================================\n"
echo "This script has been provided by TheRetroBristolian 2025."
echo "Further information can be found at:"
echo "  https://github.com/theretrobristolian/xlinkkai"
echo "  https://www.youtube.com/@TheRetroBristolian"
echo ""
echo "This script could not have been possible without special thanks to the XLink Kai team:"
echo "  https://www.teamxlink.co.uk"
echo "  https://discord.gg/dZRpsxyp - Team XLink (Official) Discord Server"
echo ""
log "All done! Enjoy your XLink Kai setup."
exit 0