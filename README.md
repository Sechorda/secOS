<div align="center">
  <a>
    <img
      alt="secOS Logo"
      width="125"
      src="https://github.com/Sechorda/secOS/blob/gh-pages/images/transparent_logo.png"
    />
  </a>
  <h1><strong>secOS</strong></h1>
  <p>
    <a href="https://github.com/Sechorda/secOS/blob/gh-pages/LICENSE">
      <img alt="License" src="https://img.shields.io/github/license/Sechorda/secOS">
    </a>
  </p>
</div>
<div align="center">

# Summary
[wiki / docs](https://github.com/Sechorda/secOS/wiki)<br>

secOS is a Debian-based Linux distribution for cybersecurity researchers. It combines essential penetration testing and bug bounty tools into a pre-configured metaframework, emphasizing minimalism and efficiency. The lightweight design enables security practitioners to focus on testing rather than setup and configuration.

---

# Build secOS
### `buildeb.sh`

Build secOS yourself with the buildeb.sh bash script
  <br>
  Tested on debian12
  </br>
  Download prebuilt .ISO/.OVA at https://sec-os.com
  
![buildeb](https://github.com/Sechorda/secOS/blob/gh-pages/images/buildeb.png)

---

# RECON
### `recon.py`
Features:<br>
<br>
**Chains tools** into a pipeline for mapping attack surface<br>
**Presents data** in an easy to review manner within an obsidian vault<br>

[BBOT](https://github.com/blacklanternsecurity/bbot)<br>
[Gospider](https://github.com/jaeles-project/gospider)<br>
[DNSReaper](https://github.com/punk-security/dnsreaper)<br>
[Wafw00f](https://github.com/EnableSecurity/wafw00f)<br>
[CloudBrute](https://github.com/0xsha/CloudBrute)<br>
[FFUF](https://github.com/ffuf/ffuf)<br>
[Arjun](https://github.com/s0md3v/Arjun)<br>
[Corsy](https://github.com/s0md3v/Corsy)<br>
[JSluice](https://github.com/BishopFox/jsluice)

---

# INFRASTRUCTURE
### `infra.py`
Features:<br>
<br>
**Create** EC2 instances<br>
**Update DNS** records pointing to new instances<br>
**List** EC2 instances<br>
**Start/Stop** EC2 instances<br>
<br>

---

# OSINT
### `osint.py`
Features:<br>
<br>
Query targets:<br>
**Username**<br>
**Full Name**<br>
**Email**<br>
**Phone Number**s<br>
<br>


---

# BROWSER/PROXY
### Firefox + Caido
Extensions:<br>
<br>
[domloggerpp](https://addons.mozilla.org/en-US/firefox/addon/domlogger/)<br>
[pwnfox](https://addons.mozilla.org/en-US/firefox/addon/pwnfox/)<br>
[wappalyzer](https://addons.mozilla.org/en-US/firefox/addon/wappalyzer/)

</div>
