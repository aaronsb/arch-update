#!/bin/bash
#
# Deployment script for update-arch system maintenance tool
# Handles installation, uninstallation, and version management

# Source utils.sh first if available
if [[ -f "./utils.sh" ]]; then
    source ./utils.sh
else
    # Minimal color definitions if utils.sh not available
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    NC="$(tput sgr0)"
    print_error() { echo "${RED}ERROR: $1${NC}"; }
    print_success() { echo "${GREEN}SUCCESS: $1${NC}"; }
    print_warning() { echo "${YELLOW}WARNING: $1${NC}"; }
fi

# Constants
INSTALL_DIR="$HOME/.local/share/update-arch"
BIN_DIR="$HOME/.local/bin"
SCRIPT_NAME="update-arch"
REQUIRED_DEPS="bash sudo pacman systemctl"

# Function to extract version from update.sh
get_version() {
    local version_line
    version_line=$(grep "^VERSION=" "update.sh")
    echo "${version_line#VERSION=}" | tr -d '"'
}

# Function to verify required dependencies
check_dependencies() {
    local missing_deps=()
    for dep in $REQUIRED_DEPS; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Function to get list of tracked files from git
get_tracked_files() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        print_error "Not in a git repository"
        return 1
    fi
    
    # Get list of tracked files, excluding .git* files
    git ls-files | grep -v "^\.git"
    return $?
}

# Function to compute hash of a file
compute_file_hash() {
    local file="$1"
    if [[ -f "$file" ]]; then
        git hash-object "$file"
    else
        echo "file_not_found"
    fi
}

# Function to detect modified files in deployment
compute_file_changes() {
    local source_file deployed_file source_hash deployed_hash
    local modified_files=()
    
    while IFS= read -r file; do
        source_file="$file"
        deployed_file="$INSTALL_DIR/$file"
        
        # Skip if deployed file doesn't exist
        [[ ! -f "$deployed_file" ]] && continue
        
        source_hash=$(compute_file_hash "$source_file")
        deployed_hash=$(compute_file_hash "$deployed_file")
        
        if [[ "$source_hash" != "$deployed_hash" ]]; then
            modified_files+=("$file")
        fi
    done < <(get_tracked_files)
    
    (IFS=$'\n'; echo "${modified_files[*]}")
}

# Function to detect extra files in deployment
detect_extra_files() {
    local tracked_files extra_files=()
    local deploy_base="${INSTALL_DIR#"$HOME/"}"  # Remove $HOME/ prefix for cleaner output
    
    # Get tracked files
    tracked_files=$(get_tracked_files)
    
    # Find all files in deployment directory
    while IFS= read -r deployed_file; do
        # Convert to relative path
        local rel_path="${deployed_file#"$INSTALL_DIR/"}"
        
        # Check if file is tracked
        if ! echo "$tracked_files" | grep -Fq "$rel_path"; then
            extra_files+=("$deploy_base/$rel_path")
        fi
    done < <(find "$INSTALL_DIR" -type f 2>/dev/null)
    
    (IFS=$'\n'; echo "${extra_files[*]}")
}

# Function to handle extra files
handle_extra_files() {
    local extra_files="$1"
    local reply
    
    echo
    print_warning "The following files were found in the deployment directory but are not in the git repository:"
    echo "$extra_files" | sed 's/^/  /'
    echo
    print_warning "These files may cause unexpected behavior. It's recommended to:"
    echo "1. Move important files to your git repository"
    echo "2. Remove extra files from the deployment directory"
    echo
    echo "Would you like to remove these extra files? [y/N]"
    read -r reply
    
    case "$reply" in
        [Yy]*)
            echo "$extra_files" | while IFS= read -r file; do
                rm -f "$HOME/$file"
                echo "Removed: $file"
            done
            return 0
            ;;
        *)
            print_warning "Keeping extra files - they may cause unexpected behavior"
            return 1
            ;;
    esac
}

# Function to check existing deployment
check_existing_deployment() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        return 1
    fi
    
    local modified_files
    modified_files=$(compute_file_changes)
    
    if [[ -n "$modified_files" ]]; then
        print_warning "The following deployed files have been modified:"
        echo "$modified_files" | sed 's/^/  /'
        echo
        print_warning "Proceeding will overwrite these modifications"
        echo "Consider moving any important changes to your git repository"
        echo
        echo "Press Enter to continue or Ctrl+C to abort"
        read -r
    fi
    
    return 0
}

