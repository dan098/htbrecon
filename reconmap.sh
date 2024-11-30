#!/bin/bash

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
ports=$(nmap $ip -p- --min-rate=1000 -T5 | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
if [ -z "$ports" ]; then
    echo "No ports found, trying with -Pn..."
    ports=$(nmap -p- --min-rate=1000 -T4 -Pn $ip | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
    if [ -z "$ports" ]; then
        echo "No ports found, exiting..."
        exit 1
    fi
fi

echo "Scanning ports: $ports"

# Run sVC scan on open ports
nmap -p$ports -sC -sV $ip -T4

# if Could not resolve host: in curl response add it to hosts file

http_ports=$(echo $ports | grep -oP '80|443' | tr '\n' ',')
curl -L $ip
REPLY=input('wanna edit host file? [y/N]')
if [ "$REPLY" == "y" ]; then
    sudo nano /etc/hosts
fi

# for http ports:
echo 'ffuf -u http://$ip/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt -r -recursion -t 200'
echo 'ffuf -u http://$ip/ -H "Host: FUZZ.domain.htb" -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-20000.txt -t 200"
