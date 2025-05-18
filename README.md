# XLink Kai Installer Script

This repository contains a Bash script to automate the installation and configuration of **XLink Kai** on a Debian-based Linux virtual machine. The script streamlines the process of setting up the XLink Kai service and provides a helpful Web UI for managing your XLink Kai account and settings.

---

## What is XLink Kai?

[XLink Kai](https://www.teamxlink.co.uk) is a free, peer-to-peer (P2P) network that enables system-link gaming over the internet. It allows players to enjoy LAN-enabled games with others worldwide, even if they aren't in the same room or connected to the same local network.

---

## What Does This Script Do?

This script performs the following tasks:
1. Updates and upgrades your system.
2. Sets the hostname of the machine to `xlinkkai1`.
3. Installs required dependencies such as `ca-certificates`, `curl`, and `gnupg`.
4. Configures the XLink Kai Debian repository and imports its GPG key.
5. Installs the **XLink Kai Engine**.
6. Creates and enables a systemd service (`kaiengine.service`) to run the XLink Kai engine as a background service.
7. Outputs helpful information, including the Web UI URL and instructions for accessing it.

---

## How to Run the Script

### Prerequisites
- A Debian-based Linux VM or physical machine (e.g., Ubuntu, Debian).
- Internet access for downloading dependencies and accessing the XLink Kai repository.
- An XLink Kai account. If you don’t have one, you can create it [here](https://www.teamxlink.co.uk).

### Steps to Run

1. **SSH into your Linux VM**:  
   Connect to your VM using an SSH client or terminal.

2. **Download the script**:  
   Run the following command to download the installation script:
   ```bash
   wget https://raw.githubusercontent.com/theretrobristolian/xlinkkai/main/configure-xlinkkai.sh -O configure-xlinkkai.sh

3. **Make the script executable**: 
    Set the appropriate permissions for the script:
    ```bash
    chmod +x configure-xlinkkai.sh

4. **Run the script**:
    Execute the script with sudo:
    ```bash
    sudo ./configure-xlinkkai.sh

## Access the Web UI

After the script completes, you will see a summary with the Web UI URL. It will look something like this:

- `http://<IP_ADDRESS>:34522` (replace `<IP_ADDRESS>` with your VM's IP address).
- If DNS is configured correctly, you can also use: `http://xlinkkai:34522`.

### Log in to XLink Kai:
- Use your XLink Kai account credentials to log in.
- If you don’t have an account, create one at [XLink Kai Website].

---

### Optional Steps:
- Navigate to the **Settings** in the Web UI:
  - Change the color scheme to your preference.
  - Enable auto-login for convenience.
  - Change the default port to **30000** if desired.

---

## Special Thanks

This script has been provided by **TheRetroBristolian 2025**.  
For further information and updates, visit:
- [GitHub Repository]
- [YouTube Channel]

This script would not have been possible without special thanks to the **XLink Kai team**:
- [Team XLink Website]
- [Team XLink (Official) Discord Server]

Special thanks to **@CrunchBite** for their contributions and support.

---

## Feedback

We welcome feedback on improvements or issues. Please feel free to open an issue or submit a pull request in this repository. Happy gaming!