#!/usr/bin/env python3

import json
import subprocess
import os
import shutil
from datetime import datetime
import sys
import concurrent.futures
import time
import argparse
import glob
import threading
import re
import boto3
import botocore
import socket
import logging

# ANSI color codes
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color

# Spinner characters
SPINNER_CHARS = ('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')

# Array of build steps
BUILD_STEPS = [
    "Running BBOT scan",
    "Running Gospider scan",
    "Running DNSReaper scan",
    "Running wafw00f scan",
    "Running CloudBrute scan",
    "Running FFUF scan",
    "Running Arjun scan",
    "Running Corsy scan",
]

VAULT_FOLDER = os.path.expanduser("~/secos-vault")

CLOUDBRUTE_WORDLIST = "/usr/local/bin/.recon/config/wordlists/cloudbrute_large.txt"
CLOUDBRUTE_CONFIG = "/usr/local/bin/.recon/config/cloudbrute.conf"

FFUF_DEFAULT_CONFIG = "/usr/local/bin/.recon/config/ffuf/ffuf_default.conf"
FFUF_FULL_CONFIG = "/usr/local/bin/.recon/config/ffuf/ffuf_full.conf"

WAFW00F_OUTPUT = "wafw00f_output.json"
DNSREAPER_OUTPUT = "dnsreaper_output.json"
ARJUN_OUTPUT = "arjun_output.json"
CORSY_OUTPUT = "corsy_output.json"

# Task tracking system
class TaskTracker:
    def __init__(self):
        self.tasks = {}
        self.lock = threading.Lock()
        self.spinner_threads = {}

    def add_task(self, step):
        with self.lock:
            self.tasks[step] = {"status": "idle", "spinner": 0}
            
    def start_task(self, step):
        with self.lock:
            if step in self.tasks:
                self.tasks[step]["status"] = "running"
                # Create and start a new spinner thread for this task
                spinner_thread = threading.Thread(target=display_spinner, args=(step,))
                spinner_thread.daemon = True
                self.spinner_threads[step] = spinner_thread
                spinner_thread.start()

    def complete_task(self, step):
        with self.lock:
            if step in self.tasks:
                self.tasks[step]["status"] = "completed"
                update_step_status(step, "completed")

    def update_task(self, step, status, spinner_index=None):
        with self.lock:
            if step in self.tasks:
                self.tasks[step]["status"] = status
                if spinner_index is not None:
                    self.tasks[step]["spinner"] = spinner_index

    def get_task_status(self, step):
        with self.lock:
            return self.tasks[step]["status"], self.tasks[step]["spinner"]

task_tracker = TaskTracker()

def update_step_status(step, status, message=""):
    line = step + 3  # Add 3 to account for the header and empty line
    sys.stdout.write(f"\033[{line};0H")  # Move cursor to the beginning of the line
    sys.stdout.write("\033[K")  # Clear the line
    if status == "idle":
        sys.stdout.write(f"{BLUE}◯ {BUILD_STEPS[step]}{NC}")
    elif status == "running":
        sys.stdout.write(f"{YELLOW}{message} {BUILD_STEPS[step]}{NC}")
    elif status == "completed":
        sys.stdout.write(f"{GREEN}✓ {BUILD_STEPS[step]}{NC}")
    sys.stdout.write("\033[{};0H".format(len(BUILD_STEPS) + 4))  # Move cursor to the end
    sys.stdout.flush()

def display_spinner(step):
    while True:
        status, spinner_index = task_tracker.get_task_status(step)
        if status == "completed":
            update_step_status(step, "completed")
            break
        update_step_status(step, "running", SPINNER_CHARS[spinner_index])
        task_tracker.update_task(step, "running", (spinner_index + 1) % len(SPINNER_CHARS))
        time.sleep(0.1)

def parse_arguments():
    parser = argparse.ArgumentParser(description="secOS recon script")
    parser.add_argument("domain", nargs="?", help="The domain to scan")
    parser.add_argument("-full", action="store_true", help="Run full scan")
    parser.add_argument("-aws", action="store_true", help="Configure AWS and use Fireprox")
    args = parser.parse_args()
    if not args.domain:
        parser.print_help()
        return None
    return args

