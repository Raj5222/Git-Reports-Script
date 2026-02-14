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
CYAN="\033[1;36m"
NC="\033[0m"

step() { echo -e "\n${CYAN}[$1]${NC} $2"; }
ok() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✖${NC} $1"; exit 1; }

# 🔥 Cleanup function (always runs)
cleanup() {
    if [ -f "$TMP_FILE" ]; then
        rm -f "$TMP_FILE"
        echo -e "${BLUE}➜${NC} Temp file removed: $TMP_FILE"
    fi

    if [ -f "$BACKUP_FILE" ]; then
        sudo rm -f "$BACKUP_FILE" 2>/dev/null || true
        echo -e "${BLUE}➜${NC} Backup file removed: $BACKUP_FILE"
    fi
}

trap cleanup EXIT

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        Git Record Installer${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}Configuration${NC}"
echo "  Install Path : $INSTALL_PATH"
echo "  Temp File    : $TMP_FILE"
echo "  Backup File  : $BACKUP_FILE"

# STEP 1 — Download
step 1 "Downloading latest version"
if ! curl -# -L "$REPO_SCRIPT" -o "$TMP_FILE"; then
    fail "Download failed"
fi

chmod +x "$TMP_FILE"
NEW_HASH=$(sha256sum "$TMP_FILE" | cut -d ' ' -f1)
FILE_SIZE=$(du -h "$TMP_FILE" | cut -f1)

ok "Download complete ($FILE_SIZE)"
echo "  SHA256: $NEW_HASH"

# STEP 2 — Compare
if [ -f "$INSTALL_PATH" ]; then
    step 2 "Checking existing installation"
    CURRENT_HASH=$(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)
    echo "  Current SHA256: $CURRENT_HASH"

    if [ "$NEW_HASH" = "$CURRENT_HASH" ]; then
        ok "Already running latest version"
        echo -e "\n${GREEN}✔ No changes required${NC}\n"
        exit 0
    else
        warn "Checksum differs → Upgrade required"
    fi
else
    step 2 "No previous installation found"
fi

# STEP 3 — Backup
if [ -f "$INSTALL_PATH" ]; then
    step 3 "Creating backup"
    sudo cp "$INSTALL_PATH" "$BACKUP_FILE" || fail "Backup failed"
    ok "Backup saved → $BACKUP_FILE"
fi

# STEP 4 — Install
step 4 "Installing new version"
echo "  FROM: $TMP_FILE"
echo "  TO  : $INSTALL_PATH"

if sudo mv -f "$TMP_FILE" "$INSTALL_PATH"; then
    ok "Installation successful"
else
    fail "Installation failed — rollback required"
fi

# STEP 5 — Verify
step 5 "Verifying installation"

hash -r 2>/dev/null || true

if command -v git-record >/dev/null 2>&1; then
    ok "Binary detected"
    echo "  Location : $(which git-record)"
    echo "  Final SHA: $(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)"
else
    fail "Binary not found in PATH"
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        Installation Complete ✔${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
