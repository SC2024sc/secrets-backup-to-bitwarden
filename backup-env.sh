#!/bin/bash

# .env Files to Bitwarden Backup Script (Linux/macOS)
# Recursively finds all .env files and backs them up to Bitwarden as Secure Notes

set -euo pipefail

# Default values
DIRECTORY="."
PREFIX=""
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v bw &> /dev/null; then
        missing+=("bw (Bitwarden CLI)")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        print_info "Install missing dependencies:"
        print_info "  npm install -g @bitwarden/cli"
        print_info "  # For jq:"
        print_info "  Ubuntu/Debian: sudo apt-get install jq"
        print_info "  macOS: brew install jq"
        print_info "  CentOS/RHEL: sudo yum install jq"
        exit 1
    fi
}

# Function to check Bitwarden authentication
check_bitwarden_auth() {
    if [ -z "${BW_SESSION:-}" ] && ! bw status | grep -q "unlocked"; then
        print_error "Bitwarden vault is locked or not authenticated"
        print_info "Please run:"
        print_info "  bw login"
        print_info "  bw unlock"
        print_info "Then set the BW_SESSION environment variable"
        exit 1
    fi
}

# Function to find all .env files
find_env_files() {
    local search_dir="$1"
    local env_files
    
    # Find all files starting with .env
    env_files=$(find "$search_dir" -type f -name ".env*" -not -name ".env.swp" -not -name ".env.tmp" 2>/dev/null || true)
    
    if [ -z "$env_files" ]; then
        print_warning "No .env files found in '$search_dir'"
        return 1
    fi
    
    echo "$env_files"
}

# Function to create item name
create_item_name() {
    local file_path="$1"
    local base_dir="$2"
    local prefix="$3"
    
    # Get relative path
    local rel_path
    rel_path=$(realpath --relative-to="$base_dir" "$file_path")
    
    # Build item name
    if [ -n "$prefix" ]; then
        echo "$prefix - $rel_path"
    else
        echo "$rel_path"
    fi
}

# Function to check if item exists
item_exists() {
    local item_name="$1"
    local item_id
    
    item_id=$(bw list items --search "$item_name" | jq -r '.[] | select(.name == "'"$item_name"'") | .id' 2>/dev/null || true)
    
    if [ -n "$item_id" ]; then
        echo "$item_id"
        return 0
    fi
    
    return 1
}

# Function to create or update Bitwarden item
backup_env_file() {
    local file_path="$1"
    local base_dir="$2"
    local prefix="$3"
    
    local item_name
    item_name=$(create_item_name "$file_path" "$base_dir" "$prefix")
    
    if [ "$VERBOSE" = true ]; then
        print_info "Processing: $file_path"
        print_info "Item name: $item_name"
    fi
    
    # Read file content
    local content
    content=$(cat "$file_path")
    
    # Check if item already exists
    local existing_id
    existing_id=$(item_exists "$item_name" || true)
    
    # Create JSON payload
    local payload
    payload=$(jq -n \
        --arg name "$item_name" \
        --arg notes "$content" \
        '{
            type: 2,
            name: $name,
            notes: $notes,
            secureNote: { type: 0 }
        }')
    
    # Create or update item
    if [ -n "$existing_id" ]; then
        if [ "$VERBOSE" = true ]; then
            print_info "Updating existing item: $existing_id"
        fi
        
        # Add ID to payload for update
        payload=$(echo "$payload" | jq --arg id "$existing_id" '. + {id: $id}')
        
        local result
        result=$(echo "$payload" | bw edit item 2>/dev/null || true)
        
        if [ -n "$result" ]; then
            print_success "Updated: $item_name"
        else
            print_error "Failed to update: $item_name"
            return 1
        fi
    else
        local result
        result=$(echo "$payload" | bw create item 2>/dev/null || true)
        
        if [ -n "$result" ]; then
            local item_id
            item_id=$(echo "$result" | jq -r '.id')
            print_success "Created: $item_name (ID: $item_id)"
        else
            print_error "Failed to create: $item_name"
            return 1
        fi
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY] [PREFIX]

Recursively finds all .env files and backs them up to Bitwarden.

Arguments:
  DIRECTORY    Directory to search for .env files (default: current directory)
  PREFIX       Prefix to add to all Bitwarden item names (optional)

Options:
  -h, --help   Show this help message
  -v, --verbose Enable verbose output

Examples:
  $(basename "$0")                                    # Search current directory
  $(basename "$0") /path/to/project                   # Search specific directory
  $(basename "$0") . "My Project"                     # Add prefix to item names
  $(basename "$0") /config "Production Secrets"       # Directory with prefix

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$DIRECTORY" ] || [ "$DIRECTORY" = "." ]; then
                DIRECTORY="$1"
            elif [ -z "$PREFIX" ]; then
                PREFIX="$1"
            else
                print_error "Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Convert to absolute path
DIRECTORY=$(realpath "$DIRECTORY")

# Main execution
main() {
    print_info ".env Files to Bitwarden Backup Script"
    print_info "====================================="
    
    # Check dependencies
    check_dependencies
    
    # Check Bitwarden authentication
    check_bitwarden_auth
    
    # Validate directory
    if [ ! -d "$DIRECTORY" ]; then
        print_error "Directory not found: $DIRECTORY"
        exit 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        print_info "Search directory: $DIRECTORY"
        print_info "Prefix: ${PREFIX:-'(none)'}"
    fi
    
    # Find all .env files
    local env_files
    env_files=$(find_env_files "$DIRECTORY")
    
    if [ $? -ne 0 ]; then
        exit 0
    fi
    
    # Process each file
    local file_count=0
    local success_count=0
    local error_count=0
    
    while IFS= read -r file; do
        ((file_count++))
        
        if backup_env_file "$file" "$DIRECTORY" "$PREFIX"; then
            ((success_count++))
        else
            ((error_count++))
        fi
    done <<< "$env_files"
    
    # Summary
    print_info "====================================="
    print_info "Backup Summary:"
    print_info "  Total files found: $file_count"
    print_success "  Successfully backed up: $success_count"
    
    if [ $error_count -gt 0 ]; then
        print_error "  Failed: $error_count"
        exit 1
    fi
    
    print_success "All .env files backed up successfully!"
}

# Run main function
main
