#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for IP argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <ip>" 1>&2
    exit 1
fi

# Display the banner
cat << "EOF"
  ,,             ,,                                                          
`7MM        mm  *MM                                                          
  MM        MM   MM                                                          
  MMpMMMb.mmMMmm MM,dMMb.      `7Mb,od8 .gP"Ya   ,p6"bo   ,pW"Wq.`7MMpMMMb.  
  MM    MM  MM   MM    `Mb       MM' "',M'   Yb 6M'  OO  6W'   `Wb MM    MM  
  MM    MM  MM   MM     M8       MM    8M"""""" 8M       8M     M8 MM    MM  
  MM    MM  MM   MM.   ,M9       MM    YM.    , YM.    , YA.   ,A9 MM    MM  
.JMML  JMML.`MbmoP^YbmdP'      .JMML.   `Mbmmd'  YMbmd'   `Ybmd9'.JMML  JMML.
EOF

export ip=$1

# Run initial nmap scan in the background
echo "Running nmap scan on $ip..."
nmap -p- --min-rate=1000 -T4 -oG scan_results.gnmap "$ip" &
nmap_pid=$!

# Ask user for OS type while Nmap is running
echo "Is the target machine running (enter a number):"
echo "1) Windows"
echo "2) Linux"
while true; do
    read -r -n 1 os_choice
    echo
    case $os_choice in
        1 ) os_flag="win"; break;;
        2 ) os_flag="lin"; break;;
        * ) echo "Invalid option. Please choose 1 or 2.";;
    esac
done

# Wait for the nmap process to finish
wait $nmap_pid

# Parse open ports
ports=$(grep 'open' scan_results.gnmap | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
if [ -z "$ports" ]; then
    echo "No ports found, trying with -Pn..."
    nmap -p- --min-rate=1000 -T4 -Pn -oG scan_results.gnmap "$ip" &
    nmap_pid=$!
    wait $nmap_pid
    ports=$(grep 'open' scan_results.gnmap | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
fi

if [ -z "$ports" ]; then
    echo "No ports found." >&2
    exit 1
fi

echo "Open ports: $ports"

# Check for HTTP service on port 80
if echo "$ports" | grep -q "80"; then
    echo "Checking HTTP service on port 80..."
    response=$(curl -L --silent "$ip:80")
    if [[ "$response" == *"Could not resolve"* ]]; then
        hostname=$(echo "$response" | grep -oP '(?<=<hostname>).*?(?=</hostname>)')
        echo "Adding hostname '$hostname' to /etc/hosts..."
        echo "$ip $hostname" | sudo tee -a /etc/hosts
    fi

    # Open the web page
    if command_exists firefox; then
        firefox "$ip" &
    elif command_exists chromium; then
        chromium "$ip" &
    else
        echo "No compatible browser found (Firefox or Chromium)."
    fi
else
    echo "Port 80 is not open."
fi

# Fuzz for subdomains using ffuf
echo "Fuzzing for subdomains..."
ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -u http://$ip -H "Host: FUZZ.$ip" -mc all -o subdomains.json

# Add found subdomains to /etc/hosts
if [[ -f subdomains.json ]]; then
    subdomains=$(jq -r '.results[].url' subdomains.json | awk -F '://' '{print $2}' | awk -F '/' '{print $1}')
    for subdomain in $subdomains; do
        echo "Adding subdomain '$subdomain' to /etc/hosts..."
        echo "$ip $subdomain" | sudo tee -a /etc/hosts
    done
fi

# Fuzz for directories on the main domain
echo "Fuzzing for directories..."
ffuf -w /usr/share/wordlists/seclists/Discovery/Web-Content/big.txt -u http://$ip/FUZZ -mc all -o directories.json

# Display found directories
if [[ -f directories.json ]]; then
    echo "Found directories:"
    jq -r '.results[].url' directories.json
fi
