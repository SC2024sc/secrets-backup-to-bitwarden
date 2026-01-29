# Quick Start Guide

## 5-Minute Setup to Backup .env Files to Bitwarden

### 1️⃣ Install Prerequisites

```bash
# Install Bitwarden CLI
npm install -g @bitwarden/cli

# Linux/macOS only: Install jq
# Ubuntu/Debian:
sudo apt-get install jq
# macOS:
brew install jq
# CentOS/RHEL:
sudo yum install jq
```

### 2️⃣ Login to Bitwarden

```bash
# Initial login
bw login

# Unlock vault and copy session key
bw unlock
# Copy the output: export BW_SESSION="xxxxxxxxx"
```

### 3️⃣ Set Session Variable

```bash
# Linux/macOS:
export BW_SESSION="your-session-key-here"

# Windows PowerShell:
$env:BW_SESSION = "your-session-key-here"
```

### 4️⃣ Run the Script

```bash
# Linux/macOS:
chmod +x backup-env.sh
./backup-env.sh

# Windows PowerShell:
.\Backup-Env.ps1
```

### 5️⃣ Verify in Bitwarden

1. Open Bitwarden web vault or app
2. Look for items named after your .env files
3. Verify the content matches your local files

## Common Commands

### Backup with Custom Prefix

```bash
# Linux/macOS:
./backup-env.sh /path/to/project "My Project"

# Windows:
.\Backup-Env.ps1 -Directory "C:\Projects\MyApp" -Prefix "My Project"
```

### Verbose Output

```bash
# Linux/macOS:
./backup-env.sh --verbose

# Windows:
.\Backup-Env.ps1 -Verbose
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Vault is locked" | Run `bw unlock` and set BW_SESSION again |
| "Scripts are disabled" (Windows) | Run `Set-ExecutionPolicy RemoteSigned` as Admin |
| "Command not found: bw" | Install Bitwarden CLI: `npm install -g @bitwarden/cli` |
| "Command not found: jq" (Linux/macOS) | Install jq using your package manager |

## Pro Tips

- **Session expires** after 15 minutes - unlock again if needed
- **Use in CI/CD** with API keys instead of user login
- **Check duplicates** - script updates existing items automatically
- **Test first** - run on non-sensitive files to verify

## Need More Help?

- Check the full [README.md](README.md) for detailed documentation
- Review [COMMUNITY_GUIDELINES.md](COMMUNITY_GUIDELINES.md) for contributing
- Open an issue for bugs or feature requests
