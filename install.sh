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

# 1️⃣ Download latest version first
log "Downloading latest version..."
if ! curl -# -L "$REPO_SCRIPT" -o "$TMP_FILE"; then
    error "Download failed. Existing installation untouched."
fi

chmod +x "$TMP_FILE"

NEW_HASH=$(sha256sum "$TMP_FILE" | cut -d ' ' -f1)
FILE_SIZE=$(du -h "$TMP_FILE" | cut -f1)

success "Download completed"
log "Downloaded file size : $FILE_SIZE"
log "New SHA256 checksum  : $NEW_HASH"
echo ""

# 2️⃣ Compare with existing installation (if exists)
if [ -f "$INSTALL_PATH" ]; then
    CURRENT_HASH=$(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)

    log "Existing installation detected"
    log "Current SHA256 checksum: $CURRENT_HASH"

    if [ "$NEW_HASH" = "$CURRENT_HASH" ]; then
        success "Already running latest version (checksum match)"
        rm -f "$TMP_FILE"
        exit 0
    else
        warn "Checksum differs — upgrade required"
    fi
else
    log "No previous installation found"
fi

echo ""

# 3️⃣ Backup existing version (if exists)
if [ -f "$INSTALL_PATH" ]; then
    log "Creating backup..."
    sudo cp "$INSTALL_PATH" "$BACKUP_FILE" || error "Backup failed"
    success "Backup created → $BACKUP_FILE"
fi

echo ""

# 4️⃣ Install new version
log "Installing new version..."
log "Moving:"
log "  FROM: $TMP_FILE"
log "  TO  : $INSTALL_PATH"

if sudo mv -f "$TMP_FILE" "$INSTALL_PATH"; then
    success "Installation successful"
else
    warn "Installation failed — attempting rollback"

    if [ -f "$BACKUP_FILE" ]; then
        sudo mv -f "$BACKUP_FILE" "$INSTALL_PATH"
        error "Rollback completed — previous version restored"
    else
        error "Rollback failed — manual recovery required"
    fi
fi

echo ""

# 5️⃣ Cleanup backup after success
if [ -f "$BACKUP_FILE" ]; then
    sudo rm -f "$BACKUP_FILE"
    success "Backup removed after successful upgrade"
fi

# 6️⃣ Final verification
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
    echo -e "${GREEN}Final SHA256    :${NC} $(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)"
else
    error "Installation failed — binary not found in PATH"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}        Installation Completed Successfully${NC}"
echo "=================================================="
echo ""