def run_command(command, output_file=None, capture_output=False):
    try:
        if output_file:
            command.extend(["-o", output_file])
        if capture_output:
            return subprocess.check_output(command, text=True)
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return output_file if output_file else True
    except subprocess.CalledProcessError as e:
        print(f"Error running {command[0]}: {e}")
    except Exception as e:
        print(f"An unexpected error occurred while running {command[0]}: {str(e)}")
    return None

def clean_up(*files_to_remove):
    try:
        for file in files_to_remove + (DNSREAPER_OUTPUT, ARJUN_OUTPUT, f"corsy_{domain}_input.txt", f"corsy_{domain}_output.json"):
            if file and os.path.exists(file):
                os.remove(file)
        if os.path.exists("report"):
            shutil.rmtree("report")
        if os.path.exists("bbot_output"):
            shutil.rmtree("bbot_output")
        for file in glob.glob("ffuf_*.json"):
            os.remove(file)
    except Exception as e:
        print(f"Error during cleanup: {str(e)}")

def delete_fireprox_api(api_id):
    delete_command = ["fireprox", "--command", "delete", "--api_id", api_id]
    try:
        subprocess.run(delete_command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"{GREEN}Fireprox API Gateway (ID: {api_id}) deleted successfully{NC}")
    except subprocess.CalledProcessError:
        print(f"{RED}Error deleting Fireprox API Gateway (ID: {api_id}){NC}")

