#!/usr/bin/env bash

set -e

REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"
TMP_FILE="/tmp/git-record-$$"

GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
NC="\033[0m"

log() { echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✔ $1${NC}"; }
error() { echo -e "${RED}✖ $1${NC}"; exit 1; }

echo ""
echo "========================================"
echo -e "${GREEN}        Git Record Installer${NC}"
echo "========================================"
echo ""

# 1️⃣ Remove old version if exists
if [ -f "$INSTALL_PATH" ]; then
    log "Old version detected. Removing..."
    sudo rm -f "$INSTALL_PATH" || error "Failed to remove old version."
    success "Old version removed."
fi

# 2️⃣ Download latest
log "Downloading latest version..."
curl -# -L "$REPO_SCRIPT" -o "$TMP_FILE" || error "Download failed."
success "Download complete."

# 3️⃣ Make executable
chmod +x "$TMP_FILE"

# 4️⃣ Install
log "Installing new version..."
sudo mv -f "$TMP_FILE" "$INSTALL_PATH" || error "Installation failed."
success "Installation successful."

# 5️⃣ Refresh shell
hash -r 2>/dev/null || true

echo ""
success "git-record is ready to use!"
echo -e "${GREEN}Run:${NC} git record"
echo ""
