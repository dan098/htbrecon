#!/usr/bin/env python3
import sys
import subprocess
import re
import os
import concurrent.futures

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    return output.decode('utf-8'), error.decode('utf-8')

def scan_ports(ip):
    print(f"Scansione delle porte per {ip}...")
    command = f"nmap -p- --min-rate=1000 -T4 {ip}"
    output, error = run_command(command)
    
    ports = re.findall(r'(\d+)/tcp', output)
    if not ports:
        print("Nessuna porta trovata, provo con -Pn")
        command += " -Pn"
        output, error = run_command(command)
        ports = re.findall(r'(\d+)/tcp', output)
    
    if not ports:
        print("Nessuna porta trovata", file=sys.stderr)
        sys.exit(1)
    
    return ','.join(ports)

def detailed_scan(ip, ports):
    print(f"Esecuzione scansione dettagliata su {ip} per le porte {ports}...")
    commands = [
        f"nmap -p{ports} -sC -sV {ip} -T4 -v -Pn",
        f"nmap -p{ports} -A -sV {ip} -T4"
    ]
    
    for command in commands:
        output, error = run_command(command)
        filename = f"scan_results_{ip.replace('.', '_')}.txt"
        with open(filename, 'a') as f:
            f.write(f"Command: {command}\n\n")
            f.write(output)
            f.write("\n\n")
        print(f"Risultati salvati in {filename}")

def add_to_hosts(ip, domain):
    print(f"Aggiunta di {domain} a /etc/hosts...")
    with open('/etc/hosts', 'r') as f:
        content = f.read()
    
    if f"{ip} {domain}" not in content:
        with open('/etc/hosts', 'a') as f:
            f.write(f"\n{ip} {domain}")
        print(f"Aggiunto {domain} a /etc/hosts")
    else:
        print(f"{domain} già presente in /etc/hosts")

def fuzz_directories(domain):
    print(f"Fuzzing delle directory per {domain}...")
    command = f"gobuster dir -u http://{domain} -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -t 200 -o gobuster_results_{domain}.txt"
    output, error = run_command(command)
    print(f"Risultati del fuzzing salvati in gobuster_results_{domain}.txt")

def fuzz_subdomains(domain):
    print(f"Fuzzing dei subdomains per {domain}...")
    command = f"gobuster dns -d {domain} -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 200 -o subdomain_results_{domain}.txt"
    output, error = run_command(command)
    print(f"Risultati del fuzzing dei subdomains salvati in subdomain_results_{domain}.txt")
    
    subdomains = []
    with open(f"subdomain_results_{domain}.txt", 'r') as f:
        for line in f:
            if "Found:" in line:
                subdomain = line.split()[1]
                subdomains.append(subdomain)
    return subdomains

def main():
    if len(sys.argv) != 2:
        print("Utilizzo: sudo ./script.py <indirizzo_ip>", file=sys.stderr)
        sys.exit(1)
    
    if os.geteuid() != 0:
        print("Questo script deve essere eseguito con privilegi di root (sudo).", file=sys.stderr)
        sys.exit(1)
    
    ip = sys.argv[1]
    ports = scan_ports(ip)
    detailed_scan(ip, ports)
    
    if '80' in ports.split(',') or '443' in ports.split(','):
        domain = input("Rilevata una porta web. Inserisci il dominio principale: ")
        add_to_hosts(ip, domain)
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = []
            futures.append(executor.submit(fuzz_directories, domain))
            futures.append(executor.submit(fuzz_subdomains, domain))
            
            for future in concurrent.futures.as_completed(futures):
                if future.result():
                    subdomains = future.result()
                    for subdomain in subdomains:
                        add_to_hosts(ip, subdomain)
                        executor.submit(fuzz_directories, subdomain)

        print("Tutte le operazioni di fuzzing sono state completate.")

if __name__ == "__main__":
    main()
