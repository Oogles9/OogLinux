#!/bin/bash
# Oogle Linux Security Tools Setup Script
set -e
echo "Installing security tools for Oogle Linux..."
TOOLS_DIR="/opt/security-tools"
mkdir -p "${TOOLS_DIR}"
# Install network security tools
apt-get update
apt-get install -y nmap wireshark aircrack-ng john hydra sqlmap dirb nikto hashcat gobuster
# Setup Metasploit Framework
if ! command -v msfconsole &> /dev/null; then
    cd "${TOOLS_DIR}"
    apt-get install -y build-essential ruby ruby-dev git postgresql libpq-dev
    git clone https://github.com/rapid7/metasploit-framework.git
    cd metasploit-framework
    gem install bundler
    bundle install
    ln -sf "${TOOLS_DIR}/metasploit-framework/msfconsole" /usr/local/bin/msfconsole
fi
# Create security tools launcher script
cat > /usr/local/bin/oogle-security-menu << "EOFMENU"
#!/bin/bash
echo "=== Oogle Linux Security Tools Menu ==="
PS3="Select a tool: "
tools=("Nmap" "Wireshark" "Aircrack-ng" "John" "Hydra" "SQLMap" "Metasploit" "Quit")
select opt in "${tools[@]}"
do
    case $opt in
        "Nmap") nmap -h; break;;
        "Wireshark") wireshark & disown; break;;
        "Aircrack-ng") aircrack-ng --help; break;;
        "John") john; break;;
        "Hydra") hydra -h; break;;
        "SQLMap") sqlmap --help; break;;
        "Metasploit") msfconsole; break;;
        "Quit") break;;
        *) echo "Invalid option $REPLY"; break;;
    esac
done
EOFMENU
chmod +x /usr/local/bin/oogle-security-menu
echo "Security tools setup complete!"
