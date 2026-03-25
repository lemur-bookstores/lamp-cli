# LAMP Stack CLI Installer
### Ubuntu 22.04 LTS — AWS Lightsail

Modular LAMP installer with phase selection, named parameters, and interactive prompts for missing values.

---

## Project Structure

```
lamp-cli/
├── init.sh               ← Main orchestrator (entry point)
├── lib/
│   └── common.sh            ← Shared utilities (colors, logging, ask_param)
└── phases/
    ├── 01_preflight.sh      ← Pre-flight checks (OS, RAM, DNS, ports)
    ├── 02_system_prep.sh    ← Swap + apt update/upgrade
    ├── 03_lamp_install.sh   ← Apache, PHP, MariaDB, Certbot, VSFTPD
    ├── 04_vhost.sh          ← Apache Virtual Host configuration
    ├── 05_database.sh       ← MariaDB hardening + database & user setup
    ├── 06_ssl.sh            ← Let's Encrypt certificate (Certbot)
    ├── 07_php_tuning.sh     ← PHP php.ini optimization
    ├── 08_mariadb_tuning.sh ← InnoDB & performance tuning
    └── 09_file_transfer.sh  ← FTPS (VSFTPD) or SFTP (SSH subsystem)
```

---

## Prerequisites

| Requirement        | Details                                                  |
|--------------------|----------------------------------------------------------|
| OS                 | Ubuntu 22.04 LTS                                         |
| Privileges         | `sudo` — most phases require root permissions            |
| DNS (Phase 6)      | A records must point to this server before SSL          |
| Let's Encrypt (Phase 9 FTPS) | Phase 6 must complete before Phase 9 with `ftps` |

```bash
# Grant execute permissions (run once on the server)
chmod +x init.sh phases/*.sh
```

---

## Parameters Quick Reference

| Parameter          | Variable             | Default  | Description                              |
|--------------------|----------------------|----------|------------------------------------------|
| `--domain`         | `DOMAIN`             | —        | Primary domain, no www                   |
| `--admin-email`    | `ADMIN_EMAIL`        | —        | Email for SSL expiry alerts              |
| `--db-name`        | `DB_NAME`            | —        | Database name                            |
| `--db-user`        | `DB_USER`            | —        | Database username                        |
| `--db-pass`        | `DB_PASS`            | —        | Database password (hidden prompt)        |
| `--php-version`    | `PHP_VERSION`        | `8.2`    | PHP version to install                   |
| `--php-handler`    | `PHP_HANDLER`        | `fpm`    | PHP handler: `fpm` or `mod`              |
| `--vhost-root`     | `VHOST_ROOT`         | `/var/www/vhosts/DOMAIN` | Absolute DocumentRoot |
| `--swap-size`      | `SWAP_SIZE`          | `4G`     | Swap file size                           |
| `--ftp-mode`       | `FTP_MODE`           | `ftps`   | Transfer mode: `ftps` or `sftp`          |
| `--ftp-user`       | `FTP_USER`           | —        | FTP/SFTP username                        |
| `--ftp-pass`       | `FTP_PASS`           | —        | FTP/SFTP password (hidden prompt)        |
| `--mariadb-ratio`  | `MARIADB_BUFFER_RATIO` | `60`   | InnoDB buffer % of RAM (50–70)          |
| `--phases`         | —                    | (menu)   | Phases to run, e.g. `1,2,3` or `all`   |

> Any omitted parameter triggers an **interactive prompt**. Password parameters always use hidden input with confirmation.

---

## Use Cases

---

### Case 1 — Full Installation (Interactive Mode)

The installer shows a phase menu and prompts for each missing value.

```bash
sudo ./init.sh
```

**Example session flow:**

```
══════════════════════════════════════════════
  Select which phases to run:

  [1] Pre-Flight Checks
  [2] System Preparation (swap, apt)
  [3] LAMP Stack Installation
  [4] Virtual Host Configuration
  [5] Database Security & Setup
  [6] SSL Certificate (Let's Encrypt)
  [7] PHP Performance Tuning
  [8] MariaDB Performance Tuning
  [9] File Transfer Service (FTP/SFTP)
  [a] Run ALL phases (1–9)
  [q] Quit

Enter phases (comma-separated, e.g. 1,2,3 or a): a

  Primary domain (no www): training.example.com
  Admin email (for cert expiry alerts): admin@example.com
  Database name: moodle_db
  Database username: moodleuser
  Database password: ████████
  Confirm Database password: ████████
  ...
```

---

### Case 2 — Full Installation with All Parameters in Command Line

Ideal for **automated provisioning scripts** (CI/CD, Lightsail user-data).

```bash
sudo ./init.sh \
  --domain        training.example.com \
  --admin-email   admin@example.com \
  --db-name       moodle_db \
  --db-user       moodleuser \
  --db-pass       "S3cur3P@ssw0rd!" \
  --php-version   8.2 \
  --php-handler   fpm \
  --swap-size     4G \
  --ftp-mode      ftps \
  --ftp-user      ftpuser \
  --ftp-pass      "Ftp$ecure2024!" \
  --mariadb-ratio 60 \
  --phases        all
```

