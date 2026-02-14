#!/usr/bin/env bash

set -e

REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"
TMP_FILE="/tmp/git-record"

GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

log() { echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✔ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✖ $1${NC}"; exit 1; }

echo ""
echo "========================================"
echo -e "${GREEN}        Git Record Installer${NC}"
echo "========================================"
echo ""

# Check sudo availability
if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required but not installed."
fi

# Remove old installation if exists
if [ -f "$INSTALL_PATH" ]; then
    log "Existing installation detected."
    sudo rm -f "$INSTALL_PATH" || error "Failed to remove old version."
    success "Old version removed."
fi

# Always download latest
log "Downloading latest version..."
if ! curl -# -L "$REPO_SCRIPT" -o "$TMP_FILE"; then
    error "Download failed."
fi
success "Download completed."

# Set permission
log "Setting executable permission..."
chmod +x "$TMP_FILE"
success "Permission set."

# Install
log "Installing to $INSTALL_PATH ..."
if ! sudo mv -f "$TMP_FILE" "$INSTALL_PATH"; then
    error "Installation failed."
fi
success "Installation successful."

# Clean temp file (if somehow left)
[ -f "$TMP_FILE" ] && rm -f "$TMP_FILE"

# Refresh shell
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
