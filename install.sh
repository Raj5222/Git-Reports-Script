#!/usr/bin/env bash
# ==============================================================================
#  📘 GIT-RECORD MULTI-OS INSTALLER & UPDATER (Ubuntu, macOS, Windows)
# ==============================================================================

set -o pipefail

REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
TMP_FILE="/tmp/git-record-installer-$$"
BACKUP_FILE="/tmp/git-record-backup-$$"

TOTAL_STEPS=6
CURRENT_STEP=0

# Formatting
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Detect System & OS
detect_system() {
    OS_ARCH="$(uname -m 2>/dev/null || echo "x86_64")"
    local u_sys
    u_sys="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"

    if [[ "$u_sys" == "darwin"* ]]; then
        SYSTEM_TYPE="macos"
        SYSTEM_NAME="macOS ($(sw_vers -productVersion 2>/dev/null || echo "Darwin"))"
    elif [[ "$u_sys" == "linux"* ]]; then
        if grep -qi "microsoft" /proc/version 2>/dev/null || grep -qi "wsl" /proc/version 2>/dev/null; then
            SYSTEM_TYPE="wsl"
            SYSTEM_NAME="Windows WSL"
        else
            SYSTEM_TYPE="linux"
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                SYSTEM_NAME=$(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Linux")
            else
                SYSTEM_NAME="Linux"
            fi
        fi
    elif [[ "$u_sys" =~ (msys|mingw|cygwin) ]] || [ -n "$WINDIR" ] || [ -n "$COMSPEC" ]; then
        SYSTEM_TYPE="windows"
        SYSTEM_NAME="Windows (Git Bash/MSYS2)"
    else
        SYSTEM_TYPE="unix"
        SYSTEM_NAME="Unix-like"
    fi
}

detect_system

# SHA-256 hash helper compatible across GNU Linux, macOS (shasum), and Windows
calc_sha256() {
    local target="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target" 2>/dev/null | cut -d ' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target" 2>/dev/null | cut -d ' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$target" 2>/dev/null | awk '{print $NF}'
    else
        # Fallback to file size + line count if no hasher available
        wc -c < "$target" 2>/dev/null | tr -d ' '
    fi
}

# Determine default installation path based on OS
INSTALL_PATH="/usr/local/bin/git-record"
USE_SUDO=1

if [ "$SYSTEM_TYPE" = "windows" ]; then
    USE_SUDO=0
    if [ -d "/usr/bin" ] && [ -w "/usr/bin" ]; then
        INSTALL_PATH="/usr/bin/git-record"
    elif [ -d "$HOME/bin" ]; then
        INSTALL_PATH="$HOME/bin/git-record"
    else
        INSTALL_PATH="$HOME/.local/bin/git-record"
        mkdir -p "$HOME/.local/bin"
    fi
elif [ "$SYSTEM_TYPE" = "macos" ]; then
    if [ "$1" = "--user" ]; then
        INSTALL_PATH="$HOME/.local/bin/git-record"
        USE_SUDO=0
        mkdir -p "$HOME/.local/bin"
    elif [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
        INSTALL_PATH="/opt/homebrew/bin/git-record"
        USE_SUDO=0
    fi
else
    # Linux / Ubuntu
    if [ "$EUID" -eq 0 ]; then
        USE_SUDO=0
    elif [ "$1" = "--user" ] || [ ! -w "/usr/local/bin" ] && ! command -v sudo >/dev/null 2>&1; then
        INSTALL_PATH="$HOME/.local/bin/git-record"
        USE_SUDO=0
        mkdir -p "$HOME/.local/bin"
    fi
fi

# Hide cursor during progress
tput civis 2>/dev/null || true

cleanup() {
    tput cnorm 2>/dev/null || true
    rm -f "$TMP_FILE" 2>/dev/null || true
    if [ -f "$BACKUP_FILE" ]; then
        if [ "$USE_SUDO" -eq 1 ]; then
            sudo rm -f "$BACKUP_FILE" 2>/dev/null || rm -f "$BACKUP_FILE" 2>/dev/null || true
        else
            rm -f "$BACKUP_FILE" 2>/dev/null || true
        fi
    fi
}

ctrl_c() {
    tput cnorm 2>/dev/null || true
    echo -e "\n${RED} [ ✖ ] Cancelled by user.${NC}"
    cleanup
    exit 130
}

trap ctrl_c INT TERM
trap cleanup EXIT

draw_bar() {
    local count="$1"
    local char="${2:-"="}"
    if [ "$count" -gt 0 ]; then
        local res=""
        while [ "${#res}" -lt "$count" ]; do
            res="${res}${char}"
        done
        printf "%s" "${res:0:$count}"
    fi
}

draw_header() {
    local percent=$1
    local bar_width=36
    local filled=$(( bar_width * percent / 100 ))
    local empty=$(( bar_width - filled ))
    
    tput sc 2>/dev/null || true
    tput cup 0 0 2>/dev/null || true
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}         📘 Git Record Multi-OS Installer v2.0              ${NC}"
    echo -e "   Target System: ${GREEN}$SYSTEM_NAME ($OS_ARCH)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local bar
    bar=$(draw_bar "$filled" "=")
    local space
    space=$(draw_bar "$empty" "-")
    
    echo -e " Progress: ${BLUE}[${bar}${CYAN}>${NC}${BLUE}${space}]${NC} ${percent}%"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    tput rc 2>/dev/null || true
}

run_task() {
    local desc="$1"
    local cmd="$2"

    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    draw_header "$pct"

    printf "${BLUE} [ .. ]${NC} %s" "$desc"

    local output
    output=$(eval "$cmd" 2>&1)
    local status=$?

    sleep 0.2

    if [ $status -eq 0 ]; then
        printf "\r${GREEN} [ ✔ ]${NC} %s\033[K\n" "$desc"
    else
        printf "\r${RED} [ ✖ ]${NC} %s\033[K\n" "$desc"
        tput cnorm 2>/dev/null || true
        echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED} ERROR:${NC}"
        echo -e "${YELLOW}$output${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
}