# Function to set up installation directories
create_directories() {
    mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$INSTALL_DIR/modules" "$HOME/.config/update-arch"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create required directories"
        return 1
    fi
    return 0
}

# Function to configure terminal preferences
configure_terminal_preferences() {
    local config_file="$HOME/.config/update-arch/terminal.conf"
    local detected_term reply
    
    # Run terminal detection
    detected_term=$(detect_terminal)
    
    # Create or update config file
    cat > "$config_file" << EOL
# Terminal configuration for update-arch
# Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
DETECTED_TERMINAL="$detected_term"
PREFERRED_TERMINAL="auto"
FORCE_ASCII_ICONS="false"
LAST_DETECTION_TIME="$(date +%s)"
EOL
    
    print_success "Terminal detected: $detected_term"
    echo
    print_warning "Would you like to customize terminal preferences? [y/N]"
    read -r reply
    
    case "$reply" in
        [Yy]*)
            echo
            print_warning "Force ASCII icons (no Nerd Font icons)? [y/N]"
            read -r reply
            case "$reply" in
                [Yy]*)
                    sed -i 's/FORCE_ASCII_ICONS="false"/FORCE_ASCII_ICONS="true"/' "$config_file"
                    print_success "ASCII icons enabled"
                    ;;
            esac
            
            echo
            print_warning "Override detected terminal? [y/N]"
            read -r reply
            case "$reply" in
                [Yy]*)
                    echo "Enter preferred terminal (e.g., vscode, kitty, auto):"
                    read -r preferred
                    sed -i "s/PREFERRED_TERMINAL=\"auto\"/PREFERRED_TERMINAL=\"$preferred\"/" "$config_file"
                    print_success "Preferred terminal set to: $preferred"
                    ;;
            esac
            ;;
    esac
    
    echo
    print_success "Terminal preferences configured"
    print_info_box "You can reconfigure anytime with: update-arch --configure-terminal"
    return 0
}

# Function to install script files
copy_files() {
    local file target_dir target_file
    local copied_files=0
    local tracked_files
    
    # Get list of tracked files from git
    tracked_files=$(get_tracked_files) || {
        print_error "Failed to get list of tracked files"
        return 1
    }
    
    # Process each tracked file
    while IFS= read -r file; do
        # Skip empty lines
        [[ -z "$file" ]] && continue
        
        # Skip files that don't exist (might be renamed with .disabled)
        [[ ! -f "$file" ]] && continue
        
        # Determine target directory and filename
        if [[ "$file" == modules/* ]]; then
            target_dir="$INSTALL_DIR/modules"
            # If source is .disabled, keep that extension in target
            if [[ "$file" == *.disabled ]]; then
                target_file="$INSTALL_DIR/$file"
            else
                target_file="$INSTALL_DIR/${file%.*}.sh"
            fi
        else
            target_dir="$INSTALL_DIR"
            target_file="$INSTALL_DIR/$file"
        fi
        
        # Create target directory if needed
        mkdir -p "$(dirname "$target_file")"
        
        # Copy file
        if cp "$file" "$target_file"; then
            echo "Copied: $file"
            ((copied_files++))
            
            # Make shell scripts executable
            if [[ "$file" == *.sh ]] && [[ "$file" != *.sh.disabled ]]; then
                chmod +x "$target_file" || {
                    print_error "Failed to set executable permissions on $file"
                    return 1
                }
            fi
        else
            print_error "Failed to copy $file"
            return 1
        fi
    done <<< "$tracked_files"
    
    if [[ $copied_files -eq 0 ]]; then
        print_error "No files were copied"
        return 1
    fi
    
    print_success "Copied $copied_files files"
    return 0
}

# Function to create command symlink
create_symlink() {
    # Remove existing symlink if it exists
    if [[ -L "$BIN_DIR/$SCRIPT_NAME" ]]; then
        rm "$BIN_DIR/$SCRIPT_NAME"
    elif [[ -e "$BIN_DIR/$SCRIPT_NAME" ]]; then
        print_error "$BIN_DIR/$SCRIPT_NAME exists but is not a symlink"
        return 1
    fi
    
    # Create new symlink
    ln -s "$INSTALL_DIR/update.sh" "$BIN_DIR/$SCRIPT_NAME"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create symlink"
        return 1
    fi
    
    return 0
}

# Function to check if ~/.local/bin is in PATH and add it if not
check_path() {
    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        print_warning "$BIN_DIR is not in your PATH"
        echo "To add it to your PATH, add the following line to your shell profile:"
        echo
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        
        # Determine shell profile file
        local shell_profile=""
        case "$SHELL" in
            */bash)
                if [[ -f "$HOME/.bash_profile" ]]; then
                    shell_profile="$HOME/.bash_profile"
                elif [[ -f "$HOME/.profile" ]]; then
                    shell_profile="$HOME/.profile"
                else
                    shell_profile="$HOME/.bashrc"
                fi
                ;;
            */zsh)
                shell_profile="$HOME/.zshrc"
                ;;
            */fish)
                shell_profile="$HOME/.config/fish/config.fish"
                ;;
            *)
                shell_profile="your shell profile"
                ;;
        esac
        
        echo "Would you like to add it to $shell_profile now? [y/N]"
        local reply
        read -r reply
        
        case "$reply" in
            [Yy]*)
                if [[ "$shell_profile" == "your shell profile" ]]; then
                    print_warning "Could not determine your shell profile. Please add it manually."
                    return 1
                fi
                
                # Create directory if it doesn't exist
                mkdir -p "$(dirname "$shell_profile")"
                
                # Add to shell profile
                if [[ "$shell_profile" == *"fish"* ]]; then
                    echo "set -x PATH \$HOME/.local/bin \$PATH" >> "$shell_profile"
                else
                    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$shell_profile"
                fi
                
                print_success "Added $BIN_DIR to your PATH in $shell_profile"
                print_warning "You need to restart your shell or run 'source $shell_profile' for the changes to take effect"
                ;;
            *)
                print_warning "PATH not updated. You may need to run update-arch with its full path: $BIN_DIR/$SCRIPT_NAME"
                ;;
        esac
        
        return 1
    fi
    
    return 0
}

