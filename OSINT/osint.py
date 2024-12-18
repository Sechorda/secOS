#!/usr/bin/env python3
import subprocess, sys, os, json, cloudscraper, re, threading, time, shlex
from bs4 import BeautifulSoup
import requests
from typing import Dict, Any, Optional, List
from dataclasses import dataclass

COLORS = {'GREEN': '\033[0;32m', 'YELLOW': '\033[1;33m', 'BLUE': '\033[0;34m', 'RED': '\033[0;31m', 'NC': '\033[0m'}
SPINNER_CHARS = ('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
VAULT_FOLDER = os.path.expanduser("~/secos-vault")
SF_OUTPUT_FILE = "./sf_output.json"

@dataclass
class TaskTracker:
    target: str
    status: str = "idle"
    spinner: int = 0
    spinner_line: int = 4
    details_line: int = 8

    def __post_init__(self):
        self.lock = threading.Lock()
        self.spinner_thread = None

    def start(self):
        with self.lock:
            self.status = "running"
            sys.stdout.write("\033[s\n\n\nDetails:\n\n")  # Save cursor and add initial spacing
            self.spinner_thread = threading.Thread(target=self._run_spinner, daemon=True)
            self.spinner_thread.start()

    def complete(self):
        with self.lock:
            self.status = "completed"
            self._update_display("✓")

    def _get_query_type(self):
        if '-' in self.target:
            return "phone number"
        elif '@' in self.target:
            return "email"
        elif ' ' in self.target:
            return "full name"
        else:
            return "username"

    def _update_display(self, symbol):
        sys.stdout.write("\033[s")  # Save current cursor position
        sys.stdout.write(f"\033[{self.spinner_line};0H")  # Move to spinner line
        sys.stdout.write("\033[K")  # Clear the line
        color = COLORS['GREEN'] if self.status == "completed" else COLORS['YELLOW']
        sys.stdout.write(f"{color}{symbol} Running OSINT query for {self._get_query_type()}: {self.target}{COLORS['NC']}")
        sys.stdout.write("\033[u")  # Restore cursor position
        sys.stdout.flush()

    def _run_spinner(self):
        while self.status != "completed":
            with self.lock:
                self._update_display(SPINNER_CHARS[self.spinner])
                self.spinner = (self.spinner + 1) % len(SPINNER_CHARS)
            time.sleep(0.1)
        with self.lock:
            self._update_display("✓")
            sys.stdout.write("\033[u\033[B\033[B")  # Restore and move down
            sys.stdout.flush()

class PhoneSearch:
    def __init__(self):
        self.proxies = requests.get(
            "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=10000&country=all&ssl=all&anonymity=all"
        ).text.strip().split('\n')
        self.scraper = cloudscraper.CloudScraper()

    def _clean_text(self, element, prefix='') -> Optional[str]:
        if not element:
            return None
        text = element.text.replace(prefix, '').strip()
        return text.replace('\\', '').replace('\n', '').replace('\r', '') if text else None

    def search_by_phone(self, phone_number: str) -> Dict[str, Any]:
        url = f"https://thatsthem.com/phone/{phone_number}"
        
        for i, proxy in enumerate(self.proxies, 1):
            try:
                print(f"\033[{self.details_line + i};0H\033[KTrying proxy {i}/{len(self.proxies)}: {proxy}")
                response = self.scraper.get(url, proxies={"http": proxy}, timeout=10)
                print(f"\033[{self.details_line + i + 1};0H\033[KStatus code: {response.status_code}")
                
                if "Found 0 results" in response.text:
                    return {}
                if "Limit Reached" in response.text:
                    print(f"\033[{self.details_line + i + 2};0H\033[KRate limit reached, trying next proxy")
                    continue
                
                print(f"\033[{self.details_line + i + 2};0H\033[KSuccessfully got response, extracting data")
                return self._extract_phone_records(response.text)
            except Exception as e:
                print(f"\033[{self.details_line + i + 2};0H\033[KError with proxy: {str(e)}")
                continue
        
        print(f"\033[{self.details_line};0H\033[KAll proxies failed")
        return {}

    def _extract_phone_records(self, html_source):
        soup = BeautifulSoup(html_source, 'html.parser')
        records = []
        
        for record_div in soup.find_all('div', class_='record'):
            record = {
                'name': self._clean_text(record_div.find('div', class_='name')),
                'lives_in': self._clean_text(record_div.find('div', class_='resides'), prefix='Lives in'),
            }
            
            if age_element := record_div.find('div', class_='age'):
                age_text = self._clean_text(age_element)
                if birth_match := re.search(r'Born on (.+?) \(', age_text):
                    record['birthday'] = birth_match.group(1)
                if age_match := re.search(r'\((\d+) years old\)', age_text):
                    record['age'] = age_match.group(1)
            
            # Add the record if it has any information
            if any(record.values()):
                records.append(record)
        
        return {'records': records}

def format_spiderfoot_for_obsidian(results: List[Dict[str, Any]], target: str) -> str:
    findings = {
        'Social Media': set(),
        'Coding': set(),
        'Professional': set(),
        'Other': set()
    }
    
    # Create variations of target to filter out
    target_variations = {target}
    if '@' in target:
        username = target.split('@')[0]
        target_variations.add(username)
    if ' ' in target:  # Full name
        target_variations.add(target.replace(' ', ''))
    
    for result in results:
        if 'data' not in result:
            continue
            
        data = result.get('data', '').replace('<SFURL>', '').replace('</SFURL>', '').strip()
        module = result.get('module', '').lower()
        
        # Skip empty, URL-only results, or any variation of the target
        if not data or data.startswith('http') or any(variation.lower() in data.lower() for variation in target_variations):
            continue
            
        # Categorize findings
        if any(x in module for x in ['github', 'gitlab', 'bitbucket']):
            if not any(data in x for x in findings['Coding']):
                findings['Coding'].add(f"GitHub: {data}")
        elif any(x in module for x in ['linkedin', 'hunter', 'companies']):
            findings['Professional'].add(data)
        elif any(x in module for x in ['facebook', 'twitter', 'instagram']):
            findings['Social Media'].add(data)
        else:
            findings['Other'].add(data)
    
    # Format findings
    formatted = []
    for category, items in findings.items():
        if items:
            formatted.append(f"### {category}")
            for item in sorted(items):
                formatted.append(f"- {item}")
            formatted.append("")
    
    return '\n'.join(formatted)

def save_to_obsidian(query_type: str, query: str, results: Dict[str, Any], target: str) -> str:
    folder_path = os.path.join(VAULT_FOLDER, f"{query_type}_{query}")
    os.makedirs(folder_path, exist_ok=True)
    
    with open(os.path.join(folder_path, "overview.md"), "w") as f:
        f.write(f"# <span class=\"custom-title\">OSINT Results: {query}</span>\n---\n\n> [!multi-column]\n>\n")
        
        if query_type == "phone":
            if records := results.get("records"):
                f.write(">> [!note]+ Personal Information\n")
                for record in records:
                    # Keep original field names but format them nicely
                    for field, value in record.items():
                        if value:
                            field_name = field.replace('_', ' ').title()
                            if field == 'lives_in':
                                field_name = 'Lives In'
                            f.write(f">> {field_name}: {value}\n")
                    f.write(">>\n")  # Add spacing between records
        else:
            f.write(">> [!note]+ Spiderfoot Findings\n")
            if isinstance(results, list):
                formatted_lines = [f">> {line}" for line in format_spiderfoot_for_obsidian(results, target).split('\n')]
                f.write('\n'.join(formatted_lines) + '\n')
            f.write(">\n")
    
    return folder_path

def run_osint(target: str):
    task_tracker = TaskTracker(target)
    os.system('clear')
    sys.stdout.write("\033[?25l")  # Hide cursor
    print(f"{COLORS['BLUE']}secＯ•Ｓ -- OSINT\n----------------------\n")
    task_tracker.start()
    
    try:
        if '-' in target:
            searcher = PhoneSearch()
            print(f"\033[{task_tracker.details_line};0H{COLORS['BLUE']}Initialized with {len(searcher.proxies)} proxies")
            print(f"\033[{task_tracker.details_line + 1};0H{COLORS['BLUE']}Attempting to fetch: https://thatsthem.com/phone/{target}")
            results = searcher.search_by_phone(target)
            task_tracker.complete()
            
            if not results or not results.get('records'):
                print(f"\033[{task_tracker.details_line + 2};0H{COLORS['YELLOW']}Results are empty - follow the link to manually solve captcha if necessary{COLORS['NC']}")
            print(f"\033[{task_tracker.details_line + 3};0H" + json.dumps(results, indent=2))
        else:
            # Run Spiderfoot silently
            command = f"spiderfoot -s {shlex.quote(target)} -o json > {SF_OUTPUT_FILE} 2>/dev/null"
            subprocess.Popen(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            start_time = time.time()
            results, shown_findings = [], set()
            detail_line = task_tracker.details_line
            
            while True:
                if os.path.exists(SF_OUTPUT_FILE):
                    try:
                        with open(SF_OUTPUT_FILE, 'r') as f:
                            current_results = json.load(f)
                            
                            for result in current_results[len(results):]:
                                if 'data' not in result or result['data'] in shown_findings:
                                    continue
                                    
                                data = result['data'].replace('<SFURL>', '').replace('</SFURL>', '').strip()
                                module = result.get('module', '').lower()
                                
                                # Skip URLs, empty data, and the target itself
                                if not data or data.startswith('http') or data == target:
                                    continue
                                
                                # Format output based on type
                                display_text = data
                                if any(x in module for x in ['github', 'gitlab', 'bitbucket']):
                                    if not data.startswith('GitHub:'):
                                        display_text = f"GitHub: {data}"
                                
                                print(f"\033[{detail_line};0H\033[K{COLORS['BLUE']}• {display_text}{COLORS['NC']}")
                                shown_findings.add(result['data'])
                                detail_line += 1
                            
                            results = current_results
                    except json.JSONDecodeError:
                        pass
                
                if not subprocess.run("ps aux | grep spiderfoot | grep -v grep", shell=True, capture_output=True).returncode == 0:
                    if results or (time.time() - start_time) > 30:
                        break
                time.sleep(1)

        task_tracker.complete()
        folder_path = save_to_obsidian("phone" if '-' in target else "spiderfoot", target, results)
        print(f"\n{COLORS['GREEN']}Results saved to {folder_path}{COLORS['NC']}")
        
    except KeyboardInterrupt:
        print(f"\n{COLORS['YELLOW']}Search interrupted by user. Cleaning up...{COLORS['NC']}")
    except Exception as e:
        print(f"\n{COLORS['RED']}Error: {str(e)}{COLORS['NC']}")
    finally:
        sys.stdout.write("\033[?25h")  # Show cursor
        if os.path.exists(SF_OUTPUT_FILE):
            try:
                os.remove(SF_OUTPUT_FILE)
            except Exception as e:
                print(f"{COLORS['YELLOW']}Warning: Could not remove temporary file: {str(e)}{COLORS['NC']}")
        print(f"\n{COLORS['GREEN']}Search completed.{COLORS['NC']}")

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help', '-help']:
        print(f"""
{COLORS['BLUE']}secＯ•Ｓ -- OSINT Tool{COLORS['NC']}
A tool for gathering OSINT data using Spiderfoot and phone number lookups.

{COLORS['BLUE']}Target Types:{COLORS['NC']}
  - Username/Email/Full Name: Will use Spiderfoot
  - Phone Number: Must use format 123-456-7890 (dashes required) Will use thatsthem.com custom API

{COLORS['BLUE']}Examples:{COLORS['NC']}
  python osint.py John Smith         # Full name lookup using Spiderfoot (no quotes needed)
  python osint.py johndoe           # Username lookup using Spiderfoot
  python osint.py user@example.com   # Email lookup using Spiderfoot
  python osint.py 123-456-7890      # Phone number lookup using thatsthem.com
""")
        sys.exit(1)
    
    run_osint(' '.join(sys.argv[1:]))