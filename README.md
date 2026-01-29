# .env Files to Bitwarden Automation

A cross-platform automation tool that recursively finds all `.env` files (including `.env.development`, `.env.production`, etc.) in a directory and securely backs them up to Bitwarden as Secure Notes.

## Features

- 🔍 **Recursive Discovery**: Automatically finds all `.env*` files in the specified directory and subdirectories
- 🔒 **Secure Storage**: Stores files as Bitwarden Secure Notes with proper naming conventions
- 🔄 **Duplicate Prevention**: Checks for existing items and updates them instead of creating duplicates
- 🌐 **Cross-Platform**: Works on both Linux/macOS (Bash) and Windows (PowerShell)
- 📁 **Preserves Structure**: Item names reflect the relative file path for easy identification
- 🛡️ **Safe Handling**: Properly escapes special characters and preserves file encoding

## Prerequisites

### Common Requirements
- **Bitwarden CLI**: Install globally on your system
  ```bash
  # npm
  npm install -g @bitwarden/cli
  
  # Or with Chocolatey on Windows
  choco install bitwarden-cli
  
  # Or with Homebrew on macOS
  brew install bitwarden-cli
  ```

- **Bitwarden Account**: Free account is sufficient
- **Authentication**: Must be logged into Bitwarden CLI
  
  ```bash
  # Initial login
  bw login
  
  # Unlock vault (do this before running the script)
  bw unlock
  
  # Set session environment variable
  # Linux/macOS:
  export BW_SESSION="<your-session-key>"
  
  # Windows PowerShell:
  $env:BW_SESSION = "<your-session-key>"
  ```

### Platform-Specific Requirements

#### Linux/macOS
- Bash shell
- jq (JSON processor)
  ```bash
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # macOS with Homebrew
  brew install jq
  
  # CentOS/RHEL
  sudo yum install jq
  ```

#### Windows
- PowerShell 5.1+ (built into Windows) or PowerShell 7 (recommended)
- No additional tools required - uses built-in JSON handling

## Setup Instructions

1. **Clone or download this repository**
2. **Authenticate with Bitwarden CLI** (see Prerequisites)
3. **Choose your platform** and run the appropriate script

### Linux/macOS Setup

```bash
# Make the script executable
chmod +x backup-env.sh

# Run it
./backup-env.sh [directory] [prefix]
```

### Windows Setup

```powershell
# If execution policy is restricted (run as Administrator once)
Set-ExecutionPolicy RemoteSigned

# Run the script
.\Backup-Env.ps1 -Directory [directory] -Prefix [prefix]
```

## Usage

### Parameters

- **Directory**: The root directory to search for `.env` files (default: current directory)
- **Prefix**: A prefix to add to all Bitwarden item names (e.g., "My Project")

### Examples

#### Linux/macOS (Bash)

```bash
# Backup all .env files in current directory
./backup-env.sh

# Backup files in a specific directory with a prefix
./backup-env.sh /path/to/project "My Web App"

# Backup with custom prefix and directory
./backup-env.sh ./config "Production Secrets"
```

#### Windows (PowerShell)

```powershell
# Backup all .env files in current directory
.\Backup-Env.ps1

# Backup files in a specific directory with a prefix
.\Backup-Env.ps1 -Directory "C:\Projects\MyApp" -Prefix "My Web App"

# Backup with custom prefix and directory
.\Backup-Env.ps1 -Directory ".\config" -Prefix "Production Secrets"
```

## What Gets Backed Up

The script will find and backup files matching these patterns:
- `.env`
- `.env.local`
- `.env.development`
- `.env.production`
- `.env.test`
- `.env.staging`
- `.env.*` (any file starting with `.env`)

### Naming Convention

Items in Bitwarden are named using this format:
```
[Prefix] - [Relative Path]/[Filename]
```

Examples:
- `My Web App - .env`
- `My Web App - config/.env.production`
- `My Web App - src/api/.env.local`

## Security Considerations

- ✅ Scripts don't log sensitive data to console
- ✅ Session keys are handled securely via environment variables
- ✅ Files are stored as Secure Notes in Bitwarden
- ✅ No temporary files with sensitive content are created
- ⚠️ Ensure your Bitwarden vault has a strong master password
- ⚠️ Consider using Bitwarden Secrets Manager for production application secrets

## Advanced Usage

### Updating Existing Items

The scripts automatically check for existing items with the same name and update them instead of creating duplicates.

### Using in CI/CD

For automated environments, consider using Bitwarden API Keys instead of user login:

```bash
# Set API key environment variables
export BW_CLIENTID="your_client_id"
export BW_CLIENTSECRET="your_client_secret"
export BW_PASSWORD="your_master_password"

# The script will use API key authentication if available
```

### Custom File Patterns

To customize which files are included, modify the `find` command in the Bash script or the `Get-ChildItem` filter in PowerShell.

## Troubleshooting

### Common Issues

1. **"Vault is locked"**
   - Run `bw unlock` and set the BW_SESSION environment variable
   - Session expires after 15 minutes by default

2. **"Scripts are disabled" (Windows)**
   - Run `Set-ExecutionPolicy RemoteSigned` as Administrator
   - Or run: `powershell -ExecutionPolicy Bypass -File .\Backup-Env.ps1`

3. **Encoding issues**
   - Windows script uses UTF-8 encoding by default
   - For Linux, ensure your locale is set correctly

4. **Permission denied**
   - Ensure the Bitwarden CLI has necessary permissions
   - Check file system permissions for the directory being scanned

### Debug Mode

Both scripts support verbose output for troubleshooting:

```bash
# Linux/macOS
./backup-env.sh --verbose

# Windows
.\Backup-Env.ps1 -Verbose
```

## Alternative Methods

### Bitwarden Premium - File Attachments

If you have Bitwarden Premium, you can attach files instead of storing them as notes:

1. Create a Secure Note item
2. Upload the .env file as an attachment
3. This preserves the original file exactly

### Bitwarden Secrets Manager

For production applications, consider Bitwarden Secrets Manager which:
- Provides API access to secrets
- Eliminates need for .env files
- Offers better security and access control
- Requires separate subscription

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use and modify for your needs.
