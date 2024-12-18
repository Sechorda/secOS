## Overview

secOS Tools provides three main components:
- **Recon**: Automated reconnaissance scanning of domains
- **OSINT**: Open-source intelligence gathering
- **Infra**: AWS infrastructure management

## Build secOS -- Bash script

Build secOS yourself with the buildeb.sh bash script

- Tested on debian12
- Download prebuilt .ISO/.OVA at https://sec-os.com

![buildeb](buildeb.png)

## Tools

### Recon

Performs comprehensive domain reconnaissance including:
- Subdomain enumeration
- WAF detection  
- DNS analysis
- Directory fuzzing
- Cloud asset discovery
- API parameter discovery
- CORS misconfiguration checks

```bash
# Basic scan (1-3 hours)
recon example.com

# Full scan with comprehensive wordlists (8+ hours)
recon -full example.com

# Use AWS/Fireprox for proxy
recon -aws example.com

# Full scan through AWS proxy
recon -full -aws example.com
```

### OSINT

Gathers intelligence using Spiderfoot and custom APIs.

```bash
# Search by username/email (uses Spiderfoot)
osint johndoe
osint user@example.com

# Search by full name (uses Spiderfoot)
osint John Smith

# Search by phone number (format: XXX-XXX-XXXX)
osint 123-456-7890
```

### Infra

Manage AWS infrastructure including EC2 instances and DNS records.

```bash
# Launch interactive infrastructure management
infra
```