# WSL2 Ultimate Port Proxy Manager

> A professional CLI tool to manage Windows ↔ WSL2 port forwarding — auto-detects your WSL2 IP, configures `netsh` proxies, and manages firewall rules, all from a single command inside your WSL2 terminal.

---

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Options Reference](#options-reference)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Overview

WSL2 runs inside a lightweight virtual machine with its **own isolated network interface** — meaning it receives a new internal IP address every time it starts. This makes it impossible to reliably access services running in WSL2 (Apache, Nginx, Node.js, etc.) from the Windows host without reconfiguring port forwarding each restart.

`tools/wsl2-portproxy.sh` automates the full lifecycle: it detects your current WSL2 IP, creates the Windows port proxy, and adds the necessary firewall rule — all with a single command that requests UAC elevation automatically.

### What the script handles for you

| Task | Manual Way | With this script |
|---|---|---|
| Detect WSL2 IP | `hostname -I` then copy IP | ✅ Automatic |
| Add port proxy | `netsh interface portproxy add ...` | ✅ Automatic |
| Add firewall rule | `netsh advfirewall firewall add ...` | ✅ Automatic |
| Request admin rights | Open elevated PowerShell manually | ✅ UAC popup triggered |
| List active proxies | `netsh interface portproxy show v4tov4` | ✅ `./tools/wsl2-portproxy.sh -l` |
| Remove a proxy | Two separate `netsh delete` commands | ✅ `./tools/wsl2-portproxy.sh -d` |

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Windows Host                                                   │
│                                                                 │
│  Browser → http://myapp.test:80                                 │
│                    │                                            │
│                    ▼                                            │
│       netsh portproxy (0.0.0.0:80)                              │
│                    │                                            │
│                    ▼                                            │
│         vEthernet (WSL) adapter                                 │
│                    │                                            │
└────────────────────┼────────────────────────────────────────────┘
                     │  forwards to WSL2_IP:80
┌────────────────────┼────────────────────────────────────────────┐
│  WSL2 VM           │                                            │
│                    ▼                                            │
│         Apache / Nginx / Node.js                                │
│         listening on 0.0.0.0:80                                 │
└─────────────────────────────────────────────────────────────────┘
```

1. The script reads the WSL2 IP via `hostname -I`.
2. It calls `powershell.exe` from inside WSL2 using `Start-Process ... -Verb RunAs` to trigger a UAC elevation popup.
3. Inside that elevated session, two `netsh` commands run:
   - **Port proxy**: routes `Windows 0.0.0.0:PORT` → `WSL2_IP:PORT`
   - **Firewall rule**: allows inbound TCP on that port
4. Your browser on Windows can now reach `http://localhost`, `http://127.0.0.1`, or any custom `.test` domain pointed to `127.0.0.1` in your hosts file.

> **Why re-run after restart?**
> WSL2's virtual network is destroyed and recreated on every `wsl --shutdown` or system restart, assigning a new internal IP. The old proxy entry still points to a dead IP — re-running the script updates it automatically.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **OS** | Windows 10 (21H1+) or Windows 11 |
| **WSL version** | WSL2 (not WSL1) |
| **Shell** | Bash inside WSL2 |
| **Permissions** | Script must be able to invoke `powershell.exe` (standard in most WSL2 setups) |
| **Windows UAC** | A UAC prompt will appear — you must confirm it to apply changes |

---

## Usage

### Basic syntax

```bash
./tools/wsl2-portproxy.sh [options]
```

### Forward the default port (80)

```bash
./tools/wsl2-portproxy.sh
```

Detects your WSL2 IP and forwards Windows port `80` → WSL2 port `80`. A UAC popup will appear in Windows — click **Yes** to apply.

**Expected output:**

```
[i] Mapping Windows:80 ➔ WSL2:172.22.47.13:80
[!] Requesting Admin privileges...
============================================================
[✓] Success! Port 80 is now exposed.
[i] Note: Check the Windows UAC popup to confirm.
============================================================
```

### Forward a custom port

```bash
./tools/wsl2-portproxy.sh -p 3000
```

### List all active port proxies

```bash
./tools/wsl2-portproxy.sh -l
```

Queries Windows via PowerShell and prints the current `netsh portproxy` table:

```
[i] Fetching active Port Proxies from Windows...
------------------------------------------------------------
Listen on ipv4:             Connect to ipv4:
Address         Port        Address         Port
--------------- ----------  --------------- ----------
0.0.0.0         80          172.22.47.13    80
0.0.0.0         3000        172.22.47.13    3000
------------------------------------------------------------
```

### Remove a port proxy

```bash
./tools/wsl2-portproxy.sh -p 80 -d
```

Deletes both the port proxy entry **and** the associated firewall rule for port `80`. UAC popup will appear.

---

## Options Reference

| Option | Description | Default |
|---|---|---|
| `-p <port>` | Port to forward | `80` |
| `-l` | List all active port proxies on Windows | — |
| `-d` | Delete the proxy and firewall rule for the specified port | — |
| `-h` | Show help message | — |

### Option combinations

```bash
./tools/wsl2-portproxy.sh              # Forward port 80 (default)
./tools/wsl2-portproxy.sh -p 8080      # Forward port 8080
./tools/wsl2-portproxy.sh -l           # List all active proxies
./tools/wsl2-portproxy.sh -p 3000 -d   # Remove proxy for port 3000
./tools/wsl2-portproxy.sh -h           # Show help
```

---

## Use Cases

### 🌐 Case 1 — Local `.test` domain with Apache or Nginx

You're running Apache inside WSL2 with a virtual host configured for `myapp.test` on port 80. You want to open `http://myapp.test` in your Windows browser.

```bash
# 1. Forward port 80 from Windows to WSL2
./tools/wsl2-portproxy.sh -p 80

# 2. On Windows, edit the hosts file as Administrator:
#    C:\Windows\System32\drivers\etc\hosts
#    Add this line:
#    127.0.0.1   myapp.test

# 3. Open http://myapp.test in your Windows browser ✅
```

---

### ⚡ Case 2 — Node.js / Vite dev server

Your frontend dev server runs on port `5173`. You want live hot-reload accessible from your Windows browser.

```bash
# Inside WSL2 — start your dev server bound to all interfaces
npm run dev -- --host 0.0.0.0

# Forward the port to Windows
./tools/wsl2-portproxy.sh -p 5173

# Open in Windows browser
# http://localhost:5173 ✅
```

---

### 🐳 Case 3 — Docker container inside WSL2

A Docker container running inside WSL2 exposes port `8080`.

```bash
# Start the container
docker run -p 8080:80 nginx

# Forward to Windows
./tools/wsl2-portproxy.sh -p 8080

# Access from Windows browser
# http://localhost:8080 ✅
```

---

### 🔄 Case 4 — WSL2 restarted, IP changed

After running `wsl --shutdown` and reopening WSL2, your old proxy points to a dead IP.

```bash
# Simply re-run — the script detects the new IP and updates the proxy
./tools/wsl2-portproxy.sh -p 80
# ✅ Old entry is replaced with the current WSL2 IP automatically
```

---

### 🔐 Case 5 — HTTPS on port 443

You have a self-signed certificate set up in Nginx for local HTTPS testing.

```bash
# Forward port 443 to WSL2
./tools/wsl2-portproxy.sh -p 443

# Access from Windows browser
# https://myapp.test ✅ (accept the self-signed cert warning)
```

---

### 🧹 Case 6 — Clean up before a handoff or project close

You're done with a project and want to remove all forwarding rules you created.

```bash
# Check what's active
./tools/wsl2-portproxy.sh -l

# Remove each port
./tools/wsl2-portproxy.sh -p 80 -d
./tools/wsl2-portproxy.sh -p 3000 -d
./tools/wsl2-portproxy.sh -p 5173 -d

# Verify everything is clean
./tools/wsl2-portproxy.sh -l
```

---

## Troubleshooting

### ❌ UAC popup appears but nothing seems to happen

The elevated PowerShell window may open and close too quickly. Verify the proxy was created by running this in an elevated PowerShell on Windows:

```powershell
netsh interface portproxy show v4tov4
```

If the entry is missing, re-run the script and confirm the UAC prompt.

---

### ❌ `http://localhost` still doesn't work after forwarding

Your server inside WSL2 may be binding only to `127.0.0.1` (loopback) instead of all interfaces.

```bash
# Check what address your server is listening on
sudo netstat -tlnp | grep :80

# If you see 127.0.0.1:80, update your server config to listen on 0.0.0.0

# Apache — edit /etc/apache2/ports.conf
# Change: Listen 127.0.0.1:80
# To:     Listen 0.0.0.0:80
sudo service apache2 restart

# Nginx — check your server block
# listen 80;           ← this binds to all interfaces by default ✅
# listen 127.0.0.1:80; ← this won't work, change it ❌
```

---

### ❌ `Could not detect WSL2 IP` error

```bash
# Verify your IP is available
hostname -I

# If the output is empty, WSL2 networking may not be initialized
# Restart WSL2 and try again:
wsl --shutdown
# Reopen WSL2 terminal and re-run the script
```

---

### ❌ Firewall rule missing after running the script

Confirm whether the rule exists on Windows:

```powershell
# Run in elevated PowerShell on Windows
netsh advfirewall firewall show rule name="WSL2 Port 80"
```

If missing, add it manually:

```powershell
netsh advfirewall firewall add rule name="WSL2 Port 80" dir=in action=allow protocol=TCP localport=80
```

---

### ❌ `powershell.exe` not found inside WSL2

```bash
# Check if Windows executables are accessible
which powershell.exe
# Expected: /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe

# If not found, ensure Windows path interop is enabled in /etc/wsl.conf:
# [interop]
# appendWindowsPath = true

# Then restart WSL2:
wsl --shutdown
```

---

## FAQ

**Q: Do I need to run the script as root inside WSL2?**  
No. The script runs as a normal user. Admin rights on Windows are requested automatically via UAC when the script calls `powershell.exe` with `-Verb RunAs`.

---

**Q: Do proxy entries persist after a Windows reboot?**  
No. `netsh portproxy` entries are not persistent — they are lost on Windows reboot or `wsl --shutdown`. Re-run the script each time you restart WSL2. You can automate this with a Windows Task Scheduler entry or a WSL2 startup script.

---

**Q: Can I forward multiple ports at once?**  
Run the script once per port:

```bash
./tools/wsl2-portproxy.sh -p 80
./tools/wsl2-portproxy.sh -p 443
./tools/wsl2-portproxy.sh -p 3000
```

---

**Q: Does this work with WSL1?**  
No. WSL1 shares the Windows network stack directly, so port forwarding is not needed. This script is designed exclusively for the isolated VM network in WSL2.

---

**Q: What happens if I run the script twice for the same port?**  
The `netsh` command will overwrite the existing proxy entry with the current WSL2 IP. It is safe to re-run — this is the intended behavior after a WSL2 restart.

---

## Author

Built by [@ElkinCp5](https://github.com/ElkinCp5).  
Contributions and issues welcome via GitHub.
