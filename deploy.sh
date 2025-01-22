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

# Function to set up installation directories
create_directories() {
    mkdir -p "$INSTALL_DIR" "$BIN_DIR"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create required directories"
        return 1
    fi
    return 0
}

# Function to install script files
copy_files() {
    local files=("update.sh" "system-check.sh" "package-update.sh" "log-manage.sh" "utils.sh")
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Required file $file not found"
            return 1
        fi
        cp "$file" "$INSTALL_DIR/"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to copy $file"
            return 1
        fi
    done
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    if [[ $? -ne 0 ]]; then
        print_error "Failed to set executable permissions"
        return 1
    fi
    
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
