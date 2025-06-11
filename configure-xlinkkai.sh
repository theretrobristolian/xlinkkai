#!/bin/bash

set -e

INSTALL_FLAG="/usr/bin/kaiengine"
SERVICE_NAME="xlink-kai"
KAI_CONFIG="/etc/kaiengine.conf"
MOTD_FILE="/etc/motd"

# Ensure script is run as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Please run this script as root or using sudo."
    exit 1
  fi
}

# Install sudo if it's not present
install_sudo_if_missing() {
  if ! command -v sudo &> /dev/null; then
    echo "⚙️  Installing sudo..."
    apt-get update && apt-get install -y sudo
  fi
}

ask_hostname_change() {
  current_hostname=$(hostname)
  echo "Your current hostname is: $current_hostname"
  read -rp "Would you like to change it to 'xlinkkai'? (y/N): " change_hostname
  if [[ "$change_hostname" =~ ^[Yy]$ ]]; then
    echo "Changing hostname to 'xlinkkai'..."
    hostnamectl set-hostname xlinkkai
    echo "127.0.1.1 xlinkkai" | tee -a /etc/hosts > /dev/null
    final_hostname="xlinkkai"
  else
    final_hostname="$current_hostname"
  fi
}

install_prerequisites() {
  echo "🔧 Installing prerequisites..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg
}

install_xlinkkai() {
  if [ -f "$INSTALL_FLAG" ]; then
    echo "✅ XLink Kai already appears to be installed. Skipping reinstallation."
    return
  fi

  echo "🔑 Configuring Team XLink repository..."
  mkdir -m 0755 -p /etc/apt/keyrings
  rm -f /etc/apt/keyrings/teamxlink.gpg
  curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
  chmod a+r /etc/apt/keyrings/teamxlink.gpg

  echo "📦 Adding repo..."
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | tee /etc/apt/sources.list.d/teamxlink.list > /dev/null

  echo "📥 Installing XLink Kai..."
  apt-get update
  apt-get install -y xlinkkai
}

setup_service() {
  echo "🔧 Setting up systemd service ($SERVICE_NAME)..."
  cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=XLink Kai Engine
Wants=network.target
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/usr/bin/kaiengine
GuessMainPID=yes
Restart=always
StartLimitInterval=5min
StartLimitBurst=4
StartLimitAction=reboot-force
EOF

  systemctl daemon-reload
  systemctl enable ${SERVICE_NAME}
  systemctl start ${SERVICE_NAME}
  echo "✅ Service ${SERVICE_NAME} enabled and started."
}

add_to_motd() {
  echo ""
  read -rp "Would you like to add connection info to the SSH welcome message (MOTD)? (y/N): " add_motd
  if [[ "$add_motd" =~ ^[Yy]$ ]]; then
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    if [ -z "$IP_ADDRESS" ]; then
      IP_ADDRESS="192.168.1.10"
    fi

    echo "" >> "$MOTD_FILE"
    echo "🕹️  Welcome to XLink Kai node" >> "$MOTD_FILE"
    echo "Access the Web UI at: http://$IP_ADDRESS:34522" >> "$MOTD_FILE"
    echo "To check status: sudo systemctl status $SERVICE_NAME" >> "$MOTD_FILE"
    echo "To restart:       sudo systemctl restart $SERVICE_NAME" >> "$MOTD_FILE"
    echo "To stop:          sudo systemctl stop $SERVICE_NAME" >> "$MOTD_FILE"
    echo "" >> "$MOTD_FILE"
    echo "✅ MOTD updated!"
  else
    echo "Skipping MOTD update."
  fi
}

clean_uninstall() {
  echo "🧹 Performing clean uninstall..."
  systemctl stop ${SERVICE_NAME} || true
  systemctl disable ${SERVICE_NAME} || true
  rm -f /etc/systemd/system/${SERVICE_NAME}.service
  systemctl daemon-reload

  apt-get purge -y xlinkkai
  apt-get autoremove -y
  rm -f "$KAI_CONFIG"
  rm -f /etc/apt/sources.list.d/teamxlink.list
  rm -f /etc/apt/keyrings/teamxlink.gpg
  sed -i '/xlinkkai/d' /etc/hosts
  sed -i '/XLink Kai/d' "$MOTD_FILE"

  echo "✅ XLink Kai has been removed."
  exit 0
}

print_summary() {
  echo ""
  echo "========================================="
  echo "🎉 Installation and service setup complete!"
  echo "To check service status: sudo systemctl status ${SERVICE_NAME}"
  echo "To restart the service:  sudo systemctl restart ${SERVICE_NAME}"
  echo ""
  echo "XLink Kai Web UI:"
  echo "  http://$(hostname -I | awk '{print $1}'):34522"
  echo "  or http://${final_hostname}:34522 (if hostname resolution is configured)"
  echo ""
  echo "This script was brought to you by:"
  echo "  🔗 https://github.com/theretrobristolian/xlinkkai"
  echo "  🎥 https://www.youtube.com/@TheRetroBristolian"
  echo ""
  echo "Special thanks to the XLink Kai team:"
  echo "  🌐 https://www.teamxlink.co.uk"
  echo "  💬 https://discord.gg/dZRpsxyp"
  echo "========================================="
}

main() {
  check_root
  install_sudo_if_missing

  clear
  echo "============================================="
  echo "🔧 XLink Kai Installer for Debian/Ubuntu"
  echo "---------------------------------------------"
  echo " Maintained by TheRetroBristolian"
  echo " GitHub: https://github.com/theretrobristolian"
  echo "============================================="
  echo ""

  if [ -f "$INSTALL_FLAG" ]; then
    echo "🚨 XLink Kai appears to already be installed."
    read -rp "Do you want to uninstall and remove it completely? (y/N): " uninstall
    if [[ "$uninstall" =~ ^[Yy]$ ]]; then
      clean_uninstall
    fi
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

  add_to_motd
  print_summary
}

main
