#!/usr/bin/env bash

set -e

# ==============================
#        CONFIGURATION
# ==============================
REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"

# ==============================
#        COLORS
# ==============================
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

log() {
    echo -e "${BLUE}➜${NC} $1"
}

success() {
    echo -e "${GREEN}✔ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✖ $1${NC}"
    exit 1
}

# ==============================
#        INSTALL PROCESS
# ==============================

echo ""
echo "========================================"
echo -e "${GREEN}        Git Record Installer${NC}"
echo "========================================"
echo ""

# Check sudo
if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required but not installed."
fi

log "Downloading git-record..."
if ! curl -# -L "$REPO_SCRIPT" -o git-record; then
    error "Download failed."
fi
success "Download completed."

log "Setting executable permissions..."
chmod +x git-record
success "Permissions set."

log "Installing to $INSTALL_PATH ..."
if ! sudo mv -f git-record "$INSTALL_PATH"; then
    error "Installation failed. Check permissions."
fi
success "Installed successfully."

log "Refreshing shell..."
hash -r 2>/dev/null || true

echo ""
if command -v git-record >/dev/null 2>&1; then
    success "git-record is ready to use!"
    echo ""
    echo -e "${GREEN}Run:${NC} git record"
else
    warn "Installed but not found in PATH."
fi

echo ""
echo "========================================"
echo -e "${GREEN}        Installation Complete${NC}"
echo "========================================"
echo ""
