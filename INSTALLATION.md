# LAMP Stack CLI — Global Installation Guide

This guide covers multiple methods to download, configure, and make the `lamp-cli` command globally accessible on Linux systems.

---

## Table of Contents

1. [Option 1 — Symlink (Recommended for Production)](#option-1--symlink-recommended-for-production)
2. [Option 2 — Wrapper Script (Advanced Flexibility)](#option-2--wrapper-script-advanced-flexibility)
3. [Option 3 — Automated Installation Script (Recommended for Users)](#option-3--automated-installation-script-recommended-for-users)
4. [Option 4 — Add to PATH (Local Installation)](#option-4--add-to-path-local-installation)
5. [Uninstallation](#uninstallation)
6. [Updating](#updating)

---

## Option 1 — Symlink (Recommended for Production)

Clone the repository to a system directory and create a symbolic link in the PATH.

### Installation

```bash
# 1. Clone repository to /opt
sudo git clone https://github.com/lemur-bookstores/lamp-cli.git /opt/lamp-cli

# 2. Make scripts executable
sudo chmod +x /opt/lamp-cli/init.sh /opt/lamp-cli/phases/*.sh

# 3. Create symlink in /usr/local/bin
sudo ln -s /opt/lamp-cli/init.sh /usr/local/bin/lamp-cli

# 4. Verify installation
lamp-cli --help
```

### Usage

```bash
# Run from anywhere
sudo lamp-cli [OPTIONS]

# Run a specific phase
sudo lamp-cli --phases 1,2,3 --domain example.com

# Interactive mode
sudo lamp-cli
```

### Advantages

✅ Accessible globally as `sudo lamp-cli`
✅ Updates with `git pull` are reflected immediately
✅ No reinstallation needed
✅ Clean system structure (files in `/opt`)

### Disadvantages

❌ Requires manual git updates
❌ Symlink can break if repo is moved

---

## Option 2 — Wrapper Script (Advanced Flexibility)

Create a wrapper script that can execute additional logic before running the CLI.

### Installation

```bash
# 1. Clone repository
sudo git clone https://github.com/lemur-bookstores/lamp-cli.git /opt/lamp-cli

# 2. Make scripts executable
sudo chmod +x /opt/lamp-cli/init.sh /opt/lamp-cli/phases/*.sh

# 3. Create wrapper script
sudo tee /usr/local/bin/lamp-cli > /dev/null <<'EOF'
#!/bin/bash

# Wrapper script for lamp-cli
# Change to the install directory before executing

SCRIPT_DIR="/opt/lamp-cli"
cd "$SCRIPT_DIR" || exit 1

exec "$SCRIPT_DIR/init.sh" "$@"
EOF

# 4. Make wrapper executable
sudo chmod +x /usr/local/bin/lamp-cli

# 5. Verify installation
lamp-cli --help
```

### Advantages

✅ Allows pre-execution logic (validation, auto-update)
✅ Preserves working directory context
✅ Can add custom error handling

### Disadvantages

❌ Extra layer of indirection
❌ Requires manual maintenance

---

## Option 3 — Automated Installation Script (Recommended for Users)

Use the automated installation script included in the repository. This is the simplest method for end users.

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/lemur-bookstores/lamp-cli/main/setup-cli.sh | sudo bash
```

### Manual Installation (if curl unavailable)

```bash
# Download the script
wget https://raw.githubusercontent.com/lemur-bookstores/lamp-cli/main/setup-cli.sh

# Run it with sudo
sudo bash setup-cli.sh
```

### Custom Installation Path (Optional)

By default, the script installs to `/opt/lamp-cli`. To use a different location:

```bash
INSTALL_DIR=/custom/path sudo bash setup-cli.sh
```

### What the Script Does

1. Clones the repository to `/opt/lamp-cli` (or specified path)
2. If already installed, pulls latest updates from git
3. Makes all scripts executable
4. Creates a symlink at `/usr/local/bin/lamp-cli`
5. Displays success message

### Usage After Installation

```bash
# Run installer from anywhere
sudo lamp-cli

# Run with parameters
sudo lamp-cli --domain example.com --php-version 8.2 --phases all

# Run a specific phase
sudo ./phases/04_vhost.sh --domain example.com
```

### Advantages

✅ Single command installation
✅ Can be used in Docker/cloud-init scripts
✅ Handles both fresh install and updates
✅ User-friendly output and error handling
✅ Most convenient for end users

### Disadvantages

❌ Requires curl or wget
❌ Less control over installation directory

---

## Option 4 — Add to PATH (Local Installation)

Install without using system directories. Useful for development or limited permissions.

### Installation

```bash
# 1. Clone to home directory
git clone https://github.com/lemur-bookstores/lamp-cli.git ~/lamp-cli

# 2. Make scripts executable
chmod +x ~/lamp-cli/init.sh ~/lamp-cli/phases/*.sh

# 3. Add to PATH in ~/.bashrc
echo 'export PATH="$HOME/lamp-cli:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Verify installation
lamp-cli --help
```

### Usage

```bash
# Run from anywhere (but still needs sudo)
sudo lamp-cli --domain example.com

# Or run directly
~/lamp-cli/init.sh --domain example.com
```

### Advantages

✅ No system directory modifications
✅ Does not require root for setup
✅ Easy to remove (just delete directory)

### Disadvantages

❌ Breaks if home directory is moved
❌ Only available to one user
❌ Not truly system-wide
❌ Installation persists in home (clutters ~)

---

## Uninstallation

### If using Option 1 (Symlink) or Option 2 (Wrapper) or Option 3 (Automated)

```bash
# Remove symlink
sudo rm /usr/local/bin/lamp-cli

# Remove installation directory
sudo rm -rf /opt/lamp-cli

# Verify removal
which lamp-cli  # Should return "not found"
```

### If using Option 4 (PATH)

```bash
# Remove from PATH (edit ~/.bashrc)
nano ~/.bashrc
# Delete the line: export PATH="$HOME/lamp-cli:$PATH"
# Save and exit

# Remove directory
rm -rf ~/lamp-cli

# Reload shell
source ~/.bashrc
```

---

## Updating

### Option 1, 2, or 3 (System Installation in /opt)

```bash
# Navigate to installation directory
cd /opt/lamp-cli

# Pull latest updates
sudo git pull origin main

# Verify update
lamp-cli --help
```

### Option 4 (Home Directory)

```bash
# Navigate to directory
cd ~/lamp-cli

# Pull latest updates
git pull origin main

# Verify update
lamp-cli --help
```

---

## System Requirements

- **OS:** Ubuntu 22.04 LTS or similar Debian-based systems
- **User:** Must have `sudo` privileges for most operations
- **Tools:** `git` must be installed
  ```bash
  # Install git if not present
  sudo apt update && sudo apt install -y git
  ```

---

## Troubleshooting

### Command not found

```bash
# Check if lamp-cli is in PATH
which lamp-cli

# If nothing returned, verify symlink exists
ls -la /usr/local/bin/lamp-cli

# Verify install directory exists
ls -la /opt/lamp-cli
```

### Permission denied

```bash
# Ensure scripts are executable
sudo chmod +x /opt/lamp-cli/init.sh /opt/lamp-cli/phases/*.sh

# Ensure symlink is correct
sudo ln -sf /opt/lamp-cli/init.sh /usr/local/bin/lamp-cli
```

### Git clone fails (network issues)

```bash
# Try with SSH key if HTTPS fails
sudo git clone git@github.com:lemur-bookstores/lamp-cli.git /opt/lamp-cli

# Or use a proxy if behind corporate firewall
sudo git clone https://github.com/lemur-bookstores/lamp-cli.git /opt/lamp-cli --depth 1
```

### Update fails

```bash
# Check git status
cd /opt/lamp-cli
git status

# If there are local changes, stash them
sudo git stash

# Try pull again
sudo git pull origin main
```

---

## Recommended Installation Method

For **most users**, we recommend **Option 3 (Automated Installation Script)**:

```bash
curl -fsSL https://raw.githubusercontent.com/lemur-bookstores/lamp-cli/main/setup-cli.sh | sudo bash
```

### Why Option 3?

- ✅ Single command
- ✅ Handles fresh installs and updates
- ✅ Idempotent (safe to run multiple times)
- ✅ Clear feedback and error messages
- ✅ Can be used in automated provisioning scripts
- ✅ Works in Docker, cloud-init, and CI/CD pipelines

---

## Quick Start

After installation with any method:

```bash
# Show help
sudo lamp-cli --help

# Interactive setup
sudo lamp-cli

# Full installation with all params
sudo lamp-cli \
  --domain        training.example.com \
  --admin-email   admin@example.com \
  --db-name       moodle_db \
  --db-user       moodleuser \
  --db-pass       "SecurePassword123!" \
  --php-version   8.2 \
  --php-handler   fpm \
  --swap-size     4G \
  --mariadb-ratio 60 \
  --phases        all
```

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/lemur-bookstores/lamp-cli/issues
- Documentation: See [README.md](README.md)
- Phase Documentation: See individual phase files in `phases/`
