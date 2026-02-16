#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"
TMP_FILE="/tmp/git-record-installer-$$"
BACKUP_FILE="/tmp/git-record-backup-$$"

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m" # No Color
BOLD="\033[1m"

# -----------------------------------------------------------------------------
# 🛡️ CLEANUP HANDLER (The Safety Net)
# -----------------------------------------------------------------------------
# This runs automatically on EXIT, Ctrl+C (INT), Warning (TERM), or Close (HUP)
cleanup_on_exit() {
    # Remove the temp file if it exists
    if [ -f "$TMP_FILE" ]; then
        rm -f "$TMP_FILE"
    fi
    
    # Remove the backup file if it exists (only keep if we manually restored it)
    if [ -f "$BACKUP_FILE" ]; then
        sudo rm -f "$BACKUP_FILE" 2>/dev/null || true
    fi
}

# Trap signals to ensure cleanup always happens
trap cleanup_on_exit EXIT INT TERM HUP

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

# Usage: run_task "Description" "Command"
run_task() {
    local desc="$1"
    local cmd="$2"

    # 1. Show "Processing" state (Blue)
    printf "${BLUE} [ .. ]${NC} %s" "$desc"

    # 2. Run command silently, capture output
    local output
    output=$(eval "$cmd" 2>&1)
    local status=$?

    # Artificial delay for visual smoothness
    sleep 0.3

    # 3. Check Status
    if [ $status -eq 0 ]; then
        # SUCCESS: Green Check
        printf "\r${GREEN} [ ✔ ]${NC} %s\n" "$desc"
    else
        # FAILURE: Red X
        printf "\r${RED} [ ✖ ]${NC} %s\n" "$desc"
        
        # Show Error Details
        echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED} ERROR DETAILS:${NC}"
        echo -e "${YELLOW}$output${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Restore backup if we messed up the install
        if [ -f "$BACKUP_FILE" ] && [ ! -f "$INSTALL_PATH" ]; then
            echo -e " ${YELLOW}↺ Restoring previous version...${NC}"
            sudo mv "$BACKUP_FILE" "$INSTALL_PATH"
        fi
        
        # Exit with error (Triggers the 'trap' cleanup automatically)
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}         Git Record Installer${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 0. Permissions Check
# We run this manually to handle the password prompt gracefully
if [ "$EUID" -ne 0 ]; then
    printf "${BLUE} [ .. ]${NC} Checking permissions"
    if sudo -v 2>/dev/null; then
         printf "\r${GREEN} [ ✔ ]${NC} Checking permissions\n"
    else
         printf "\r${RED} [ ✖ ]${NC} Checking permissions\n"
         echo -e "${RED}      Error: Sudo password required.${NC}"
         exit 1
    fi
fi

# 1. Download
run_task "Downloading source" \
    "curl -fsSL '$REPO_SCRIPT' -o '$TMP_FILE' && [ -s '$TMP_FILE' ]"

# 2. Verify Checksum Logic
verify_checksum() {
    NEW_HASH=$(sha256sum "$TMP_FILE" | cut -d ' ' -f1)
    if [ -f "$INSTALL_PATH" ]; then
        CUR_HASH=$(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)
        if [ "$NEW_HASH" = "$CUR_HASH" ]; then
            return 2 # Special code: Already Installed
        fi
    fi
    chmod +x "$TMP_FILE"
}

printf "${BLUE} [ .. ]${NC} Verifying integrity"
OUTPUT=$(verify_checksum 2>&1)
STATUS=$?

if [ $STATUS -eq 2 ]; then
    printf "\r${GREEN} [ ✔ ]${NC} Verifying integrity\n"
    
    # Explicit visual cleanup for the "Already Installed" path
    printf "${GREEN} [ ✔ ]${NC} Cleaning up\n"
    
    echo -e "\n${GREEN} You are already running the latest version!${NC}\n"
    exit 0
elif [ $STATUS -eq 0 ]; then
    printf "\r${GREEN} [ ✔ ]${NC} Verifying integrity\n"
else
    printf "\r${RED} [ ✖ ]${NC} Verifying integrity\n"
    echo -e "${YELLOW}$OUTPUT${NC}"
    exit 1
fi

# 3. Backup
if [ -f "$INSTALL_PATH" ]; then
    run_task "Backing up old version" \
        "sudo cp '$INSTALL_PATH' '$BACKUP_FILE'"
fi

# 4. Install
run_task "Installing binary" \
    "sudo mv -f '$TMP_FILE' '$INSTALL_PATH' && sudo chmod +x '$INSTALL_PATH'"

# 5. Validation
run_task "Validating installation" \
    "hash -r; command -v git-record"

# 6. Visual Cleanup Step
# The trap handles the actual deletion on exit, but this task ensures 
# the user *sees* that cleanup is part of the process.
run_task "Cleaning up artifacts" \
    "rm -f '$TMP_FILE' && sudo rm -f '$BACKUP_FILE' 2>/dev/null"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}✔ Installation Complete${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Run with command: ${BOLD}git-record${NC}"
echo ""
