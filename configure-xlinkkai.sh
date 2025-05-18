#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Update and upgrade the system
echo "Updating and upgrading system..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Set the hostname to xlinkkai1
echo "Setting hostname to 'xlinkkai1'..."
sudo hostnamectl set-hostname xlinkkai1
echo "127.0.1.1 xlinkkai1" | sudo tee -a /etc/hosts > /dev/null

# Install required packages
echo "Installing required packages..."
sudo apt install -y ca-certificates curl gnupg

# Prepare the keyring and repository
echo "Configuring Team XLink repository..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/teamxlink.gpg
curl -fsSL https://dist.teamxlink.co.uk/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/teamxlink.gpg
sudo chmod a+r /etc/apt/keyrings/teamxlink.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/teamxlink.gpg] https://dist.teamxlink.co.uk/linux/debian/static/deb/release/ /" | sudo tee /etc/apt/sources.list.d/teamxlink.list > /dev/null

# Update package lists and install XLink Kai
echo "Updating package lists and installing XLink Kai..."
sudo apt-get update
sudo apt-get install -y xlinkkai

# Create the kaiengine service file
echo "Creating the kaiengine service..."
sudo bash -c 'cat > /etc/systemd/system/kaiengine.service <<EOF
[Unit]
Description=kaiengine
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
EOF'

# Reload systemd, enable and start the kaiengine service
echo "Enabling and starting the kaiengine service..."
sudo systemctl daemon-reload
sudo systemctl enable kaiengine
sudo systemctl start kaiengine

# Clean up
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean

# Get the IP address of the VM
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="192.168.1.10" # Example fallback IP
fi

# Display helpful information to the user
echo -e "\n========================================="
echo "Installation and service setup completed!"
echo "To check the status of the kaiengine service, run:"
echo "  sudo systemctl status kaiengine"
echo ""
echo "If you need to restart the service, run:"
echo "  sudo systemctl restart kaiengine"
echo ""
echo "Why use XLink Kai? XLink Kai allows you to play system-link games over the internet with other players worldwide."
echo ""
echo "To access the XLink Kai Web UI, go to one of the following URLs:"
echo "  http://$IP_ADDRESS:34522"
echo "  OR, if DNS is configured correctly:"
echo "  http://xlinkkai:34522"
echo "========================================="
echo ""
echo "This script has been provided by TheRetroBristolian 2025."
echo "Further information can be found at:"
echo "  https://github.com/theretrobristolian/xlinkkai"
echo "  https://www.youtube.com/@TheRetroBristolian"
echo ""
echo "This script could not have been possible without special thanks to the XLink Kai team:"
echo "  https://www.teamxlink.co.uk"
echo "  https://discord.gg/dZRpsxyp - Team XLink (Official) Discord Server"
echo "Special thanks to user @CrunchBite."