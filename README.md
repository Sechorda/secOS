<div align="center">
  <a>
    <img
      alt="secOS Logo"
      width="125"
      src="./images/transparent_logo.png"
    />
  </a>
  <h1><strong>secOS</strong></h1>
  <p>
    <strong>A Linux distro that focuses on BugBounty and penetration testing tools</strong>
  </p>
  <p>
    <a href="https://github.com/YourUsername/secOS/blob/main/LICENSE">
      <img alt="License" src="https://img.shields.io/github/license/YourUsername/secOS.svg">
    </a>
  </p>
</div>

---
# RECON

### This OS includes a `recon.py` that chains together popular and commonly used discovery tools for Recon:
- [Knockpy](https://github.com/guelfoweb/knock)
- [Amass](https://github.com/owasp-amass/amass)
- [Gospider](https://github.com/jaeles-project/gospider)
- [DNSReaper](https://github.com/punk-security/dnsreaper)
- [Wafw00f](https://github.com/EnableSecurity/wafw00f)
- [CloudBrute](https://github.com/0xsha/CloudBrute)
- [FFUF](https://github.com/ffuf/ffuf)
- [Arjun](https://github.com/s0md3v/Arjun)
- [Corsy](https://github.com/s0md3v/Corsy)
- [JSluice](https://github.com/BishopFox/jsluice)

(`-aws` option allows for proxying brute-force requests through AWS gateway proxy for psuedo-infinite IPs)

(see https://aws.amazon.com/security/penetration-testing/ to understand AWS TOS policy)

# INFRASTRUCTURE

### This OS includes `infra.py` - a python script for managing cloud instances and their DNS records for quick infrastructure

(Supports: AWS EC2, AWS Route53)
(Coming soon: Cloudflare DNS)

- List EC2 instances
- Start/Stop EC2 instances
- Update DNS records pointing to new instances
- (Coming soon: secos-serv.iso/.ova/.ami - A server/C2 variant with server side tools and scripts to host using infra.py)