clear 2>/dev/null || true
echo -e "\n\n\n\n\n\n"
draw_header "0"

# --- STEP 1: PERMISSIONS & ENVIRONMENT CHECK ---
CURRENT_STEP=1
draw_header "$(( 1 * 100 / TOTAL_STEPS ))"

if [ "$USE_SUDO" -eq 1 ]; then
    if sudo -n true 2>/dev/null; then
        printf "${GREEN} [ ✔ ]${NC} System permissions verified\n"
    else
        printf "${YELLOW} [ 🔑 ] Action Required: Enter sudo password${NC}"
        tput cnorm 2>/dev/null || true
        if sudo -v; then
            tput civis 2>/dev/null || true
            printf "\r${GREEN} [ ✔ ]${NC} System permissions verified\033[K\n"
        else
            tput civis 2>/dev/null || true
            printf "\r${RED} [ ✖ ]${NC} Authentication failed\033[K\n"
            exit 1
        fi
    fi
else
    printf "${GREEN} [ ✔ ]${NC} User permissions verified ($SYSTEM_NAME)\n"
fi

# --- STEP 2: SOURCE ACQUISITION ---
LOCAL_SCRIPT_SOURCE="$(dirname "$0")/git-records.sh"
if [ -f "$LOCAL_SCRIPT_SOURCE" ]; then
    run_task "Loading script from workspace" \
        "cp '$LOCAL_SCRIPT_SOURCE' '$TMP_FILE' && [ -s '$TMP_FILE' ]"
else
    run_task "Downloading latest release" \
        "curl -fsSL '$REPO_SCRIPT' -o '$TMP_FILE' && [ -s '$TMP_FILE' ]"
fi

# --- STEP 3: INTEGRITY & VERSION CHECK ---
run_task "Verifying package integrity" \
    "[ -f '$TMP_FILE' ] && head -n 1 '$TMP_FILE' | grep -q '#!/usr/bin/env bash'"

NEW_HASH=$(calc_sha256 "$TMP_FILE")
INSTALL_TYPE="FRESH"

if [ -f "$INSTALL_PATH" ]; then
    CURRENT_HASH=$(calc_sha256 "$INSTALL_PATH")
    if [ "$NEW_HASH" = "$CURRENT_HASH" ]; then
        draw_header "100"
        printf "${GREEN} [ ✔ ]${NC} git-record is already up to date\n"
        rm -f "$TMP_FILE"
        echo -e "\n${GREEN} You have the latest version installed at ${BOLD}$INSTALL_PATH${NC}\n"
        exit 0
    else
        INSTALL_TYPE="UPDATE"
    fi
fi

# --- STEP 4: BACKUP ---
if [ "$INSTALL_TYPE" = "UPDATE" ]; then
    if [ "$USE_SUDO" -eq 1 ]; then
        run_task "Backing up existing installation" \
            "sudo cp '$INSTALL_PATH' '$BACKUP_FILE'"
    else
        run_task "Backing up existing installation" \
            "cp '$INSTALL_PATH' '$BACKUP_FILE'"
    fi
else
    run_task "Preparing installation target" "true"
fi

# --- STEP 5: INSTALLATION ---
if [ "$USE_SUDO" -eq 1 ]; then
    run_task "Installing executable to $INSTALL_PATH" \
        "sudo mv -f '$TMP_FILE' '$INSTALL_PATH' && sudo chmod +x '$INSTALL_PATH'"
else
    run_task "Installing executable to $INSTALL_PATH" \
        "mv -f '$TMP_FILE' '$INSTALL_PATH' && chmod +x '$INSTALL_PATH'"
fi

# --- STEP 6: CLEANUP ---
run_task "Finalizing system configuration" \
    "rm -f '$TMP_FILE' 2>/dev/null"

# Done
draw_header "100"
echo ""
echo -e " ${GREEN}✔ Installation Complete!${NC}"
echo -e "   Target OS       : ${BOLD}$SYSTEM_NAME ($OS_ARCH)${NC}"
echo -e "   Executable path : ${BOLD}$INSTALL_PATH${NC}"
echo -e "   Run command     : ${CYAN}git-record${NC}  or  ${CYAN}git record${NC}"
echo ""