---

### Case 3 — Pre-Flight Checks Only (Server Diagnostics)

Useful to confirm the server, DNS, and ports are ready **before** installing anything.

```bash
sudo ./init.sh --domain training.example.com --phases 1
```

Or run directly as a standalone script:

```bash
sudo ./phases/01_preflight.sh --domain training.example.com
```

**What it checks:**
- OS version and current user
- Total RAM and disk space
- Public IP vs. DNS domain resolution
- Ports 80, 443, 21, 22 in use

---

### Case 4 — System Preparation (Swap + Updates)

For small servers (≤ 1 GB RAM) where `apt upgrade` can get OOM-killed.

```bash
# 2 GB swap on nano instance
sudo ./init.sh --swap-size 2G --phases 2

# 4 GB swap on medium instance (recommended for Moodle)
sudo ./init.sh --swap-size 4G --phases 2
```

Or standalone:

```bash
sudo ./phases/02_system_prep.sh --swap-size 4G
```

---

### Case 5 — Install LAMP Stack Only (No Additional Configuration)

```bash
# PHP 8.2 (default)
sudo ./init.sh --phases 3

# PHP 8.3
sudo ./init.sh --php-version 8.3 --phases 3
```

Or standalone:

```bash
sudo ./phases/03_lamp_install.sh --php-version 8.1
```

**Packages installed:** Apache 2, MariaDB, PHP + extensions (fpm/mod_php, cli, mysql, zip, ldap, xml, gd, curl, tidy, mbstring, intl, soap, imagick), Certbot, VSFTPD.

---

### Case 6 — Configure a Virtual Host for a Domain

```bash
sudo ./init.sh \
  --domain      training.example.com \
  --php-version 8.2 \
  --php-handler fpm \
  --phases      4
```

Or standalone:

```bash
sudo ./phases/04_vhost.sh \
  --domain      training.example.com \
  --php-version 8.2 \
  --php-handler fpm
```

**Result:**
```
/var/www/vhosts/training.example.com/
├── httpdocs/        ← DocumentRoot (owner: www-data)
└── logs/
    ├── access.log
    └── error.log
```

Apache config generated at:
`/etc/apache2/sites-available/training.example.com.conf`

---

### Case 7 — Install Stack + Virtual Host + Database (No SSL Yet)

Typical workflow for staging where DNS doesn't point to the server yet.

```bash
sudo ./init.sh \
  --domain      staging.example.com \
  --php-version 8.2 \
  --php-handler fpm \
  --db-name     moodle_db \
  --db-user     moodleuser \
  --db-pass     "S3cur3P@ss!" \
  --phases      3,4,5
```

---

### Case 8 — Issue SSL Certificate (Once DNS Is Ready)

```bash
sudo ./init.sh \
  --domain      training.example.com \
  --admin-email admin@example.com \
  --phases      6
```

Or standalone:

```bash
sudo ./phases/06_ssl.sh \
  --domain      training.example.com \
  --admin-email admin@example.com
```

> The script automatically verifies that DNS resolves to the server's IP before calling Certbot. If it doesn't match, it **aborts** with a clear error message instead of consuming your Let's Encrypt rate limit.

**Auto-renewal:** cron every 12 hours — configured automatically.

---

### Case 9 — Optimize PHP for Moodle / LMS

With recommended defaults:

```bash
sudo ./init.sh --php-version 8.2 --phases 7
```

With custom values:

```bash
sudo ./phases/07_php_tuning.sh
# Prompts:
#   PHP version: 8.2
#   max_input_vars  [5000]: 6000
#   max_execution_time [250]: 300
#   post_max_size [50M]: 100M
#   upload_max_filesize [50M]: 100M
#   max_input_time [250]: 300
```

| Directive            | Default Value | Moodle Recommended |
|----------------------|----------------|--------------------|
| `max_input_vars`     | 5000           | 5000+              |
| `max_execution_time` | 250s           | 160s+              |
| `post_max_size`      | 50M            | 50M+               |
| `upload_max_filesize`| 50M            | 50M+               |
| `max_input_time`     | 250s           | 120s+              |

---

### Case 10 — Tune MariaDB Based on Server RAM

The script automatically calculates `innodb_buffer_pool_size` from actual server RAM.

```bash
# 60% of RAM (recommended for dedicated database server)
sudo ./init.sh --mariadb-ratio 60 --phases 8

# 50% (recommended if Apache/PHP run on same server)
sudo ./init.sh --mariadb-ratio 50 --phases 8
```

**Example calculation on 2 GB RAM instance:**

| Variable                   | Calculation       | Result |
|----------------------------|-------------------|--------|
| `RAM_TOTAL_MB`             | `free -m`         | 2048 MB   |
| `MARIADB_BUFFER_RATIO`     | user config       | 60%       |
| `innodb_buffer_pool_size`  | 2048 × 60 / 100   | **1228 MB** |

