#!/bin/bash
# ============================================================================
# EnvVarSwitcher (evs) - WSL Installation Script
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVS_SCRIPT="$SCRIPT_DIR/evs.sh"

echo ""
echo -e "${CYAN}EnvVarSwitcher (evs) - WSL Installer${NC}"
echo "======================================"
echo ""

# Check if evs.sh exists
if [[ ! -f "$EVS_SCRIPT" ]]; then
    echo -e "${RED}Error: evs.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Check for jq
echo -n "Checking for jq... "
if command -v jq &> /dev/null; then
    echo -e "${GREEN}found${NC}"
else
    echo -e "${YELLOW}not found${NC}"
    echo ""
    echo "jq is required for JSON parsing. Install it with:"
    echo ""
    echo "  Ubuntu/Debian: sudo apt install jq"
    echo "  Alpine:        apk add jq"
    echo "  macOS:         brew install jq"
    echo ""
    read -p "Continue anyway? (y/N): " continue_install
    if [[ "$continue_install" != "y" && "$continue_install" != "Y" ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Detect shell
SHELL_NAME=$(basename "$SHELL")
echo "Detected shell: $SHELL_NAME"

# Determine RC file
case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    *)
        RC_FILE="$HOME/.bashrc"
        echo -e "${YELLOW}Warning: Unknown shell '$SHELL_NAME', defaulting to .bashrc${NC}"
        ;;
esac

echo "RC file: $RC_FILE"
echo ""

# Function definition to add
EVS_FUNCTION="
# EnvVarSwitcher (evs) - Environment Variable Switcher
evs() {
    source \"$EVS_SCRIPT\" \"\$@\"
}"

# Check if already installed
if [[ -f "$RC_FILE" ]] && grep -q "EnvVarSwitcher" "$RC_FILE" 2>/dev/null; then
    echo -e "${YELLOW}evs is already installed in $RC_FILE${NC}"
    echo ""
    read -p "Do you want to reinstall? (y/N): " reinstall
    if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    # Remove existing installation
    sed -i '/# EnvVarSwitcher/,/^}/d' "$RC_FILE"
    echo "Removed existing installation."
fi

# Add to RC file
echo "$EVS_FUNCTION" >> "$RC_FILE"

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "The 'evs' command has been added to $RC_FILE"
echo ""
echo -e "${CYAN}To start using evs:${NC}"
echo "  1. Run: source $RC_FILE"
echo "  2. Or restart your terminal"
echo "  3. Then try: evs list"
echo ""
echo "Script location: $EVS_SCRIPT"
echo "Profiles location: $SCRIPT_DIR/profiles/"
echo ""

# Optional: create local config directory
read -p "Create local profiles directory (~/.config/evs/profiles)? (y/N): " create_local
if [[ "$create_local" == "y" || "$create_local" == "Y" ]]; then
    mkdir -p "$HOME/.config/evs/profiles"
    echo -e "${GREEN}Created: $HOME/.config/evs/profiles${NC}"
    echo "Local profiles will take priority over shared ones."
fi

echo ""
