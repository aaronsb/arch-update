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
    mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$INSTALL_DIR/modules"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create required directories"
        return 1
    fi
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
        
        # Determine target directory
        if [[ "$file" == modules/* ]]; then
            target_dir="$INSTALL_DIR/modules"
            target_file="$INSTALL_DIR/$file"
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
    
    print_success "Uninstallation complete"
    return 0
}

# Function to perform installation
install() {
    echo "Installing update-arch..."
    
    # Check dependencies
    check_dependencies || return 1
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        print_error "Not running from a git repository"
        print_error "The deploy script requires a git repository to track file changes"
        return 1
    fi
    
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
    
    local version
    version=$(get_version)
    print_success "Installation of update-arch v${version} complete!"
    echo "You can now run '${GREEN}update-arch${NC}' from anywhere"
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
