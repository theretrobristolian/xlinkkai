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

# Clean up
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean

echo "Configuration complete!"