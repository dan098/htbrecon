#!/bin/bash

if [[ $# -eq 1 ]]; then
        ip=$1
else
        echo "inserisci ip" 1>&2
        exit 1
fi

ports=$(nmap -p- --min-rate=1000 -T4 $ip | grep '^[0-9]' | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
if [ -z "$ports" ]; then
    echo "Nessuna porta trovata, provo con -Pn"
    ports=$(nmap -p- --min-rate=1000 -T4 $ip -Pn | grep '^[0-9]' | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
fi

if [ -z "$ports" ]; then
    echo "Nessuna porta trovata" >&2
    exit 1
fi

nmap -p$ports -sC -sV $ip -T4 -v -Pn
