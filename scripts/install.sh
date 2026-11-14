#!/usr/bin/env bash
# scripts/install.sh - Non-root user space installer for SMD-TUI 2.0
# Installs to ~/.local/bin and initializes ~/.config/smd-tui/config.conf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ANSI Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_BIN_DIR="${HOME}/.local/bin"
TARGET_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/smd-tui"
SYMLINK_PATH="${TARGET_BIN_DIR}/smd-tui"

uninstall() {
    echo -e "${YELLOW}Uninstalling SMD-TUI 2.0...${NC}"
    if [[ -L "$SYMLINK_PATH" || -f "$SYMLINK_PATH" ]]; then
        rm -f "$SYMLINK_PATH"
        echo -e "  ✓ Removed executable: $SYMLINK_PATH"
    fi
    echo -e "${GREEN}SMD-TUI binary removed.${NC}"
    echo -e "Note: User configuration in '$TARGET_CONFIG_DIR' was preserved."
    exit 0
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
fi

echo -e "${CYAN}${BOLD}==================================================${NC}"
echo -e "${CYAN}${BOLD}       SMD-TUI 2.0 - Non-Root User Installer      ${NC}"
echo -e "${CYAN}${BOLD}==================================================${NC}"

# Check for root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Notice: Running as root. SMD-TUI is designed for normal non-root user accounts.${NC}"
fi

# 1. Ensure target bin directory exists
mkdir -p "$TARGET_BIN_DIR"
mkdir -p "$TARGET_CONFIG_DIR"

# 2. Make app.sh executable
chmod +x "$PROJECT_ROOT/app.sh"

# 3. Create or update symlink
ln -sf "$PROJECT_ROOT/app.sh" "$SYMLINK_PATH"
echo -e "  ${GREEN}✓${NC} Created symlink: ${BOLD}$SYMLINK_PATH${NC} -> $PROJECT_ROOT/app.sh"

# 4. Install default configuration if not already present
if [[ ! -f "$TARGET_CONFIG_DIR/config.conf" ]]; then
    cp "$PROJECT_ROOT/config/defaults.conf" "$TARGET_CONFIG_DIR/config.conf"
    echo -e "  ${GREEN}✓${NC} Initialized default user config: $TARGET_CONFIG_DIR/config.conf"
else
    echo -e "  - User configuration already exists: $TARGET_CONFIG_DIR/config.conf (kept intact)"
fi

# 5. Check if ~/.local/bin is in PATH
echo ""
if [[ ":$PATH:" != *":$TARGET_BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Tip: '${TARGET_BIN_DIR}' is not currently in your \$PATH.${NC}"
    echo -e "Add it by adding this line to your ~/.bashrc or ~/.profile:"
    echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
fi

echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo -e "You can launch SMD-TUI 2.0 with: ${CYAN}${BOLD}smd-tui${NC} or ${CYAN}${BOLD}$PROJECT_ROOT/app.sh${NC}"