# Function to remove all installed components
uninstall() {
    print_warning "Uninstalling update-arch..."
    
    # Remove symlink
    if [[ -L "$BIN_DIR/$SCRIPT_NAME" ]]; then
        rm "$BIN_DIR/$SCRIPT_NAME"
        print_success "Removed symlink"
    fi
    
    # Remove install directory
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "Removed install directory"
    fi
    
    # Remove terminal configuration
    if [[ -f "$HOME/.config/update-arch/terminal.conf" ]]; then
        rm -f "$HOME/.config/update-arch/terminal.conf"
        print_success "Removed terminal configuration"
        # Try to remove config directory if empty
        rmdir "$HOME/.config/update-arch" 2>/dev/null || true
    fi
    
    print_success "Uninstallation complete"
    return 0
}

# Function to perform installation
install() {
    print_header "Installing update-arch..."
    
    # Check dependencies
    check_dependencies || return 1
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        print_error "Not running from a git repository"
        print_error "The deploy script requires a git repository to track file changes"
        return 1
    fi
    
    # Run terminal detection test first
    print_header "Terminal Detection"
    test_terminal_detection
    
    # Check for existing deployment and modifications
    if check_existing_deployment; then
        print_warning "Existing deployment detected"
        echo "This is normal - files will be updated in place"
        echo
        
        # Check for extra files
        local extra_files
        extra_files=$(detect_extra_files)
        
        if [[ -n "$extra_files" ]]; then
            handle_extra_files "$extra_files"
        fi
    fi
    
    # Create directories
    create_directories || return 1
    
    # Copy files
    copy_files || return 1
    
    # Create symlink
    create_symlink || return 1
    
    # Configure terminal preferences
    configure_terminal_preferences || return 1
    
    # Check if ~/.local/bin is in PATH
    check_path
    local path_in_path=$?
    
    local version
    version=$(get_version)
    print_success "Installation of update-arch v${version} complete!"
    
    if [[ $path_in_path -eq 0 ]]; then
        echo "You can now run '${GREEN}update-arch${NC}' from anywhere"
    else
        echo "You can run '${GREEN}$BIN_DIR/$SCRIPT_NAME${NC}' to use the script"
    fi
    
    echo "Use '${GREEN}update-arch --help${NC}' to see available options"
    return 0
}

# Main execution logic
case "$1" in
    --uninstall)
        uninstall
        ;;
    *)
        install
        ;;
esac
