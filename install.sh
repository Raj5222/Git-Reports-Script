#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"
TMP_FILE="/tmp/git-record-installer-$$"
BACKUP_FILE="/tmp/git-record-backup-$$"

# Total steps for the progress bar
TOTAL_STEPS=6
CURRENT_STEP=0

# -----------------------------------------------------------------------------
# Colors & Formatting
# -----------------------------------------------------------------------------
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m" # No Color
BOLD="\033[1m"

# -----------------------------------------------------------------------------
# UI Functions (Progress Bar)
# -----------------------------------------------------------------------------

# Hide cursor during install to stop flickering
tput civis

# Restore cursor and files on exit
cleanup() {
    tput cnorm # Show cursor
    rm -f "$TMP_FILE" 2>/dev/null
    if [ -f "$BACKUP_FILE" ]; then
        sudo rm -f "$BACKUP_FILE" 2>/dev/null || true
    fi
}

# Handle Ctrl+C
ctrl_c() {
    tput cnorm
    echo -e "\n${RED} [ ✖ ] Cancelled by user.${NC}"
    cleanup
    exit 130
}

trap ctrl_c INT TERM
trap cleanup EXIT

# Draw the Header and Progress Bar at the Top
draw_header() {
    local percent=$1
    local bar_width=40
    local filled=$(( bar_width * percent / 100 ))
    local empty=$(( bar_width - filled ))
    
    # 1. Save current cursor position (where the list is)
    tput sc
    
    # 2. Jump to Top-Left (Line 0, Col 0) to draw header
    tput cup 0 0
    
    # 3. Draw the fixed header (Occupies 5 lines)
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}                Git Record Installer${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Draw Bar
    local bar=$(printf "%0.s=" $(seq 1 $filled))
    local space=$(printf "%0.s-" $(seq 1 $empty))
    
    echo -e " Progress: ${BLUE}[${bar}${CYAN}>${NC}${BLUE}${space}]${NC} ${percent}%"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 4. Restore cursor position (Back to the list)
    tput rc
}

# -----------------------------------------------------------------------------
# Task Runner
# -----------------------------------------------------------------------------

# Usage: run_task "Description" "Command"
run_task() {
    local desc="$1"
    local cmd="$2"

    # Update Progress
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    draw_header "$pct"

    # Print "Processing" (Blue)
    printf "${BLUE} [ .. ]${NC} %s" "$desc"

    # Run Command
    local output
    output=$(eval "$cmd" 2>&1)
    local status=$?

    # Small delay for visual smoothness
    sleep 0.3

    if [ $status -eq 0 ]; then
        # Success (Green) - \033[K clears the rest of the line
        printf "\r${GREEN} [ ✔ ]${NC} %s\033[K\n" "$desc"
    else
        # Failure (Red)
        printf "\r${RED} [ ✖ ]${NC} %s\033[K\n" "$desc"
        
        tput cnorm # Show cursor for error
        echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED} ERROR:${NC}"
        echo -e "${YELLOW}$output${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

clear

# IMPORTANT: Reserve space for the header!
# We print 5 blank lines so the cursor starts BELOW the header area.
echo -e "\n\n\n\n\n"

# Draw initial 0% header
draw_header "0"

# 1. Sudo Check
if [ "$EUID" -ne 0 ]; then
    # Manually update bar for this step
    CURRENT_STEP=1
    draw_header "$(( 1 * 100 / TOTAL_STEPS ))"

    printf "${BLUE} [ .. ]${NC} Checking permissions"
    if sudo -v 2>/dev/null; then
         printf "\r${GREEN} [ ✔ ]${NC} Permissions granted\033[K\n"
    else
         printf "\r${RED} [ ✖ ]${NC} Checking permissions\033[K\n"
         echo -e "${RED}      Error: Password required.${NC}"
         exit 1
    fi
else
    # Skip verification visually if already root
    run_task "Checking permissions" "true"
fi

# 2. Download
run_task "Downloading latest version" \
    "curl -fsSL '$REPO_SCRIPT' -o '$TMP_FILE' && [ -s '$TMP_FILE' ]"

# 3. Version Check
run_task "Checking for updates" \
    "[ -f '$TMP_FILE' ]"

NEW_HASH=$(sha256sum "$TMP_FILE" | cut -d ' ' -f1)
INSTALL_TYPE="FRESH"

if [ -f "$INSTALL_PATH" ]; then
    CURRENT_HASH=$(sha256sum "$INSTALL_PATH" | cut -d ' ' -f1)
    
    if [ "$NEW_HASH" = "$CURRENT_HASH" ]; then
        # Already Updated
        draw_header "100"
        printf "${GREEN} [ ✔ ]${NC} System is already up to date\n"
        
        rm -f "$TMP_FILE"
        echo -e "\n${GREEN} You have the latest version.${NC}\n"
        exit 0
    else
        INSTALL_TYPE="UPDATE"
    fi
fi

# 4. Backup (Only if updating)
if [ "$INSTALL_TYPE" = "UPDATE" ]; then
    run_task "Backing up old version" \
        "sudo cp '$INSTALL_PATH' '$BACKUP_FILE'"
else
    # Dummy step to keep bar smooth on fresh install
    run_task "Preparing installation" "true"
fi

# 5. Install
run_task "Installing to system" \
    "sudo mv -f '$TMP_FILE' '$INSTALL_PATH' && sudo chmod +x '$INSTALL_PATH'"

# 6. Final Cleanup
run_task "Cleaning up temporary files" \
    "rm -f '$TMP_FILE' && sudo rm -f '$BACKUP_FILE' 2>/dev/null"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
draw_header "100"
echo ""
echo -e " ${GREEN}✔ Installation Complete${NC}"
echo -e "   Run command: ${BOLD}git-record${NC}"
echo ""