---

### Case 11 — File Transfer: FTPS (VSFTPD + TLS)

Requires Phase 6 (SSL) to complete first. Uses the Let's Encrypt certificate.

```bash
sudo ./init.sh \
  --domain   training.example.com \
  --ftp-mode ftps \
  --ftp-user ftpuser \
  --ftp-pass "Ftp$ecure!" \
  --phases   9
```

**Connection:** Port 21, Explicit TLS (FileZilla, WinSCP).  
**Passive ports:** 49152–65535 TCP (must open in Lightsail firewall).

---

### Case 12 — File Transfer: SFTP (SSH Subsystem)

More secure — no extra service or TLS certificate needed. Uses existing port 22.

```bash
sudo ./init.sh \
  --domain   training.example.com \
  --ftp-mode sftp \
  --ftp-user sftpuser \
  --ftp-pass "Sftp$ecure!" \
  --phases   9
```

**Connection:** Port 22, SFTP protocol (FileZilla, WinSCP, Cyberduck).  
User is **chrooted** to `/var/www/vhosts/<domain>`.

---

### Case 13 — Reconfigure a Single Phase Without Touching Others

Example: SSL certificate expired or error, re-issue it:

```bash
sudo ./phases/06_ssl.sh \
  --domain      training.example.com \
  --admin-email admin@example.com
```

Example: change database password:

```bash
sudo ./phases/05_database.sh \
  --db-name moodle_db \
  --db-user moodleuser \
  --db-pass "NewPassword2025!"
```

---

### Case 14 — Low-Memory Server (512 MB / 1 GB)

Conservative configuration for nano or micro Lightsail instances.

```bash
sudo ./init.sh \
  --swap-size     4G \
  --php-version   8.2 \
  --php-handler   fpm \
  --mariadb-ratio 50 \
  --phases        2,3,4,5,6,7,8
```

> Swap is configured in phase 2, **before** apt upgrade, to prevent OOM kills.

---

### Case 15 — Multiple Domains on One Server

Run phase 4 multiple times, once per domain:

```bash
# First domain
sudo ./phases/04_vhost.sh --domain site-a.com --php-version 8.2

# Second domain
sudo ./phases/04_vhost.sh --domain site-b.com --php-version 8.2

# SSL for each domain
sudo ./phases/06_ssl.sh --domain site-a.com --admin-email admin@site-a.com
sudo ./phases/06_ssl.sh --domain site-b.com --admin-email admin@site-b.com
```

Each vhost has its own directory:
```
/var/www/vhosts/
├── site-a.com/httpdocs/
└── site-b.com/httpdocs/
```

---

### Case 16 — Using mod_php Instead of PHP-FPM

For simpler setups or development environments, use Apache's built-in mod_php:

```bash
sudo ./init.sh \
  --domain      dev.example.com \
  --php-version 8.2 \
  --php-handler mod \
  --phases      3,4,7
```

**Differences with mod_php:**
- Single PHP version per server (no multi-version support)
- PHP runs inside Apache process (no separate service)
- Simpler but less flexible than FPM
- Better for development/testing, not recommended for production

---

### Case 17 — Custom DocumentRoot Path

Host applications outside the standard `/var/www/vhosts` location:

```bash
sudo ./init.sh \
  --domain      myapp.example.com \
  --vhost-root  /srv/apps/myapp \
  --php-version 8.2 \
  --php-handler fpm \
  --phases      4
```

**Result:**
```
/srv/apps/myapp/
├── httpdocs/        ← Apache DocumentRoot
└── logs/
```

---

## JSON Confirmation Output

Each phase outputs a JSON block on completion, useful for automated pipelines or audit trails:

```json
{
  "phase": "4_vhost",
  "status": "success",
  "site": {
    "domain": "training.example.com",
    "root_path": "/var/www/vhosts/training.example.com/httpdocs",
    "php_version": "8.2",
    "php_handler": "fpm",
    "config_path": "/etc/apache2/sites-available/training.example.com.conf",
    "config_syntax_test": "Syntax OK",
    "apache_status": "active",
    "http_check": "200"
  }
}
```

> Passwords never appear in JSON output — shown as `"(hidden)"`.

---

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Phase 6 fails: DNS mismatch | DNS doesn't point to server | Update A record and wait for propagation |
| Phase 9 FTPS fails: cert not found | Phase 6 didn't complete | Run `./phases/06_ssl.sh` first |
| Changes to `php.ini` not reflected | FPM/Apache not restarted | `sudo systemctl restart php8.2-fpm` and `sudo systemctl restart apache2` |
| MariaDB won't start after Phase 8 | `innodb_log_file_size` incompatible | Check `/var/log/mysql/error.log` |
| FTP connection refused (passive mode) | Passive port range closed | Open 49152–65535 TCP in Lightsail firewall |
| `ask_param` doesn't prompt for value | Variable already exported in shell | `unset VARIABLE` and re-run |
