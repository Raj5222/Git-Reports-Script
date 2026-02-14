#!/usr/bin/env bash

set -e

REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"
TMP_FILE="/tmp/git-record-$$"
BACKUP_FILE="/tmp/git-record-backup-$$"

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
echo "=================================================="
echo -e "${GREEN}        Git Record Enterprise Installer${NC}"
echo "=================================================="
echo ""

log "Install Path      : $INSTALL_PATH"
log "Temp Download Path: $TMP_FILE"
log "Backup Path       : $BACKUP_FILE"
echo ""

# 1️⃣ Download first
log "Downloading latest version from:"
log "$REPO_SCRIPT"
echo ""

if ! curl -# -L "$REPO_SCRIPT" -o "$TMP_FILE"; then
    error "Download failed. Existing installation untouched."
fi

FILE_SIZE=$(du -h "$TMP_FILE" | cut -f1)
CHECKSUM=$(sha256sum "$TMP_FILE" | cut -d ' ' -f1)

success "Download completed"
log "Downloaded file size : $FILE_SIZE"
log "SHA256 checksum      : $CHECKSUM"

chmod +x "$TMP_FILE"
success "Executable permission applied"

echo ""

# 2️⃣ Backup old version if exists
if [ -f "$INSTALL_PATH" ]; then
    log "Existing installation detected at:"
    log "$INSTALL_PATH"

    sudo cp "$INSTALL_PATH" "$BACKUP_FILE" || error "Backup failed"
    success "Backup created → $BACKUP_FILE"
else
    log "No previous installation found"
fi

echo ""

# 3️⃣ Install new version
log "Installing new version..."
log "Moving:"
log "  FROM: $TMP_FILE"
log "  TO  : $INSTALL_PATH"

if sudo mv -f "$TMP_FILE" "$INSTALL_PATH"; then
    success "Move successful"
else
    warn "Installation failed — attempting rollback"

    if [ -f "$BACKUP_FILE" ]; then
        sudo mv -f "$BACKUP_FILE" "$INSTALL_PATH"
        error "Rollback complete — previous version restored"
    else
        error "Rollback failed — no backup available"
    fi
fi

echo ""

# 4️⃣ Cleanup backup after success
if [ -f "$BACKUP_FILE" ]; then
    sudo rm -f "$BACKUP_FILE"
    success "Backup removed after successful install"
fi

# 5️⃣ Final verification
hash -r 2>/dev/null || true

echo ""
log "Verifying installation..."

if command -v git-record >/dev/null 2>&1; then
    success "Binary detected in PATH"
    echo ""
    echo -e "${GREEN}Binary Location :${NC} $(which git-record)"
    echo -e "${GREEN}File Details    :${NC}"
    ls -lh "$INSTALL_PATH"
    echo ""
    echo -e "${GREEN}Installed Version:${NC}"
    git-record --version 2>/dev/null || echo "Version flag not implemented"
else
    error "Installation failed — binary not found in PATH"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}        Installation Completed Successfully${NC}"
echo "=================================================="
echo ""