def configure_aws_and_fireprox(domain):
    def check_aws_configuration():
        try:
            session = boto3.Session()
            sts = session.client('sts')
            sts.get_caller_identity()
            return True
        except botocore.exceptions.NoCredentialsError:
            return False

    if not check_aws_configuration():
        print(f"{RED}Error: AWS credentials not found. Please run 'aws configure' to set up your credentials.{NC}")
        return None, None

    # Get the current AWS user's ARN
    aws_user_arn = subprocess.check_output(["aws", "sts", "get-caller-identity", "--query", "Arn", "--output", "text"]).decode().strip()
    
    # Set up Fireprox
    create_command = ["fireprox", "--command", "create", "--url", f"https://{domain}"]
    try:
        result = subprocess.run(create_command, capture_output=True, text=True, check=True)
        
        # Use regex to find the URL and API ID in the output
        url_match = re.search(r'(https://[^\s]+\.amazonaws\.com/fireprox/)', result.stdout)
        api_id_match = re.search(r'\(([a-z0-9]+)\)', result.stdout)
        
        if not url_match or not api_id_match:
            raise Exception("Failed to create Fireprox proxy")
        
        proxy_url = url_match.group(1)
        api_id = api_id_match.group(1)
        
        # Create a policy document allowing access only to the authenticated user
        policy_document = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": aws_user_arn
                    },
                    "Action": "execute-api:Invoke",
                    "Resource": f"arn:aws:execute-api:*:*:{api_id}/*/*/*"
                }
            ]
        }
        
        # Apply the policy to the API Gateway
        update_policy_command = [
            "aws", "apigateway", "update-rest-api",
            "--rest-api-id", api_id,
            "--patch-operations",
            f'op=replace,path=/policy,value={json.dumps(json.dumps(policy_document))}'
        ]
        subprocess.run(update_policy_command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Clear and update proxychains config with strict chain
        with open("/etc/proxychains.conf", "w") as f:
            f.write("strict_chain\n")
            f.write("dns_server = 1.1.1.1\n")
            f.write("[ProxyList]\n")
            f.write(f"http {proxy_url} 443\n")

        return proxy_url, api_id
    except subprocess.CalledProcessError as e:
        print(f"Error setting up Fireprox: {e}")
        return None, None

def fetch_txt_records(domain, max_retries=3, retry_delay=5):
    txt_command = ["dig", "@1.1.1.1", domain, "txt", "+short"]
    for _ in range(max_retries):
        txt_output = run_command(txt_command, capture_output=True)
        if txt_output:
            return [line.strip().strip('"') for line in txt_output.split("\n") if line.strip() and not line.startswith(";")]
        time.sleep(retry_delay)
    print(f"Max retries reached. Skipping TXT record retrieval for {domain}.")
    return []

def is_subdomain_active(subdomain):
    try:
        socket.gethostbyname(subdomain)
        return True
    except socket.gaierror:
        return False

def run_bbot_scan(domain):
   output_dir = "bbot_output"
   name = "secos"
   
   shutil.rmtree(output_dir, ignore_errors=True)
   
   subprocess.run([
       "bbot",
       "-t", domain,
       "-f", "subdomain-enum", 
       "-n", name,
       "-o", output_dir,
       "--silent"
   ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
   
   subdomains_file = os.path.join(output_dir, name, "subdomains.txt")
   
   if not os.path.exists(subdomains_file):
       raise FileNotFoundError(f"Subdomains file not found at {subdomains_file}")
   
   with open(subdomains_file, 'r') as infile:
       active = []
       for subdomain in infile:
           subdomain = subdomain.strip()
           if subdomain and is_subdomain_active(subdomain):
               active.append(subdomain)
   
   with open(subdomains_file, 'w') as outfile:
       outfile.write('\n'.join(active))
   
   return subdomains_file
        
   

def run_parallel_scans(domain, subdomains_file, scan_data, use_proxy=False):
    scan_functions = {
        'gospider': (1, lambda: run_gospider_and_jsluice(domain, VAULT_FOLDER, scan_data, use_proxy)),
        'dnsreaper': (2, lambda: run_dnsreaper_scan(subdomains_file)),
        'wafw00f': (3, lambda: run_wafw00f_scan(domain, subdomains_file)),
        'cloudbrute': (4, lambda: run_cloudbrute_scan(domain, VAULT_FOLDER)),
        'ffuf': (5, lambda: run_ffuf_scan(domain, scan_data, FFUF_FULL_CONFIG if run_full else FFUF_DEFAULT_CONFIG, use_proxy)),
        'arjun': (6, lambda: run_arjun_scan(domain, scan_data)),
        'corsy': (7, lambda: run_corsy_scan(domain, [item["domain"] for item in scan_data[1:]]))
    }

    results = {}
    futures = {}
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(scan_functions)) as executor:
        # Submit all tasks
        for name, (step, func) in scan_functions.items():
            task_tracker.start_task(step)
            futures[name] = executor.submit(func)
            
            # Set up completion callback for each task
            def make_callback(task_name, task_step):
                def callback(future):
                    try:
                        results[task_name] = future.result()
                        task_tracker.complete_task(task_step)
                    except Exception as e:
                        print(f"Error in {task_name}: {str(e)}")
                        results[task_name] = None
                        task_tracker.complete_task(task_step)
                return callback
            
            futures[name].add_done_callback(make_callback(name, scan_functions[name][0]))
        
        # Wait for all futures to complete
        concurrent.futures.wait(futures.values())
    
    # Return results in the expected order
    return (
        results.get('gospider'),
        results.get('dnsreaper'),
        *results.get('wafw00f', (None, None)),
        results['cloudbrute'],
        results['ffuf'],
        results['arjun'],
        results['corsy']
    )

def run_gospider_and_jsluice(domain, vault_folder, scan_data, use_proxy=False):
    gospider_output_folder = os.path.join(vault_folder, domain, "Gospider")
    jsluice_folder = os.path.join(vault_folder, domain, "JSluice")
    shutil.rmtree(gospider_output_folder, ignore_errors=True)
    os.makedirs(jsluice_folder, exist_ok=True)
    
    urls_to_scan = [domain] + [item["domain"] for item in scan_data[1:] if item["domain"] != domain and "www." not in item["domain"]]
    for url in urls_to_scan:
        command = ["gospider", "-s", f"https://{url}/", "-o", gospider_output_folder]
        if use_proxy:
            command = ["proxychains"] + command
        run_command(command)
    
    prefix_order = ["[url]", "[javascript]", "[linkfinder]", "[href]"]
    js_files_found = False
    
    for file_path in glob.glob(os.path.join(gospider_output_folder, "*")):
        if os.path.isfile(file_path):
            with open(file_path, "r") as file:
                lines = sorted(file.readlines(), key=lambda line: next((i for i, prefix in enumerate(prefix_order) if line.startswith(prefix)), len(prefix_order)))
            
            new_file_path = f"{file_path}.md"
            with open(new_file_path, "w") as file:
                file.writelines(lines)
            os.remove(file_path)
            
            if os.path.getsize(new_file_path) == 0:
                os.remove(new_file_path)
            
            for line in lines:
                if line.startswith("[javascript] - "):
                    js_url = line.strip().split(" - ")[1]
                    if not js_files_found:
                        js_files_found = True
                    jsluice_output = subprocess.run(["jsluice", "secrets", js_url], capture_output=True, text=True).stdout
                    if jsluice_output.strip():
                        js_file_name = js_url.split("/")[-1]
                        jsluice_findings_file = os.path.join(jsluice_folder, f"{js_file_name}_findings.md")
                        with open(jsluice_findings_file, "w") as f:
                            f.write(jsluice_output)

def run_dnsreaper_scan(subdomains_file):
    subprocess.run(["dnsreaper", "file", "--filename", subdomains_file, "--out", DNSREAPER_OUTPUT, "--out-format", "json"], 
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    with open(DNSREAPER_OUTPUT, "r") as file:
        result = json.loads(file.read().strip() or "[]")
    return result

def run_ffuf_scan(domain, scan_data, config_file, use_proxy=False):
    ffuf_dir = os.path.join(VAULT_FOLDER, domain, "FFUF")
    os.makedirs(ffuf_dir, exist_ok=True)
    if not os.path.exists(config_file):
        print(f"Error: {config_file} file not found.")
        return []
    
    def run_ffuf_for_url(url):
        subdomain_or_root = url.replace("https://", "").split("/")[0]
        ffuf_output_file = os.path.join(ffuf_dir, f"ffuf_{subdomain_or_root}.json")
        ffuf_command = f"ffuf -config {config_file} -u '{url}/FUZZ' -o {ffuf_output_file} -of json -s"
        if use_proxy:
            ffuf_command = f"proxychains {ffuf_command}"
        try:
            # Run FFUF and wait for completion
            process = subprocess.Popen(ffuf_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            process.wait()  # Wait for the process to complete
            
            if process.returncode == 0 and os.path.exists(ffuf_output_file):
                with open(ffuf_output_file, "r") as file:
                    ffuf_data = json.load(file)
                ffuf_results_file = os.path.join(ffuf_dir, f"{subdomain_or_root}_ffuf.md")
                with open(ffuf_results_file, "w") as file:
                    for result in ffuf_data.get("results", []):
                        file.write(f"{result.get('status', 'N/A')} - {result.get('url', 'N/A')}\n")
                    file.write("\n")
                return ffuf_output_file
        except Exception as e:
            print(f"Error during FFUF scan for {url}: {e}")
        return None

    urls_to_scan = [f"https://{domain}"] + [f"https://{item['domain']}" for item in scan_data[1:] if not item['domain'].startswith("www.")]
    ffuf_output_files = []
    
    # Run FFUF scans sequentially to ensure proper completion
    for url in urls_to_scan:
        output_file = run_ffuf_for_url(url)
        if output_file:
            ffuf_output_files.append(output_file)
    
    return ffuf_output_files

def run_cloudbrute_scan(domain, vault_folder):
    keyword = domain.split('.')[0]
    cloudbrute_dir = os.path.join(vault_folder, domain, "CloudBrute")
    try:
        os.makedirs(cloudbrute_dir, exist_ok=True)
        output_file = os.path.join(cloudbrute_dir, "cloudbrute.md")
        
        # Create empty file first to ensure it exists
        with open(output_file, 'w') as f:
            pass
            
        cloudbrute_command = [
            "cloudbrute",
            "-d", domain,
            "-k", keyword,
            "-w", CLOUDBRUTE_WORDLIST,
            "-C", CLOUDBRUTE_CONFIG,
            "-o", output_file
        ]
        run_command(cloudbrute_command)
        
        # Only process if file has content
        if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
            with open(output_file, 'r') as f:
                lines = f.readlines()
            unique_lines = list(dict.fromkeys(lines))
            with open(output_file, 'w') as f:
                f.writelines(unique_lines)
        return True
    except Exception as e:
        print(f"Error in cloudbrute: {str(e)}")
        return False
        
def run_wafw00f_scan(domain, subdomains_file):
    with open(subdomains_file, 'r') as f:
        subdomains = [line.strip() for line in f]
    all_domains = [domain] + subdomains
    wafw00f_command = ["wafw00f"] + [f"https://{d}" for d in all_domains] + ["-a", "-o", WAFW00F_OUTPUT, "-f", "json"]
    run_command(wafw00f_command)
    with open(WAFW00F_OUTPUT, 'r') as f:
        waf_data = json.load(f)
    root_waf = None
    different_wafs = {}
    processed_domains = set()
    for item in waf_data:
        subdomain = item["url"].split("://")[1]
        if subdomain not in processed_domains:
            processed_domains.add(subdomain)
            if subdomain == domain:
                root_waf = {
                    "url": item["url"],
                    "detected": item["detected"],
                    "firewall": item["firewall"] if item["detected"] else "No WAF detected",
                    "manufacturer": item["manufacturer"] if item["detected"] else "N/A"
                }
            elif item["detected"]:
                if not root_waf or item["firewall"] != root_waf["firewall"]:
                    different_wafs[subdomain] = (item["firewall"], item["manufacturer"])
            else:
                different_wafs[subdomain] = ("No WAF detected", "N/A")
    if not root_waf:
        root_waf = {
            "url": f"https://{domain}",
            "detected": False,
            "firewall": "No WAF detected",
            "manufacturer": "N/A"
        }
    return root_waf, different_wafs

def run_arjun_scan(domain, scan_data):
    arjun_dir = os.path.join(VAULT_FOLDER, domain, "Arjun")
    os.makedirs(arjun_dir, exist_ok=True)
    
    def is_api_endpoint(url):
        return 'api' in url.lower() or any('api' in part.lower() for part in url.split('/'))
    
    urls_to_scan = [f"https://{domain}"] + [f"https://{item['domain']}" for item in scan_data[1:] if not item['domain'].startswith("www.")]
    api_urls = [url for url in urls_to_scan if is_api_endpoint(url)]
    
    arjun_results = {}
    for url in api_urls:
        safe_filename = re.sub(r'[^\w\-_\. ]', '_', url.replace('https://', ''))
        output_file = os.path.join(arjun_dir, f"arjun_{safe_filename}.json")
        arjun_command = ["arjun", "-u", url, "-oJ", output_file]
        
        # Run Arjun and wait for completion
        process = subprocess.Popen(arjun_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        process.wait()  # Wait for the process to complete
        
        try:
            if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                with open(output_file, 'r') as f:
                    result = json.load(f)
                if result:  # Only add results if there are actual findings
                    arjun_results[url] = result
        except json.JSONDecodeError:
            print(f"Invalid JSON in Arjun output file for {url}")
    
    if arjun_results:
        with open(ARJUN_OUTPUT, 'w') as f:
            json.dump(arjun_results, f, indent=2)
    
    return arjun_results

def run_corsy_scan(domain, subdomains):
    corsy_input_file = f"corsy_{domain}_input.txt"
    corsy_output_file = f"corsy_{domain}_output.json"
    
    # Create input file with HTTPS URLs
    with open(corsy_input_file, 'w') as f:
        f.write(f"https://{domain}\n")
        for sub in subdomains:
            f.write(f"https://{sub}\n")
    
    # Run Corsy and wait for completion
    corsy_command = ["corsy", "-i", corsy_input_file, "-o", corsy_output_file]
    process = subprocess.Popen(corsy_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    process.wait()  # Wait for the process to complete
    
    # Read and return results
    if os.path.exists(corsy_output_file) and os.path.getsize(corsy_output_file) > 0:
        with open(corsy_output_file, 'r') as f:
            return json.load(f)
    return None

def create_overview_note(domain_folder, domain, txt_records, scan_data, dnsreaper_data, root_waf, different_wafs, corsy_results):
    www_subdomain = f"www.{domain}"
    overview_note_path = os.path.join(domain_folder, "overview.md")
    with open(overview_note_path, "w") as file:
        # Custom title
        file.write(f"# <span class=\"custom-title\">{domain}</span>\n")
        file.write("---\n")
        
        # Multi-column callouts
        file.write("> [!multi-column]\n")
        file.write(">\n")
        
        # WAF Findings
        file.write(">> [!note]+ WAF info(Wafw00f)\n")
        file.write(f">> {domain} : {root_waf['firewall']}\n")
        if different_wafs:
            file.write(">>\n")
            file.write(">> ***\n")
            file.write(">>\n")
            for subdomain, (firewall, _) in different_wafs.items():
                file.write(f">> {subdomain} : {firewall}\n")
        file.write(">\n")
        
        # Subdomains Vulnerable to Takeover
        file.write(">> [!note]+ Subdomain Takeover(DNSReaper)\n")
        if dnsreaper_data:
            for item in dnsreaper_data:
                file.write(f">> - {item['domain']}\n")
        else:
            file.write(">> None found\n")
        file.write(">\n")
        
        # CORS Misconfiguration (Corsy)
        file.write(">> [!note]+ CORS Misconfiguration (Corsy)\n")
        if corsy_results:
            for host, data in corsy_results.items():
                file.write(f">> {host} : {data['class']}\n")
        else:
            file.write(">> None found\n")
        file.write("\n")
        
        # TXT Records callout (outside the multi-column layout)
        file.write("> [!note]+ TXT Records\n")
        for record in txt_records:
            file.write(f"> {record}\n")
        file.write("\n")

        # Subdomains table
        file.write('<h2 style="text-align:center;text-decoration:underline;">Subdomains</h2>\n\n')
        file.write("| Subdomain | IP | HTTP Status | HTTPS Status | Server |\n")
        file.write("|:-----------:|:----:|:-----------:|:------------:|:--------:|\n")
        for item in scan_data[1:]:
            if item["domain"] != domain and item["domain"] != www_subdomain:
                subdomain = item["domain"]
                ip = ", ".join(item.get("ip", ["N/A"]))
                http_status = item.get('http', ['N/A'])[0]
                https_status = item.get('https', ['N/A'])[0]
                server = item.get('http', ['', '', 'N/A'])[2] or item.get('https', ['', '', 'N/A'])[2]
                
                file.write(f"| {subdomain} | {ip} | {http_status} | {https_status} | {server} |\n")
    return overview_note_path

def save_to_obsidian(vault_folder, domain, txt_records, scan_data, dnsreaper_data, root_waf, different_wafs, corsy_results):
    domain_folder = os.path.join(vault_folder, domain)
    os.makedirs(domain_folder, exist_ok=True)
    create_overview_note(domain_folder, domain, txt_records, scan_data, dnsreaper_data, root_waf, different_wafs, corsy_results)
    return domain_folder

if __name__ == "__main__":
    args = parse_arguments()
    if args is None:
        sys.exit(1)
    
    output_file = None
    subdomains_file = None
    ffuf_output_files = []
    api_id = None
    
    try:
        domain = args.domain
        run_full = args.full
        use_aws = args.aws
        
        # Print the header
        os.system('clear')        
        print(f"{BLUE}secＯ•Ｓ -- RECON")
        print(f"{BLUE}----------------------")
        print()
                
        for i in range(len(BUILD_STEPS)):
            task_tracker.add_task(i)
            update_step_status(i, "idle")
        
        if use_aws:
            proxy_url, api_id = configure_aws_and_fireprox(domain)
            if proxy_url is None:
                sys.exit(1)
            print(f"\n{GREEN}AWS configured successfully")
            print(f"Fireprox proxy set up: {proxy_url}{NC}")
        
        # Start BBOT scan
        task_tracker.start_task(0)
        subdomains_file = run_bbot_scan(domain)
        task_tracker.complete_task(0)
        
        # Fetch TXT records without progress tracking
        txt_records = fetch_txt_records(domain)
        
        if subdomains_file:
            # Create scan_data structure
            scan_data = [{"domain": domain, "txt_records": txt_records}]
            with open(subdomains_file, 'r') as f:
                for subdomain in f.readlines():
                    scan_data.append({"domain": subdomain.strip(), "ip": []})
            
            _, dnsreaper_data, root_waf, different_wafs, _, ffuf_output_files, arjun_results, corsy_results = run_parallel_scans(domain, subdomains_file, scan_data, use_aws)
            
            domain_folder = save_to_obsidian(VAULT_FOLDER, domain, txt_records, scan_data, dnsreaper_data, root_waf, different_wafs, corsy_results)
                        
            # Clear the AWS configuration and Fireprox setup messages
            if use_aws:
                print("\033[2A\033[J", end="")
            
            print(f"\n{GREEN}Results saved to {domain_folder}{NC}")
        else:
            print(f"{RED}Error: No subdomains found or BBOT scan failed.{NC}")
    
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Scan interrupted by user. Cleaning up...{NC}")
    except Exception as e:
        print(f"{RED}An unexpected error occurred: {str(e)}{NC}")
    finally:
        # Cleanup operations
        if api_id:
            delete_fireprox_api(api_id)
        
        clean_up(output_file, subdomains_file, *ffuf_output_files, WAFW00F_OUTPUT)
        
        print(f"{GREEN}Scan completed.{NC}")