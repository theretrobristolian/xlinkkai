#!/bin/bash

set -e

# Globals
DEFAULT_CONFIG_FILE="/etc/kaiengine.conf"
SERVICE_NAME="xlink-kai"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_FLAG="/usr/bin/kaiengine"
FINAL_HOSTNAME="$(hostname)"
IP_ADDRESS="$(hostname -I | awk '{print $1}' || echo "192.168.1.10")"

# Functions

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use 'sudo'."
    exit 1
  fi
}

install_sudo_if_missing() {
  if ! command -v sudo &>/dev/null; then
    echo "Installing 'sudo'..."
    apt-get update -y && apt-get install -y sudo
  fi
}

ask_hostname_change() {
  CURRENT_HOSTNAME=$(hostname)
  read -rp "Your current hostname is '$CURRENT_HOSTNAME'. Change it to 'xlinkkai'? (y/N): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    hostnamectl set-hostname xlinkkai
    sed -i "/127.0.1.1/d" /etc/hosts
    echo "127.0.1.1 xlinkkai" >> /etc/hosts
    FINAL_HOSTNAME="xlinkkai"
    echo "Hostname changed to xlinkkai."
  else
    FINAL_HOSTNAME="$CURRENT_HOSTNAME"
    echo "Keeping existing hostname: $FINAL_HOSTNAME"
  fi
}

install_prerequisites() {
  echo "Installing prerequisites..."
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get install -y ca-certificates curl gnupg
}

configure_repository() {
  echo "Adding Team XLink repo..."
  sudo mkdir -m 0755 -p /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/teamxlink.gpg
  curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
  sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null
}

install_xlinkkai() {
  if [ -f "$INSTALL_FLAG" ]; then
    echo "XLink Kai is already installed. Skipping install."
  else
    configure_repository
    echo "Installing XLink Kai..."
    sudo apt-get update
    sudo apt-get install -y xlinkkai
  fi
}

setup_service() {
  echo "Creating and enabling the ${SERVICE_NAME} service..."
  cat > "$SERVICE_FILE" <<EOF
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
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"
}

add_info_to_motd() {
  echo "Appending key info to /etc/motd..."
  cat >> /etc/motd <<EOF

-----------------------------------------
🚀 XLink Kai Info
📡 Web UI: http://$IP_ADDRESS:34522
🛠 Service: systemctl status $SERVICE_NAME
▶️ Start:    sudo systemctl start $SERVICE_NAME
⏹ Stop:     sudo systemctl stop $SERVICE_NAME
🔄 Restart:  sudo systemctl restart $SERVICE_NAME
-----------------------------------------
EOF
}

clean_uninstall() {
  echo "Stopping and removing XLink Kai and configuration..."
  sudo systemctl stop "$SERVICE_NAME" || true
  sudo systemctl disable "$SERVICE_NAME" || true
  sudo rm -f "$SERVICE_FILE"
  sudo systemctl daemon-reload
  sudo apt-get remove --purge -y xlinkkai || true
  sudo rm -f "$DEFAULT_CONFIG_FILE"
  sudo apt-get autoremove -y
  sudo apt-get clean
  echo "✅ XLink Kai has been fully removed."
  exit 0
}

print_summary() {
  echo -e "\n========================================="
  echo "✅ Installation and setup completed!"
  echo "Service: $(systemctl is-active $SERVICE_NAME || echo 'not installed')"
  echo ""
  echo "🌐 Access the XLink Kai Web UI at:"
  echo "  http://$IP_ADDRESS:34522"
  echo "  OR, if DNS is configured:"
  echo "  http://$FINAL_HOSTNAME:34522"
  echo "========================================="
  echo ""

  read -rp "Would you like to add this info to your SSH welcome message (/etc/motd)? (y/N): " motd
  if [[ "$motd" =~ ^[Yy]$ ]]; then
    add_info_to_motd
    echo "Info added to /etc/motd."
  fi

  echo ""
  echo "Provided by TheRetroBristolian 2025"
  echo "  https://github.com/theretrobristolian/xlinkkai"
  echo "  https://www.youtube.com/@TheRetroBristolian"
  echo "  https://discord.gg/dZRpsxyp"
  echo "Special thanks to @CrunchBite and the Team XLink community!"
}

# Main Flow

check_root
install_sudo_if_missing

read -rp "Do you want to uninstall and remove XLink Kai? (y/N): " uninstall
if [[ "$uninstall" =~ ^[Yy]$ ]]; then
  clean_uninstall
fi

ask_hostname_change
install_prerequisites
install_xlinkkai

read -rp "Do you want to install and run XLink Kai as a service? (y/N): " service
if [[ "$service" =~ ^[Yy]$ ]]; then
  setup_service
else
  echo "Skipping service setup."
fi

print_summary
