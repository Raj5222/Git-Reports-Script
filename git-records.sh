#!/usr/bin/env bash
# ==============================================================================
#  📘 GIT-RECORD (Git Reports & Workflow Suite) v2.0.0
#  A modern, ultra-fast, safe, and beautiful Git branch manager & report suite.
# ==============================================================================

# Exit on unexpected pipeline failures, but allow controlled error handling
set -o pipefail

VERSION="2.0.0"

# ------------------------------------------------------------------------------
# ⚙️  DEFAULT CONFIGURATION & ENVIRONMENT OVERRIDES
# ------------------------------------------------------------------------------
DEFAULT_LIMIT=10
STALE_DAYS=90
CLEANUP_THRESHOLD=60
VELOCITY_DAYS=30
MAX_INTERVAL=3600
MIN_INTERVAL=1
DEFAULT_REFRESH_INTERVAL=5
USE_UNICODE=1
COLOR_MODE="auto" # auto | always | never

# Load user configuration if present
if [ -f "$HOME/.gitrecordrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.gitrecordrc" 2>/dev/null || true
fi
if [ -f ".gitrecord" ]; then
    # shellcheck source=/dev/null
    source ".gitrecord" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 🎨 COLOR PALETTE & TERMINAL CAPABILITIES
# ------------------------------------------------------------------------------
setup_colors() {
    # Check NO_COLOR env var (https://no-color.org/)
    if [ -n "$NO_COLOR" ] || [ "$COLOR_MODE" = "never" ] || { [ "$COLOR_MODE" = "auto" ] && [ ! -t 1 ]; }; then
        C_RESET=""
        C_BOLD=""
        C_DIM=""
        C_UNDERLINE=""
        C_RED=""
        C_GREEN=""
        C_YELLOW=""
        C_BLUE=""
        C_MAGENTA=""
        C_CYAN=""
        C_WHITE=""
        C_GRAY=""
        C_REPO=""
        C_CURRENT=""
        C_REMOTE=""
        C_REMOTE_TXT=""
        C_LOCAL=""
        C_AUTHOR=""
        C_TIME=""
        C_WARN=""
        C_BORDER=""
        C_HEADER=""
        C_BG_DARK=""
        C_SUCCESS=""
        C_MUTED=""
        return
    fi

    # ANSI Colors
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_UNDERLINE=$'\033[4m'

    # Standard colors
    C_RED=$'\033[38;5;196m'
    C_GREEN=$'\033[38;5;46m'
    C_YELLOW=$'\033[38;5;220m'
    C_BLUE=$'\033[38;5;39m'
    C_MAGENTA=$'\033[38;5;207m'
    C_CYAN=$'\033[38;5;45m'
    C_WHITE=$'\033[38;5;255m'
    C_GRAY=$'\033[38;5;244m'

    # Themed semantic colors
    C_REPO=$'\033[38;5;39m'
    C_CURRENT=$'\033[38;5;82m'
    C_REMOTE=$'\033[38;5;245m'
    C_REMOTE_TXT=$'\033[38;5;75m'
    C_LOCAL=$'\033[38;5;254m'
    C_AUTHOR=$'\033[38;5;215m'
    C_TIME=$'\033[38;5;117m'
    C_WARN=$'\033[38;5;208m'
    C_BORDER=$'\033[38;5;240m'
    C_HEADER=$'\033[38;5;251m'
    C_BG_DARK=$'\033[48;5;236m'
    C_SUCCESS=$'\033[38;5;48m'
    C_MUTED=$'\033[38;5;242m'
}

setup_icons() {
    # Check if terminal supports UTF-8
    if [ "$USE_UNICODE" -eq 1 ] && [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" =~ [uU][tT][fF]-?8 ]]; then
        ICON_REPO="📦"
        ICON_BRANCH="🌿"
        ICON_CURRENT="➜"
        ICON_STALE="⚠"
        ICON_TIP="💡"
        ICON_TEAM="👥"
        ICON_LOG="📜"
        ICON_SEARCH="🔍"
        ICON_AHEAD="↑"
        ICON_BEHIND="↓"
        ICON_TAG="🏷️"
        ICON_STASH="📥"
        ICON_STATS="📊"
        ICON_CLEANUP="🧹"
        ICON_GRAPH="📈"
        ICON_CONFLICT="⚔️"
        ICON_CI="🔧"
        ICON_GITHUB="🐙"
        ICON_GITLAB="🦊"
        ICON_CHECK="✔"
        ICON_CROSS="✖"
        ICON_WARN_TRI="⚠"
        ICON_DOT="●"
        ICON_CIRCLE="○"
        ICON_SYNC="🔄"
        ICON_LOCK="🔒"
        ICON_DIRTY="⚡"
        ICON_CLEAN="✨"
        ICON_WORKTREE="🌲"
        ICON_CLOCK="⏱"
        ICON_ROCKET="🚀"
        
        # Box drawing characters
        BOX_TL="┌"
        BOX_TR="┐"
        BOX_BL="└"
        BOX_BR="┘"
        BOX_H="─"
        BOX_V="│"
        BOX_TJ="┬"
        BOX_BJ="┴"
        BOX_LJ="├"
        BOX_RJ="┤"
        BOX_X="┼"
        BOX_ROUND_TL="╭"
        BOX_ROUND_TR="╮"
        BOX_ROUND_BL="╰"
        BOX_ROUND_BR="╯"
    else
        ICON_REPO="[REPO]"
        ICON_BRANCH="*"
        ICON_CURRENT="=>"
        ICON_STALE="!"
        ICON_TIP="i"
        ICON_TEAM="[TEAM]"
        ICON_LOG="[LOG]"
        ICON_SEARCH="[FIND]"
        ICON_AHEAD="^"
        ICON_BEHIND="v"
        ICON_TAG="[TAG]"
        ICON_STASH="[STASH]"
        ICON_STATS="[STATS]"
        ICON_CLEANUP="[CLEAN]"
        ICON_GRAPH="[GRAPH]"
        ICON_CONFLICT="[CONFLICT]"
        ICON_CI="[CI]"
        ICON_GITHUB="[GH]"
        ICON_GITLAB="[GL]"
        ICON_CHECK="v"
        ICON_CROSS="x"
        ICON_WARN_TRI="!"
        ICON_DOT="*"
        ICON_CIRCLE="o"
        ICON_SYNC="~"
        ICON_LOCK="[L]"
        ICON_DIRTY="*"
        ICON_CLEAN="="
        ICON_WORKTREE="[WT]"
        ICON_CLOCK="T:"
        ICON_ROCKET=">>"

        # ASCII Box characters
        BOX_TL="+"
        BOX_TR="+"
        BOX_BL="+"
        BOX_BR="+"
        BOX_H="-"
        BOX_V="|"
        BOX_TJ="+"
        BOX_BJ="+"
        BOX_LJ="+"
        BOX_RJ="+"
        BOX_X="+"
        BOX_ROUND_TL="+"
        BOX_ROUND_TR="+"
        BOX_ROUND_BL="+"
        BOX_ROUND_BR="+"
    fi
}

setup_colors
setup_icons

# ------------------------------------------------------------------------------
# 🛠️  FAST STRING & UI UTILITIES (Pure Bash - No Subshell Overhead)
# ------------------------------------------------------------------------------

# Strip ANSI codes for accurate width calculation
strip_ansi() {
    local text="$1"
    echo -e "$text" | sed -E $'s/\033\\[[0-9;]*[a-zA-Z]//g'
}

# Calculate visible length of text ignoring ANSI escape sequences
str_len() {
    local raw="$1"
    local clean
    clean=$(strip_ansi "$raw")
    echo "${#clean}"
}

# Repeat a character N times without seq/subshell loops
repeat_char() {
    local char="${1:-" "}"
    local count="${2:-0}"
    if [ "$count" -le 0 ]; then
        return
    fi
    local result=""
    while [ "${#result}" -lt "$count" ]; do
        result="${result}${char}"
    done
    printf "%s" "${result:0:$count}"
}

# Truncate string to max length with ellipsis if needed
truncate_str() {
    local str="$1"
    local max_len="$2"
    local raw_len
    raw_len=$(str_len "$str")
    if [ "$raw_len" -le "$max_len" ]; then
        echo "$str"
    else
        if [ "$max_len" -le 3 ]; then
            echo "${str:0:$max_len}"
        else
            local cut_len=$((max_len - 3))
            echo "${str:0:$cut_len}..."
        fi
    fi
}

# Print cell with exact padding and color
print_cell() {
    local txt="$1"
    local width="$2"
    local color="${3:-$C_RESET}"
    local align="${4:-left}" # left | right | center

    local vlen
    vlen=$(str_len "$txt")
    local pad=$((width - vlen))
    [ "$pad" -lt 0 ] && pad=0

    if [ "$align" = "right" ]; then
        repeat_char " " "$pad"
        printf "%b%s%b" "$color" "$txt" "${C_RESET}"
    elif [ "$align" = "center" ]; then
        local pad_left=$((pad / 2))
        local pad_right=$((pad - pad_left))
        repeat_char " " "$pad_left"
        printf "%b%s%b" "$color" "$txt" "${C_RESET}"
        repeat_char " " "$pad_right"
    else
        printf "%b%s%b" "$color" "$txt" "${C_RESET}"
        repeat_char " " "$pad"
    fi
}

# Draw horizontal visual progress bar
draw_bar() {
    local val="${1:-0}"
    local max="${2:-100}"
    local width="${3:-20}"
    local color="${4:-$C_GREEN}"
    local char="${5:-"█"}"

    [ "$max" -le 0 ] && max=1
    local filled=$(( val * width / max ))
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    local empty=$(( width - filled ))

    printf "%b" "$color"
    repeat_char "$char" "$filled"
    printf "%b" "$C_MUTED"
    repeat_char "░" "$empty"
    printf "%b" "$C_RESET"
}

# ------------------------------------------------------------------------------
# 📦 PROFESSIONAL BOXED MESSAGE & ERROR SYSTEM
# ------------------------------------------------------------------------------

render_error_box() {
    local message="$1"
    local hint="$2"
    local example="$3"

    local max_len=${#message}
    [ -n "$hint" ] && [ "${#hint}" -gt "$max_len" ] && max_len=${#hint}
    [ -n "$example" ] && [ "${#example}" -gt "$max_len" ] && max_len=${#example}

    # Inner content width: max_len + label prefix (" Message : ")
    local inner_width=$((max_len + 13))
    [ "$inner_width" -lt 55 ] && inner_width=55

    echo
    printf "  %b%s%s" "$C_RED" "$BOX_TL$BOX_H" " ERROR "
    local top_bar_len=$((inner_width - 8))
    repeat_char "$BOX_H" "$top_bar_len"
    printf "%s%b\n" "$BOX_TR" "$C_RESET"

    # Message
    local l1=" Message : $message"
    local p1=$((inner_width - ${#l1}))
    [ "$p1" -lt 0 ] && p1=0
    printf "  %b%s%b%s" "$C_RED$BOX_V" "$C_RESET" "$l1"
    repeat_char " " "$p1"
    printf "%b%s%b\n" "$C_RED" "$BOX_V" "$C_RESET"

    # Hint
    if [ -n "$hint" ]; then
        local l2=" Hint    : $hint"
        local p2=$((inner_width - ${#l2}))
        [ "$p2" -lt 0 ] && p2=0
        printf "  %b%s%b%s" "$C_RED$BOX_V" "$C_DIM" "$l2"
        repeat_char " " "$p2"
        printf "%b%s%b\n" "$C_RED" "$BOX_V" "$C_RESET"
    fi

    # Example
    if [ -n "$example" ]; then
        local l3=" Example : $example"
        local p3=$((inner_width - ${#l3}))
        [ "$p3" -lt 0 ] && p3=0
        printf "  %b%s%b%s" "$C_RED$BOX_V" "$C_YELLOW" "$l3"
        repeat_char " " "$p3"
        printf "%b%s%b\n" "$C_RED" "$BOX_V" "$C_RESET"
    fi

    # Bottom
    printf "  %b%s" "$C_RED" "$BOX_BL"
    repeat_char "$BOX_H" "$inner_width"
    printf "%s%b\n\n" "$BOX_BR" "$C_RESET"

    exit 1
}

print_success() {
    echo -e "  ${C_SUCCESS}${ICON_CHECK}  $1${C_RESET}"
}

print_warn() {
    echo -e "  ${C_WARN}${ICON_WARN_TRI}  $1${C_RESET}"
}

print_info() {
    echo -e "  ${C_CYAN}${ICON_TIP}  $1${C_RESET}"
}

# ------------------------------------------------------------------------------
# 💻 CROSS-PLATFORM SYSTEM & OS DISCOVERY (Ubuntu, macOS, Windows)
# ------------------------------------------------------------------------------

detect_os_environment() {
    OS_ARCH="$(uname -m 2>/dev/null || echo "unknown")"
    local u_sys
    u_sys="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"

    if [[ "$u_sys" == "darwin"* ]]; then
        OS_TYPE="macos"
        local mac_ver mac_build
        mac_ver=$(sw_vers -productVersion 2>/dev/null || echo "")
        mac_build=$(sw_vers -buildVersion 2>/dev/null || echo "")
        if [ -n "$mac_ver" ]; then
            OS_NAME="macOS $mac_ver ($mac_build)"
        else
            OS_NAME="macOS (Darwin $(uname -r 2>/dev/null))"
        fi
    elif [[ "$u_sys" == "linux"* ]]; then
        if grep -qi "microsoft" /proc/version 2>/dev/null || grep -qi "wsl" /proc/version 2>/dev/null; then
            OS_TYPE="windows_wsl"
            local distro="Linux"
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                distro=$(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Linux")
            fi
            OS_NAME="Windows WSL ($distro)"
        else
            OS_TYPE="linux"
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                OS_NAME=$(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Linux")
            elif command -v lsb_release >/dev/null 2>&1; then
                OS_NAME=$(lsb_release -ds 2>/dev/null || echo "Linux")
            else
                OS_NAME="Linux $(uname -r 2>/dev/null)"
            fi
        fi
    elif [[ "$u_sys" =~ (msys|mingw|cygwin) ]] || [ -n "$WINDIR" ] || [ -n "$COMSPEC" ]; then
        OS_TYPE="windows"
        local win_ver=""
        if command -v cmd.exe >/dev/null 2>&1; then
            win_ver=$(cmd.exe /c "ver" 2>/dev/null | tr -d '\r\n' | sed 's/^[[:space:]]*//')
        fi
        [ -z "$win_ver" ] && win_ver="Windows (Git Bash/MinGW)"
        OS_NAME="$win_ver"
    else
        OS_TYPE="unix"
        OS_NAME="$(uname -s 2>/dev/null || echo "Unix") $(uname -r 2>/dev/null || echo "")"
    fi
}

get_past_date() {
    local days="${1:-30}"
    local fmt="${2:-"%Y-%m-%d"}"

    # 1. Try GNU date (Ubuntu, Linux, Git Bash)
    local gnu_res
    gnu_res=$(date -d "$days days ago" "+$fmt" 2>/dev/null)
    if [ -n "$gnu_res" ]; then
        echo "$gnu_res"
        return
    fi

    # 2. Try BSD date (macOS, FreeBSD)
    local bsd_res
    bsd_res=$(date -v-"${days}"d "+$fmt" 2>/dev/null)
    if [ -n "$bsd_res" ]; then
        echo "$bsd_res"
        return
    fi

    # 3. Epoch fallback arithmetic
    local now_epoch target_epoch
    now_epoch=$(date +%s 2>/dev/null || echo 0)
    target_epoch=$(( now_epoch - (days * 86400) ))
    
    local epoch_res
    epoch_res=$(date -d "@$target_epoch" "+$fmt" 2>/dev/null || date -r "$target_epoch" "+$fmt" 2>/dev/null)
    if [ -n "$epoch_res" ]; then
        echo "$epoch_res"
        return
    fi

    echo "$days days ago"
}

get_clipboard_tool_name() {
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
        echo "wl-copy (Wayland)"
    elif command -v pbcopy >/dev/null 2>&1; then
        echo "pbcopy (macOS)"
    elif command -v xclip >/dev/null 2>&1; then
        echo "xclip (X11)"
    elif command -v xsel >/dev/null 2>&1; then
        echo "xsel (X11)"
    elif command -v clip.exe >/dev/null 2>&1; then
        echo "clip.exe (Windows)"
    elif command -v powershell.exe >/dev/null 2>&1; then
        echo "PowerShell Set-Clipboard (Windows)"
    elif [ -t 1 ]; then
        echo "OSC 52 (ANSI Terminal Escape)"
    else
        echo "none (console fallback)"
    fi
}

action_sys_info() {
    detect_os_environment
    local clip_tool
    clip_tool=$(get_clipboard_tool_name)
    local git_ver
    git_ver=$(git --version 2>/dev/null || echo "not found")
    local bash_ver
    bash_ver="${BASH_VERSION:-unknown}"
    local cols_detected
    cols_detected=$(tput cols 2>/dev/null || echo "100")
    local term_info="${TERM:-dumb} (${cols_detected} cols)"

    local fzf_stat="Not installed (using built-in menu)"
    command -v fzf >/dev/null 2>&1 && fzf_stat="Available (interactive fuzzy search)"
    local jq_stat="Not installed"
    command -v jq >/dev/null 2>&1 && jq_stat="Available (REST API JSON parser)"
    local gh_stat="Not installed"
    command -v gh >/dev/null 2>&1 && gh_stat="Available (GitHub CLI integration)"
    local glab_stat="Not installed"
    command -v glab >/dev/null 2>&1 && glab_stat="Available (GitLab CLI integration)"

    local box_width=68

    echo
    printf "  %b%s%s" "$C_CYAN" "$BOX_TL$BOX_H" " SYSTEM & PLATFORM DIAGNOSTICS "
    repeat_char "$BOX_H" $((box_width - 34))
    printf "%s%b\n" "$BOX_TR" "$C_RESET"

    print_diag_line() {
        local label="$1"
        local val="$2"
        local color="${3:-"$C_WHITE"}"
        local label_padded
        label_padded=$(printf "%-22s" "$label")
        local content_str="  ${label_padded} : ${val}"
        local raw_len=${#content_str}
        local pad=$((box_width - raw_len))
        [ "$pad" -lt 0 ] && pad=0

        printf "  %b%s%b  %-22s : %b%s%b" "$C_CYAN" "$BOX_V" "$C_RESET" "$label" "$color" "$val" "$C_RESET"
        repeat_char " " "$pad"
        printf "%b%s%b\n" "$C_CYAN" "$BOX_V" "$C_RESET"
    }

    print_diag_line "Operating System" "$OS_NAME" "$C_BOLD$C_WHITE"
    print_diag_line "Platform / Arch" "$OS_TYPE ($OS_ARCH)" "$C_CYAN"
    print_diag_line "Shell Version" "Bash $bash_ver" "$C_RESET"
    print_diag_line "Git Binary" "$git_ver" "$C_RESET"
    print_diag_line "Terminal Environment" "$term_info" "$C_RESET"
    print_diag_line "Clipboard Engine" "$clip_tool" "$C_GREEN"
    print_diag_line "FZF Fuzzy Engine" "$fzf_stat" "$([ "$fzf_stat" != "Not installed (using built-in menu)" ] && echo "$C_GREEN" || echo "$C_DIM")"
    print_diag_line "JSON Parser (jq)" "$jq_stat" "$([ "$jq_stat" != "Not installed" ] && echo "$C_GREEN" || echo "$C_DIM")"
    print_diag_line "GitHub CLI (gh)" "$gh_stat" "$([ "$gh_stat" != "Not installed" ] && echo "$C_GREEN" || echo "$C_DIM")"
    print_diag_line "GitLab CLI (glab)" "$glab_stat" "$([ "$glab_stat" != "Not installed" ] && echo "$C_GREEN" || echo "$C_DIM")"

    printf "  %b%s" "$C_CYAN" "$BOX_BL"
    repeat_char "$BOX_H" "$box_width"
    printf "%s%b\n\n" "$BOX_BR" "$C_RESET"
}

# ------------------------------------------------------------------------------
# 📋 SYSTEM CLIPBOARD COPYING (Multi-Platform with OSC 52 Fallback)
# ------------------------------------------------------------------------------
copy_to_clipboard() {
    local text="$1"

    # Wayland (Ubuntu / Linux)
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$text" | wl-copy
        return 0
    fi

    # macOS (Darwin)
    if command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$text" | pbcopy
        return 0
    fi

    # X11 xclip (Ubuntu / Debian / Linux)
    if command -v xclip >/dev/null 2>&1; then
        printf "%s" "$text" | xclip -selection clipboard 2>/dev/null
        return 0
    fi

    # X11 xsel (Ubuntu / Linux)
    if command -v xsel >/dev/null 2>&1; then
        printf "%s" "$text" | xsel --clipboard --input 2>/dev/null
        return 0
    fi

    # Windows clip.exe (Git Bash / MSYS2 / WSL)
    if command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe 2>/dev/null
        return 0
    fi

    # Windows PowerShell fallback
    if command -v powershell.exe >/dev/null 2>&1; then
        printf "%s" "$text" | powershell.exe -NoProfile -NonInteractive -Command "\$Input | Set-Clipboard" 2>/dev/null
        return 0
    fi

    # OSC 52 terminal copy fallback (works over SSH and in modern terminals on Windows/Mac/Linux)
    if [ -t 1 ]; then
        local b64
        b64=$(printf "%s" "$text" | base64 2>/dev/null | tr -d '\r\n')
        if [ -n "$b64" ]; then
            printf "\033]52;c;%s\007" "$b64"
            return 0
        fi
    fi

    return 1
}

# ------------------------------------------------------------------------------
# 🔍 REPOSITORY & GIT ENVIRONMENT DISCOVERY
# ------------------------------------------------------------------------------
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        render_error_box "Not a Git repository" "Run this command inside an active Git project" "cd /path/to/project && git-record"
    fi
}

detect_primary_branch() {
    local base=""
    # Check origin/HEAD symref
    base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -n "$base" ]; then
        echo "$base"
        return
    fi
    # Check common branch names
    for b in main master trunk develop; do
        if git show-ref --verify --quiet "refs/heads/$b" || git show-ref --verify --quiet "refs/remotes/origin/$b"; then
            echo "$b"
            return
        fi
    done
    echo "main"
}

get_repo_info() {
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    REPO_NAME=$(basename "$REPO_ROOT")
    CUR_BRANCH=$(git branch --show-current 2>/dev/null)
    
    # Handle detached HEAD or rebasing state
    if [ -z "$CUR_BRANCH" ]; then
        local head_commit
        head_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        CUR_BRANCH="(detached at $head_commit)"
    fi

    # Working tree status
    local dirty_count
    dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty_count" -gt 0 ]; then
        IS_DIRTY=1
        STATUS_BADGE="${C_YELLOW}${ICON_DIRTY} $dirty_count modified${C_RESET}"
    else
        IS_DIRTY=0
        STATUS_BADGE="${C_GREEN}${ICON_CLEAN} clean${C_RESET}"
    fi

    # Stash count
    STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

    # Local & remote branch counts
    COUNT_LOCAL=$(git for-each-ref --format='%(refname)' refs/heads 2>/dev/null | wc -l | tr -d ' ')
    COUNT_REMOTE=$(git for-each-ref --format='%(refname)' refs/remotes 2>/dev/null | grep -v "/HEAD$" | wc -l | tr -d ' ')
    PRIMARY_BRANCH=$(detect_primary_branch)
}

# ------------------------------------------------------------------------------
# 🌐 REMOTE PLATFORM & CI/CD HELPERS (GitHub / GitLab / CLI Native)
# ------------------------------------------------------------------------------

detect_remote_platform() {
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null)
    [ -z "$remote_url" ] && return 1

    if [[ "$remote_url" =~ github\.com ]] || [[ "$remote_url" =~ github ]]; then
        echo "github"
    elif [[ "$remote_url" =~ gitlab ]]; then
        echo "gitlab"
    else
        return 1
    fi
}

get_github_token() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN"
    elif [ -n "$GH_TOKEN" ]; then
        echo "$GH_TOKEN"
    else
        git config --global github.token 2>/dev/null || git config github.token 2>/dev/null
    fi
}

get_gitlab_token() {
    if [ -n "$GITLAB_TOKEN" ]; then
        echo "$GITLAB_TOKEN"
    elif [ -n "$GL_TOKEN" ]; then
        echo "$GL_TOKEN"
    else
        git config --global gitlab.token 2>/dev/null || git config gitlab.token 2>/dev/null
    fi
}

parse_github_repo() {
    local url
    url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    fi
}

parse_gitlab_repo() {
    local url
    url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ gitlab.*[:/]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    elif [[ "$url" =~ [:/]([^/]+)/([^/.]+)\.git ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
}

get_gitlab_domain() {
    local url
    url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ ^https?://([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$url" =~ @([^:]+): ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "gitlab.com"
    fi
}

# Format seconds into compact human-readable duration
format_duration() {
    local seconds="${1:-0}"
    seconds="${seconds%%.*}"
    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        echo "-"
        return
    fi
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m"
    fi
}

# ------------------------------------------------------------------------------
# 📊 DATA ENGINE (One-Pass, High-Performance Ref Scanner)
# ------------------------------------------------------------------------------

declare -a ROWS_ID ROWS_BRANCH_TEXT ROWS_BRANCH_REF ROWS_HASH ROWS_DATE ROWS_AUTHOR ROWS_AGE_RAW ROWS_MESSAGE ROWS_AHEAD ROWS_BEHIND ROWS_TYPE

load_records() {
    check_git_repo
    get_repo_info

    # Reset data arrays
    ROWS_ID=()
    ROWS_BRANCH_TEXT=()
    ROWS_BRANCH_REF=()
    ROWS_HASH=()
    ROWS_DATE=()
    ROWS_AUTHOR=()
    ROWS_AGE_RAW=()
    ROWS_MESSAGE=()
    ROWS_AHEAD=()
    ROWS_BEHIND=()
    ROWS_TYPE=()

    count=0
    local term_cols
    term_cols=$(tput cols 2>/dev/null || echo 100)
    [ "$term_cols" -lt 60 ] && term_cols=60

    # Initial column widths
    W_ID=4
    W_TYPE=6
    W_BRANCH=15
    W_STATUS=5
    W_HASH=8
    W_DATE=13
    W_AUTHOR=12

    if [ "$MODE" = "HISTORY" ]; then
        # History Mode (Direct commit logs)
        while IFS='|' read -r hash shorthash date author ts msg; do
            [ -z "$hash" ] && continue
            count=$((count + 1))
            ROWS_ID[$count]="$count"
            ROWS_TYPE[$count]="COMMIT"
            ROWS_BRANCH_TEXT[$count]="$msg"
            ROWS_BRANCH_REF[$count]="commit/$hash"
            ROWS_HASH[$count]="$shorthash"
            ROWS_DATE[$count]="$date"
            ROWS_AUTHOR[$count]="$author"
            ROWS_AGE_RAW[$count]="$ts"
            ROWS_MESSAGE[$count]="$msg"
            ROWS_AHEAD[$count]="-"
            ROWS_BEHIND[$count]="-"

            [ "${#count}" -gt "$W_ID" ] && W_ID=${#count}
            [ "${#msg}" -gt "$W_BRANCH" ] && W_BRANCH=${#msg}
            [ "${#shorthash}" -gt "$W_HASH" ] && W_HASH=${#shorthash}
            [ "${#date}" -gt "$W_DATE" ] && W_DATE=${#date}
            [ "${#author}" -gt "$W_AUTHOR" ] && W_AUTHOR=${#author}

            [ "$LIMIT" -gt 0 ] && [ "$count" -ge "$LIMIT" ] && break
        done < <(git log --format='%H|%h|%cr|%an|%ct|%s' -n "${LIMIT:-50}" 2>/dev/null)

    elif [ "$MODE" = "CODE_SEARCH" ]; then
        # Code search mode across branches
        echo -e "  ${C_CYAN}${ICON_SEARCH} Searching branch commits for '${C_BOLD}$FILTER_CODE${C_RESET}${C_CYAN}'...${C_RESET}\n"
        local matched_refs=()
        while IFS= read -r ref; do
            [ -z "$ref" ] && continue
            if git grep -q -I "$FILTER_CODE" "$ref" 2>/dev/null; then
                matched_refs+=("$ref")
                [ "$LIMIT" -gt 0 ] && [ "${#matched_refs[@]}" -ge "$LIMIT" ] && break
            fi
        done < <(git for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null | grep -v "/HEAD$")

        if [ "${#matched_refs[@]}" -eq 0 ]; then
            render_error_box "No matches found" "No branches contain text: '$FILTER_CODE'" "git-record -S \"function_name\""
        fi

        for fullref in "${matched_refs[@]}"; do
            local short_branch="${fullref#refs/heads/}"
            short_branch="${short_branch#refs/remotes/}"
            local btype="LOCAL"
            [[ "$fullref" == refs/remotes/* ]] && btype="REMOTE"

            IFS='|' read -r hash shorthash date author ts msg < <(git show -s --format='%H|%h|%cr|%an|%ct|%s' "$fullref" 2>/dev/null)
            count=$((count + 1))
            ROWS_ID[$count]="$count"
            ROWS_TYPE[$count]="$btype"
            ROWS_BRANCH_TEXT[$count]="$short_branch"
            ROWS_BRANCH_REF[$count]="$fullref"
            ROWS_HASH[$count]="$shorthash"
            ROWS_DATE[$count]="$date"
            ROWS_AUTHOR[$count]="$author"
            ROWS_AGE_RAW[$count]="$ts"
            ROWS_MESSAGE[$count]="$msg"
            ROWS_AHEAD[$count]="-"
            ROWS_BEHIND[$count]="-"

            [ "${#count}" -gt "$W_ID" ] && W_ID=${#count}
            [ "${#short_branch}" -gt "$W_BRANCH" ] && W_BRANCH=${#short_branch}
            [ "${#shorthash}" -gt "$W_HASH" ] && W_HASH=${#shorthash}
            [ "${#date}" -gt "$W_DATE" ] && W_DATE=${#date}
            [ "${#author}" -gt "$W_AUTHOR" ] && W_AUTHOR=${#author}
        done

    else
        # Standard Branch Mode (Local & Remote with Ahead/Behind Tracking)
        local ref_patterns=()
        if [ "$ONLY_LOCAL" -eq 1 ]; then
            ref_patterns=("refs/heads")
        elif [ "$ONLY_REMOTE" -eq 1 ]; then
            ref_patterns=("refs/remotes")
        else
            ref_patterns=("refs/heads" "refs/remotes")
        fi

        while IFS='|' read -r fullref short_branch shorthash date author ts msg upstream track; do
            [ -z "$fullref" ] && continue
            [[ "$fullref" == */HEAD ]] && continue

            # Apply name/author/message filter if requested
            if [ -n "$FILTER_NAME" ]; then
                local search_haystack="$short_branch $author $msg"
                if [[ ! "$search_haystack" =~ $FILTER_NAME ]]; then
                    continue
                fi
            fi

            local btype="LOCAL"
            if [[ "$fullref" == refs/remotes/* ]]; then
                btype="REMOTE"
            fi

            # Calculate push/pull ahead/behind status
            local ahead_count=0
            local behind_count=0
            if [ -n "$upstream" ]; then
                if [[ "$track" =~ ahead\ ([0-9]+) ]]; then
                    ahead_count="${BASH_REMATCH[1]}"
                fi
                if [[ "$track" =~ behind\ ([0-9]+) ]]; then
                    behind_count="${BASH_REMATCH[1]}"
                fi
            fi

            count=$((count + 1))
            ROWS_ID[$count]="$count"
            ROWS_TYPE[$count]="$btype"
            ROWS_BRANCH_TEXT[$count]="$short_branch"
            ROWS_BRANCH_REF[$count]="$fullref"
            ROWS_HASH[$count]="$shorthash"
            ROWS_DATE[$count]="$date"
            ROWS_AUTHOR[$count]="$author"
            ROWS_AGE_RAW[$count]="$ts"
            ROWS_MESSAGE[$count]="$msg"
            ROWS_AHEAD[$count]="ahead_count"
            ROWS_AHEAD[$count]="$ahead_count"
            ROWS_BEHIND[$count]="$behind_count"

            [ "${#count}" -gt "$W_ID" ] && W_ID=${#count}
            [ "${#short_branch}" -gt "$W_BRANCH" ] && W_BRANCH=${#short_branch}
            [ "${#shorthash}" -gt "$W_HASH" ] && W_HASH=${#shorthash}
            [ "${#date}" -gt "$W_DATE" ] && W_DATE=${#date}
            [ "${#author}" -gt "$W_AUTHOR" ] && W_AUTHOR=${#author}

            [ "$LIMIT" -gt 0 ] && [ "$count" -ge "$LIMIT" ] && break
        done < <(git for-each-ref --sort=-committerdate --format='%(refname)|%(refname:short)|%(objectname:short)|%(committerdate:relative)|%(authorname)|%(committerdate:unix)|%(subject)|%(upstream)|%(upstream:track)' "${ref_patterns[@]}" 2>/dev/null)
    fi

    TOTAL_VISIBLE=$count

    # Max bound adjustments
    [ "$W_BRANCH" -gt 45 ] && W_BRANCH=45
    [ "$W_AUTHOR" -gt 20 ] && W_AUTHOR=20
    [ "$W_DATE" -gt 18 ] && W_DATE=18

    # Pad column widths for spacing
    W_ID=$((W_ID + 2))
    W_TYPE=$((W_TYPE + 2))
    W_BRANCH=$((W_BRANCH + 3))
    W_STATUS=$((W_STATUS + 2))
    W_HASH=$((W_HASH + 2))
    W_DATE=$((W_DATE + 2))
    W_AUTHOR=$((W_AUTHOR + 2))
}

# ------------------------------------------------------------------------------
# 🖥️ TABLE RENDERING ENGINE (Responsive, Auto-Fit & Beautiful Borders)
# ------------------------------------------------------------------------------

render_table() {
    if [ "$TOTAL_VISIBLE" -eq 0 ]; then
        echo
        print_warn "No branches or records matched your criteria."
        echo
        return
    fi

    local now_ts
    now_ts=$(date +%s)
    local stale_sec=$((STALE_DAYS * 86400))

    # Header Card
    echo
    printf "  %b%s %b%s%b   %s %b%s%b   %s %s\n" \
        "$C_BOLD$C_REPO" "$ICON_REPO" "$C_WHITE" "${REPO_NAME^^}" "$C_RESET" \
        "$ICON_BRANCH" "$C_CURRENT$C_BOLD" "$CUR_BRANCH" "$C_RESET" \
        "$STATUS_BADGE" "$([ "$STASH_COUNT" -gt 0 ] && echo "${C_DIM}• $ICON_STASH $STASH_COUNT stashed${C_RESET}")"

    printf "  %bLocal: %s   Remote: %s   Total Shown: %s/%s%b\n" \
        "$C_DIM" "$COUNT_LOCAL" "$COUNT_REMOTE" "$TOTAL_VISIBLE" "$((COUNT_LOCAL + COUNT_REMOTE))" "$C_RESET"
    echo

    # Top border
    printf "  %b%s" "$C_BORDER" "$BOX_TL"
    repeat_char "$BOX_H" $W_ID; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_TYPE; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_BRANCH; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_STATUS; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_HASH; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_DATE; printf "%s" "$BOX_TJ"
    repeat_char "$BOX_H" $W_AUTHOR; printf "%s%b\n" "$BOX_TR" "$C_RESET"

    # Column Headers
    local branch_header_title="BRANCH NAME"
    [ "$MODE" = "HISTORY" ] && branch_header_title="COMMIT MESSAGE"

    printf "  %b%s" "$C_BORDER" "$BOX_V"
    print_cell " NO " "$W_ID" "$C_HEADER$C_BOLD" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " TYPE " "$W_TYPE" "$C_HEADER$C_BOLD" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " $branch_header_title " "$W_BRANCH" "$C_HEADER$C_BOLD" "left"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " SYNC " "$W_STATUS" "$C_HEADER$C_BOLD" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " COMMIT " "$W_HASH" "$C_HEADER$C_BOLD" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " LAST UPDATED " "$W_DATE" "$C_HEADER$C_BOLD" "left"; printf "%b%s" "$C_BORDER" "$BOX_V"
    print_cell " AUTHOR " "$W_AUTHOR" "$C_HEADER$C_BOLD" "left"; printf "%b%s%b\n" "$C_BORDER" "$BOX_V" "$C_RESET"

    # Header Separator
    printf "  %b%s" "$C_BORDER" "$BOX_LJ"
    repeat_char "$BOX_H" $W_ID; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_TYPE; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_BRANCH; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_STATUS; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_HASH; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_DATE; printf "%s" "$BOX_X"
    repeat_char "$BOX_H" $W_AUTHOR; printf "%s%b\n" "$BOX_RJ" "$C_RESET"

    # Data Rows
    for ((i=1; i<=TOTAL_VISIBLE; i++)); do
        local id="${ROWS_ID[$i]}"
        local btype="${ROWS_TYPE[$i]}"
        local btext="${ROWS_BRANCH_TEXT[$i]}"
        local bref="${ROWS_BRANCH_REF[$i]}"
        local bhash="${ROWS_HASH[$i]}"
        local bdate="${ROWS_DATE[$i]}"
        local bauthor="${ROWS_AUTHOR[$i]}"
        local bts="${ROWS_AGE_RAW[$i]}"
        local ahead="${ROWS_AHEAD[$i]}"
        local behind="${ROWS_BEHIND[$i]}"

        local is_current=0
        if [ "$btext" = "$CUR_BRANCH" ] && [ "$MODE" != "HISTORY" ]; then
            is_current=1
        fi

        # Sync Status formatting
        local sync_str="-"
        local sync_color="$C_MUTED"
        if [ "$ahead" != "-" ] && [ "$behind" != "-" ]; then
            if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                sync_str="${ICON_AHEAD}${ahead}${ICON_BEHIND}${behind}"
                sync_color="$C_YELLOW"
            elif [ "$ahead" -gt 0 ]; then
                sync_str="${ICON_AHEAD}${ahead}"
                sync_color="$C_GREEN"
            elif [ "$behind" -gt 0 ]; then
                sync_str="${ICON_BEHIND}${behind}"
                sync_color="$C_RED"
            else
                sync_str="${ICON_CHECK}"
                sync_color="$C_GREEN"
            fi
        fi

        # Row styling
        local row_id_col="$C_DIM"
        local row_branch_col="$C_LOCAL"
        local row_type_col="$C_GRAY"
        local row_hash_col="$C_CYAN"
        local row_date_col="$C_TIME"
        local row_author_col="$C_AUTHOR"

        local branch_display="$btext"
        if [ "$is_current" -eq 1 ]; then
            row_id_col="$C_CURRENT$C_BOLD"
            row_type_col="$C_CURRENT$C_BOLD"
            row_branch_col="$C_CURRENT$C_BOLD"
            row_hash_col="$C_CURRENT"
            row_date_col="$C_CURRENT"
            row_author_col="$C_CURRENT"
            branch_display="${ICON_CURRENT} ${btext}"
        elif [ "$btype" = "REMOTE" ]; then
            row_type_col="$C_MUTED"
            row_branch_col="$C_REMOTE"
            if [[ "$btext" == origin/* ]]; then
                branch_display="origin/${C_REMOTE_TXT}${btext#origin/}${C_REMOTE}"
            fi
        elif [ "$btype" = "LOCAL" ]; then
            row_type_col="$C_CYAN"
            if [ $((now_ts - bts)) -gt "$stale_sec" ]; then
                row_branch_col="$C_WARN"
                branch_display="${ICON_STALE} ${btext}"
            fi
        fi

        # Truncate branch name to fit cell safely
        local max_branch_chars=$((W_BRANCH - 2))
        local clean_branch_len
        clean_branch_len=$(str_len "$branch_display")
        if [ "$clean_branch_len" -gt "$max_branch_chars" ]; then
            branch_display=$(truncate_str "$branch_display" "$max_branch_chars")
        fi

        # Print row
        printf "  %b%s" "$C_BORDER" "$BOX_V"
        print_cell " $id " "$W_ID" "$row_id_col" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $btype " "$W_TYPE" "$row_type_col" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $branch_display " "$W_BRANCH" "$row_branch_col" "left"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $sync_str " "$W_STATUS" "$sync_color" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $bhash " "$W_HASH" "$row_hash_col" "center"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $bdate " "$W_DATE" "$row_date_col" "left"; printf "%b%s" "$C_BORDER" "$BOX_V"
        print_cell " $bauthor " "$W_AUTHOR" "$row_author_col" "left"; printf "%b%s%b\n" "$C_BORDER" "$BOX_V" "$C_RESET"
    done

    # Bottom border
    printf "  %b%s" "$C_BORDER" "$BOX_BL"
    repeat_char "$BOX_H" $W_ID; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_TYPE; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_BRANCH; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_STATUS; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_HASH; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_DATE; printf "%s" "$BOX_BJ"
    repeat_char "$BOX_H" $W_AUTHOR; printf "%s%b\n" "$BOX_BR" "$C_RESET"
}

print_command_center() {
    echo
    printf "  %b%s QUICK WORKFLOW ACTIONS%b\n" "$C_BOLD$C_CYAN" "$ICON_ROCKET" "$C_RESET"
    printf "  %b%-28s  %-28s  %-28s%b\n" "$C_HEADER" "🌿 WORKFLOW" "🔍 INSPECT" "📊 ANALYTICS & CI" "$C_RESET"
    printf "  %b%-28s  %-28s  %-28s%b\n" "$C_MUTED" "git-record -c <ID>  (Checkout)" "git-record -s <ID>  (Show)" "git-record -X <ID>  (Stats)" "$C_RESET"
    printf "  %b%-28s  %-28s  %-28s%b\n" "$C_MUTED" "git-record -m <ID>  (Merge)" "git-record -C <A:B> (Compare)" "git-record -V       (Velocity)" "$C_RESET"
    printf "  %b%-28s  %-28s  %-28s%b\n" "$C_MUTED" "git-record -d <ID>  (Delete)" "git-record -M <ID>  (Conflicts)" "git-record -G       (Graph)" "$C_RESET"
    printf "  %b%-28s  %-28s  %-28s%b\n" "$C_MUTED" "git-record -b <IDs> (Bulk Del)" "git-record -k <ID>  (Copy Hash)" "git-record -N <ID>  (CI Status)" "$C_RESET"
    echo
    printf "  %bUse %bgit-record -h%b for full manual  |  %bgit-record -i%b for interactive menu%b\n\n" \
        "$C_DIM" "$C_CYAN" "$C_DIM" "$C_CYAN" "$C_DIM" "$C_RESET"
}

# ------------------------------------------------------------------------------
# 🚀 CORE WORKFLOW ACTIONS (Checkout, Merge, Delete, Bulk Delete, Rename)
# ------------------------------------------------------------------------------

RESOLVED_BRANCH=""
RESOLVED_REF=""
RESOLVED_HASH=""

resolve_branch_target() {
    local input="$1"
    local flag_name="${2:-target}"
    RESOLVED_BRANCH=""
    RESOLVED_REF=""
    RESOLVED_HASH=""

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        if [ "$input" -ge 1 ] && [ "$input" -le "$TOTAL_VISIBLE" ]; then
            RESOLVED_BRANCH="${ROWS_BRANCH_TEXT[$input]}"
            RESOLVED_REF="${ROWS_BRANCH_REF[$input]}"
            RESOLVED_HASH="${ROWS_HASH[$input]}"
            return 0
        else
            render_error_box "Branch ID out of range: $input" "Select an ID between 1 and $TOTAL_VISIBLE" "git-record $flag_name 1"
        fi
    else
        # Match by branch name in loaded records
        for ((i=1; i<=TOTAL_VISIBLE; i++)); do
            if [ "${ROWS_BRANCH_TEXT[$i]}" = "$input" ]; then
                RESOLVED_BRANCH="${ROWS_BRANCH_TEXT[$i]}"
                RESOLVED_REF="${ROWS_BRANCH_REF[$i]}"
                RESOLVED_HASH="${ROWS_HASH[$i]}"
                return 0
            fi
        done

        # If not in table, check git directly
        if git show-ref --verify --quiet "refs/heads/$input"; then
            RESOLVED_BRANCH="$input"
            RESOLVED_REF="refs/heads/$input"
            RESOLVED_HASH=$(git rev-parse --short "refs/heads/$input" 2>/dev/null)
            return 0
        elif git show-ref --verify --quiet "refs/remotes/origin/$input"; then
            RESOLVED_BRANCH="origin/$input"
            RESOLVED_REF="refs/remotes/origin/$input"
            RESOLVED_HASH=$(git rev-parse --short "refs/remotes/origin/$input" 2>/dev/null)
            return 0
        fi
    fi

    render_error_box "Invalid branch or ID: '$input'" "Please specify a valid numeric ID or existing branch name" "git-record -c 1"
}

action_checkout() {
    local target="$1"
    resolve_branch_target "$target" "-c"
    local branch="$RESOLVED_BRANCH"
    local ref="$RESOLVED_REF"

    if [ "$branch" = "$CUR_BRANCH" ]; then
        print_info "Already on branch '${C_BOLD}$branch${C_RESET}'"
        return 0
    fi

    if [[ "$ref" == refs/heads/* ]]; then
        if git checkout "$branch"; then
            print_success "Switched to branch '${C_BOLD}$branch${C_RESET}'"
        fi
    else
        # Remote branch checkout
        local local_name="${branch#origin/}"
        local_name="${local_name#upstream/}"

        if git show-ref --verify --quiet "refs/heads/$local_name"; then
            if git checkout "$local_name"; then
                print_success "Switched to existing local branch '${C_BOLD}$local_name${C_RESET}'"
            fi
        else
            if git checkout -b "$local_name" --track "$branch" 2>/dev/null || git checkout "$local_name" 2>/dev/null; then
                print_success "Created and switched to branch '${C_BOLD}$local_name${C_RESET}' tracking '${C_DIM}$branch${C_RESET}'"
            else
                render_error_box "Failed to checkout remote branch" "Check for working tree conflicts or uncommitted changes" "git status"
            fi
        fi
    fi
}

action_delete() {
    local target="$1"
    local force="${2:-0}"
    resolve_branch_target "$target" "-d"
    local branch="$RESOLVED_BRANCH"
    local ref="$RESOLVED_REF"

    if [[ "$ref" != refs/heads/* ]]; then
        render_error_box "Cannot delete remote branch with this flag" "To delete on remote: git push origin --delete ${branch#origin/}" "git-record -d <local_id>"
    fi

    if [ "$branch" = "$CUR_BRANCH" ]; then
        render_error_box "Cannot delete the currently active branch: '$branch'" "Switch to another branch first" "git-record -c main"
    fi

    # Protected branch check
    if [[ "$branch" =~ ^(master|main|develop|staging|production|release) ]]; then
        print_warn "Branch '${C_BOLD}$branch${C_RESET}' is a protected branch!"
        printf "  %bAre you absolutely sure you want to delete it? (yes/no): %b" "$C_YELLOW$C_BOLD" "$C_RESET"
        read -r confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Deletion cancelled."
            return 0
        fi
    fi

    local del_flag="-d"
    [ "$force" -eq 1 ] && del_flag="-D"

    if git branch "$del_flag" "$branch" 2>/dev/null; then
        print_success "Deleted branch '${C_BOLD}$branch${C_RESET}'"
    else
        if [ "$force" -eq 0 ]; then
            print_warn "Branch '${C_BOLD}$branch${C_RESET}' has unmerged commits."
            printf "  %bForce delete branch anyway? (y/N): %b" "$C_YELLOW" "$C_RESET"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if git branch -D "$branch" 2>/dev/null; then
                    print_success "Force deleted branch '${C_BOLD}$branch${C_RESET}'"
                fi
            else
                print_info "Deletion cancelled."
            fi
        else
            render_error_box "Failed to delete branch '$branch'" "Ensure branch is not locked or checked out in a worktree" "git worktree list"
        fi
    fi
}

action_bulk_delete() {
    local raw_ids="$1"
    IFS=',' read -ra id_list <<< "$raw_ids"

    if [ "${#id_list[@]}" -eq 0 ]; then
        render_error_box "No branch IDs provided for bulk delete" "Provide comma-separated branch IDs" "git-record -b 2,4,5"
    fi

    local valid_branches=()
    echo
    printf "  %b%s REVIEW BRANCHES TO DELETE:%b\n" "$C_BOLD$C_YELLOW" "$ICON_CLEANUP" "$C_RESET"

    for raw_id in "${id_list[@]}"; do
        local clean_id
        clean_id=$(echo "$raw_id" | tr -d ' ')
        if ! [[ "$clean_id" =~ ^[0-9]+$ ]]; then
            render_error_box "Invalid ID in bulk list: '$clean_id'" "All IDs must be numeric" "git-record -b 2,3,5"
        fi

        if [ "$clean_id" -lt 1 ] || [ "$clean_id" -gt "$TOTAL_VISIBLE" ]; then
            render_error_box "ID $clean_id out of range (1-$TOTAL_VISIBLE)" "Check table IDs" "git-record"
        fi

        local bname="${ROWS_BRANCH_TEXT[$clean_id]}"
        local bref="${ROWS_BRANCH_REF[$clean_id]}"

        if [[ "$bref" != refs/heads/* ]]; then
            print_warn "Skipping ID $clean_id ($bname) - Remote branches cannot be bulk deleted locally."
            continue
        fi

        if [ "$bname" = "$CUR_BRANCH" ]; then
            print_warn "Skipping ID $clean_id ($bname) - Cannot delete currently checked-out branch."
            continue
        fi

        valid_branches+=("$bname")
        printf "    %b[%s]%b %-30s\n" "$C_DIM" "$clean_id" "$C_RESET" "$bname"
    done

    if [ "${#valid_branches[@]}" -eq 0 ]; then
        print_warn "No eligible local branches found to delete."
        return 0
    fi

    echo
    printf "  %bConfirm deletion of %d local branches? (yes/no): %b" "$C_YELLOW$C_BOLD" "${#valid_branches[@]}" "$C_RESET"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Bulk deletion cancelled."
        return 0
    fi

    local deleted=0
    for b in "${valid_branches[@]}"; do
        if git branch -D "$b" >/dev/null 2>&1; then
            print_success "Deleted: $b"
            deleted=$((deleted + 1))
        else
            print_warn "Failed to delete: $b"
        fi
    done

    echo
    print_success "Bulk cleanup complete. Deleted $deleted/${#valid_branches[@]} branches."
    echo
}

action_merge() {
    local target="$1"
    resolve_branch_target "$target" "-m"
    local branch="$RESOLVED_BRANCH"

    if [ "$branch" = "$CUR_BRANCH" ]; then
        render_error_box "Cannot merge branch '$branch' into itself" "Switch to target branch first" "git-record -c main"
    fi

    # Check for uncommitted working tree changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        render_error_box "Working tree has uncommitted changes" "Commit or stash changes before merging" "git stash"
    fi

    # Pre-merge conflict check
    local base_commit
    base_commit=$(git merge-base HEAD "$branch" 2>/dev/null)
    if [ -n "$base_commit" ]; then
        local conflict_test
        conflict_test=$(git merge-tree "$base_commit" HEAD "$branch" 2>/dev/null)
        if [[ "$conflict_test" =~ \+{7}\ (our|their|base) ]] || [[ "$conflict_test" =~ \<{7} ]]; then
            print_warn "Potential merge conflicts detected in advance!"
            printf "  %bRun merge conflict inspection first? (y/N): %b" "$C_YELLOW" "$C_RESET"
            read -r inspect_conflicts
            if [[ "$inspect_conflicts" =~ ^[Yy]$ ]]; then
                action_conflicts "$target"
                return 0
            fi
        fi
    fi

    echo -e "\n  ${C_CYAN}${ICON_SYNC} Merging '${C_BOLD}$branch${C_RESET}${C_CYAN}' into '${C_BOLD}$CUR_BRANCH${C_RESET}${C_CYAN}'...${C_RESET}\n"
    if git merge "$branch"; then
        print_success "Successfully merged '$branch' into '$CUR_BRANCH'"
    else
        render_error_box "Merge resulted in conflicts" "Resolve conflicts in editor, then commit result" "git status"
    fi
}

action_rename() {
    local target="$1"
    local new_name="$2"
    resolve_branch_target "$target" "-R"
    local branch="$RESOLVED_BRANCH"
    local ref="$RESOLVED_REF"

    if [[ "$ref" != refs/heads/* ]]; then
        render_error_box "Cannot rename remote branch directly" "Only local branches can be renamed" "git-record"
    fi

    if [ -z "$new_name" ]; then
        echo -e "\n  ${C_HEADER}Current Branch Name:${C_RESET} ${C_CYAN}$branch${C_RESET}"
        printf "  %bEnter new branch name: %b" "$C_BOLD" "$C_RESET"
        read -r new_name
    fi

    if [ -z "$new_name" ]; then
        render_error_box "New branch name cannot be empty" "Provide a valid branch name" "git-record -r 1 new-feature"
    fi

    if ! git check-ref-format --branch "$new_name" 2>/dev/null; then
        render_error_box "Invalid Git branch name: '$new_name'" "Branch names cannot contain spaces, '~', '^', ':', or start with '-'" "git-record -r 1 feature/clean"
    fi

    if git branch -m "$branch" "$new_name"; then
        print_success "Renamed branch '${C_BOLD}$branch${C_RESET}' → '${C_BOLD}$new_name${C_RESET}'"
    fi
}

action_show() {
    local target="$1"
    resolve_branch_target "$target" "-s"
    local branch="$RESOLVED_BRANCH"
    local hash="$RESOLVED_HASH"

    echo -e "\n  ${C_BOLD}${ICON_LOG} COMMIT DETAILS: ${C_CYAN}$branch${C_RESET} ${C_DIM}($hash)${C_RESET}\n"
    git show --stat --decorate "$hash"
    echo
}

action_copy_hash() {
    local target="$1"
    resolve_branch_target "$target" "-k"
    local hash="$RESOLVED_HASH"

    local full_hash
    full_hash=$(git rev-parse "$hash" 2>/dev/null || echo "$hash")

    if copy_to_clipboard "$full_hash"; then
        echo
        print_success "Copied commit hash to clipboard: ${C_BOLD}$full_hash${C_RESET}"
        echo
    else
        echo
        print_info "Commit hash: ${C_BOLD}$full_hash${C_RESET}"
        echo
    fi
}

# ------------------------------------------------------------------------------
# 📊 DEEP ANALYTICS & COMPARISON SUITE
# ------------------------------------------------------------------------------

action_stats() {
    local target="$1"
    resolve_branch_target "$target" "-X"
    local branch="$RESOLVED_BRANCH"

    local base_ref="$PRIMARY_BRANCH"
    if [ "$branch" = "$base_ref" ] || [ "$branch" = "origin/$base_ref" ]; then
        base_ref="HEAD~20"
    fi

    echo -e "\n  ${C_BOLD}${ICON_STATS} BRANCH METRICS & STATISTICS: ${C_CYAN}$branch${C_RESET}\n"

    # Commit counts & Churn
    local commits_ahead commits_behind
    commits_ahead=$(git rev-list --count "$base_ref..$branch" 2>/dev/null || echo 0)
    commits_behind=$(git rev-list --count "$branch..$base_ref" 2>/dev/null || echo 0)

    # Churn stats
    local additions=0 deletions=0 files_changed=0
    while read -r add del file; do
        [ -z "$file" ] && continue
        [[ "$add" =~ ^[0-9]+$ ]] && additions=$((additions + add))
        [[ "$del" =~ ^[0-9]+$ ]] && deletions=$((deletions + del))
        files_changed=$((files_changed + 1))
    done < <(git diff --numstat "$base_ref...$branch" 2>/dev/null)

    # Output Card
    printf "  %b┌─ Activity Relative to %s%b\n" "$C_HEADER" "$base_ref" "$C_RESET"
    printf "  %b│%b  Ahead:       %b+%s commits%b\n" "$C_HEADER" "$C_RESET" "$C_GREEN" "$commits_ahead" "$C_RESET"
    printf "  %b│%b  Behind:      %b-%s commits%b\n" "$C_HEADER" "$C_RESET" "$C_RED" "$commits_behind" "$C_RESET"
    printf "  %b│%b  Files:       %s modified\n" "$C_HEADER" "$C_RESET" "$files_changed"
    printf "  %b│%b  Lines Added: %b+%s%b\n" "$C_HEADER" "$C_RESET" "$C_GREEN" "$additions" "$C_RESET"
    printf "  %b│%b  Lines Del:   %b-%s%b\n" "$C_HEADER" "$C_RESET" "$C_RED" "$deletions" "$C_RESET"
    printf "  %b│%b  Net Churn:   %b%s%b lines\n" "$C_HEADER" "$C_RESET" "$C_CYAN" "$((additions - deletions))" "$C_RESET"
    printf "  %b└────────────────────────────────────────%b\n\n" "$C_HEADER" "$C_RESET"

    # Top Contributors on this branch
    printf "  %b%s Top Contributors:%b\n" "$C_BOLD" "$ICON_TEAM" "$C_RESET"
    git shortlog -sn --no-merges -n 5 "$base_ref..$branch" 2>/dev/null | while read -r c author; do
        printf "    %-24s " "$author"
        draw_bar "$c" "${commits_ahead:-10}" 15 "$C_BLUE"
        printf " %3d commits\n" "$c"
    done

    # Recent Commits
    echo
    printf "  %b%s Recent Commits on %s:%b\n" "$C_BOLD" "$ICON_LOG" "$branch" "$C_RESET"
    git log --oneline --graph -n 8 "$branch" 2>/dev/null | sed 's/^/    /'
    echo
}

action_compare() {
    local pair="$1"
    if [[ ! "$pair" =~ ^([^:]+):([^:]+)$ ]]; then
        render_error_box "Invalid comparison format: '$pair'" "Format must be <ID1>:<ID2> or <branch1>:<branch2>" "git-record -C 1:3"
    fi

    local target1="${BASH_REMATCH[1]}"
    local target2="${BASH_REMATCH[2]}"

    resolve_branch_target "$target1" "-C"
    local branch1="$RESOLVED_BRANCH"
    local hash1="$RESOLVED_HASH"

    resolve_branch_target "$target2" "-C"
    local branch2="$RESOLVED_BRANCH"
    local hash2="$RESOLVED_HASH"

    echo -e "\n  ${C_BOLD}${ICON_SEARCH} TWO-WAY BRANCH COMPARISON${C_RESET}"
    echo -e "  Branch A: ${C_CYAN}$branch1${C_RESET} ${C_DIM}($hash1)${C_RESET}"
    echo -e "  Branch B: ${C_CYAN}$branch2${C_RESET} ${C_DIM}($hash2)${C_RESET}\n"

    local base_commit
    base_commit=$(git merge-base "$branch1" "$branch2" 2>/dev/null)
    if [ -n "$base_commit" ]; then
        echo -e "  ${C_HEADER}Common Merge Base:${C_RESET} ${C_DIM}$base_commit ($(git log -1 --format='%cr' "$base_commit"))${C_RESET}\n"
    fi

    echo -e "  ${C_HEADER}Commits in $branch1 but NOT in $branch2:${C_RESET}"
    git log --oneline --no-merges -n 10 "$branch2..$branch1" 2>/dev/null | sed 's/^/    /' || echo "    (none)"

    echo -e "\n  ${C_HEADER}Commits in $branch2 but NOT in $branch1:${C_RESET}"
    git log --oneline --no-merges -n 10 "$branch1..$branch2" 2>/dev/null | sed 's/^/    /' || echo "    (none)"

    echo -e "\n  ${C_HEADER}Diff Summary ($branch1 ... $branch2):${C_RESET}"
    git diff --stat "$branch1...$branch2" 2>/dev/null | head -15 | sed 's/^/    /'
    echo
}

action_conflicts() {
    local target="$1"
    local base_target="${2:-$PRIMARY_BRANCH}"

    resolve_branch_target "$target" "-M"
    local branch="$RESOLVED_BRANCH"

    echo -e "\n  ${C_BOLD}${ICON_CONFLICT} MERGE CONFLICT PREDICTOR${C_RESET}"
    echo -e "  Checking mergeability: ${C_CYAN}$branch${C_RESET} ➔ ${C_CYAN}$base_target${C_RESET}\n"

    local base_commit
    base_commit=$(git merge-base "$base_target" "$branch" 2>/dev/null)

    if [ -z "$base_commit" ]; then
        render_error_box "No common ancestor found between $branch and $base_target" "Branches do not share git commit history" "git-record -C $branch:$base_target"
    fi

    # Read modified files on both sides
    local files_a files_b
    mapfile -t files_a < <(git diff --name-only "$base_commit" "$branch" 2>/dev/null)
    mapfile -t files_b < <(git diff --name-only "$base_commit" "$base_target" 2>/dev/null)

    local overlapping=()
    for fa in "${files_a[@]}"; do
        for fb in "${files_b[@]}"; do
            if [ "$fa" = "$fb" ]; then
                overlapping+=("$fa")
                break
            fi
        done
    done

    if [ "${#overlapping[@]}" -eq 0 ]; then
        echo -e "  ${C_SUCCESS}${ICON_CHECK} Clean Merge Expected!${C_RESET}"
        echo -e "  ${C_DIM}No overlapping file modifications between both branches.${C_RESET}\n"
        return 0
    fi

    echo -e "  ${C_WARN}${ICON_WARN_TRI} Potential file overlap in ${#overlapping[@]} file(s):${C_RESET}\n"
    for f in "${overlapping[@]}"; do
        local changes_a changes_b
        changes_a=$(git diff --numstat "$base_commit" "$branch" -- "$f" 2>/dev/null | awk '{print "+" $1 "/-" $2}')
        changes_b=$(git diff --numstat "$base_commit" "$base_target" -- "$f" 2>/dev/null | awk '{print "+" $1 "/-" $2}')
        printf "    %b%s%b  %-40s %b(%s in branch, %s in %s)%b\n" \
            "$C_RED" "$ICON_CONFLICT" "$C_RESET" "$f" "$C_DIM" "${changes_a:-+0/-0}" "${changes_b:-+0/-0}" "$base_target" "$C_RESET"
    done

    echo
    printf "  %bTip: Inspect exact file diff with: git diff %s...%s -- <filename>%b\n\n" "$C_DIM" "$base_target" "$branch" "$C_RESET"
}

action_velocity() {
    local days="${1:-$VELOCITY_DAYS}"
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        days=$VELOCITY_DAYS
    fi

    local since_date
    since_date=$(get_past_date "$days" "%Y-%m-%d")

    echo -e "\n  ${C_BOLD}${ICON_GRAPH} TEAM VELOCITY & METRICS (Past $days Days)${C_RESET}\n"

    # Total commit count & author count in window
    local total_commits total_authors
    total_commits=$(git log --since="$since_date" --all --oneline 2>/dev/null | wc -l | tr -d ' ')
    total_authors=$(git log --since="$since_date" --all --format='%an' 2>/dev/null | sort -u | wc -l | tr -d ' ')
    local avg_per_day=0
    [ "$days" -gt 0 ] && avg_per_day=$((total_commits / days))

    printf "  %b┌─ Summary (%s to Present)%b\n" "$C_HEADER" "$since_date" "$C_RESET"
    printf "  %b│%b  Total Commits:  %b%s%b\n" "$C_HEADER" "$C_RESET" "$C_BOLD$C_CYAN" "$total_commits" "$C_RESET"
    printf "  %b│%b  Active Authors: %b%s%b\n" "$C_HEADER" "$C_RESET" "$C_BOLD$C_GREEN" "$total_authors" "$C_RESET"
    printf "  %b│%b  Avg Commits/Day:%b %s%b\n" "$C_HEADER" "$C_RESET" "$C_BOLD$C_YELLOW" "$avg_per_day" "$C_RESET"
    printf "  %b└────────────────────────────────────────%b\n\n" "$C_HEADER" "$C_RESET"

    # Top Committers
    printf "  %b%s Top Contributors by Commit Volume:%b\n" "$C_BOLD" "$ICON_TEAM" "$C_RESET"
    local max_author_commits=1
    while read -r c _; do
        [ -n "$c" ] && [ "$c" -gt "$max_author_commits" ] && max_author_commits=$c
    done < <(git log --since="$since_date" --all --format='%an' 2>/dev/null | sort | uniq -c | sort -rn | head -1)

    git log --since="$since_date" --all --format='%an' 2>/dev/null | sort | uniq -c | sort -rn | head -8 | while read -r c author; do
        [ -z "$c" ] && continue
        printf "    %-24s " "$author"
        draw_bar "$c" "$max_author_commits" 20 "$C_CYAN"
        printf " %3d commits\n" "$c"
    done

    # Daily Activity Trend (Past 14 Days)
    echo
    printf "  %b%s Daily Commit Timeline:%b\n" "$C_BOLD" "$ICON_CLOCK" "$C_RESET"
    local past_14
    past_14=$(get_past_date 14 "%Y-%m-%d")
    git log --since="$past_14" --all --date=short --format='%cd' 2>/dev/null | sort | uniq -c | while read -r c dt; do
        [ -z "$dt" ] && continue
        printf "    %-12s " "$dt"
        draw_bar "$c" 30 18 "$C_GREEN"
        printf " %3d\n" "$c"
    done
    echo
}

action_graph() {
    echo -e "\n  ${C_BOLD}${ICON_GRAPH} BRANCH DIVERGENCE & TOPOLOGY GRAPH${C_RESET}\n"
    local main_b="$PRIMARY_BRANCH"
    printf "  %bBase Reference: %s%b\n\n" "$C_DIM" "$main_b" "$C_RESET"

    local branches=()
    mapfile -t branches < <(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | head -25)

    for b in "${branches[@]}"; do
        if [ "$b" = "$main_b" ]; then
            printf "  %b%s (Base Root)%b\n" "$C_BOLD$C_GREEN" "$b" "$C_RESET"
            continue
        fi

        local ahead behind
        ahead=$(git rev-list --count "$main_b..$b" 2>/dev/null || echo 0)
        behind=$(git rev-list --count "$b..$main_b" 2>/dev/null || echo 0)

        local status_badge=""
        if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            status_badge="${C_GREEN}[synchronized]${C_RESET}"
        elif [ "$behind" -eq 0 ]; then
            status_badge="${C_CYAN}[pure ahead]${C_RESET}"
        elif [ "$ahead" -gt 30 ] || [ "$behind" -gt 30 ]; then
            status_badge="${C_RED}[diverged]${C_RESET}"
        else
            status_badge="${C_YELLOW}[active branch]${C_RESET}"
        fi

        printf "  %b├──%b %-30s %b+%s%b / %b-%s%b  %s\n" \
            "$C_BORDER" "$C_RESET" "$b" \
            "$C_GREEN" "$ahead" "$C_RESET" \
            "$C_RED" "$behind" "$C_RESET" \
            "$status_badge"
    done
    echo
}

action_cleanup_audit() {
    echo -e "\n  ${C_BOLD}${ICON_CLEANUP} SMART REPOSITORY CLEANUP AUDITOR${C_RESET}\n"
    local main_b="$PRIMARY_BRANCH"

    # Detect fully merged branches
    local merged=()
    while IFS= read -r b; do
        b=$(echo "$b" | tr -d ' *')
        if [ -n "$b" ] && [ "$b" != "$main_b" ] && [ "$b" != "$CUR_BRANCH" ] && [[ ! "$b" =~ ^(master|main|develop|staging|production) ]]; then
            merged+=("$b")
        fi
    done < <(git branch --merged "$main_b" 2>/dev/null)

    # Detect stale/abandoned branches (> CLEANUP_THRESHOLD days)
    local stale=()
    local threshold_ts=$(( $(date +%s) - (CLEANUP_THRESHOLD * 86400) ))
    while IFS='|' read -r b ts; do
        if [ -n "$ts" ] && [ "$ts" -lt "$threshold_ts" ] && [ "$b" != "$main_b" ] && [ "$b" != "$CUR_BRANCH" ]; then
            stale+=("$b")
        fi
    done < <(git for-each-ref --format='%(refname:short)|%(committerdate:unix)' refs/heads 2>/dev/null)

    if [ "${#merged[@]}" -eq 0 ] && [ "${#stale[@]}" -eq 0 ]; then
        print_success "Repository is clean! No merged or stale branches need pruning."
        echo
        return 0
    fi

    if [ "${#merged[@]}" -gt 0 ]; then
        echo -e "  ${C_GREEN}${ICON_CHECK} Merged Branches (Safe to Delete):${C_RESET}"
        for b in "${merged[@]}"; do
            echo -e "    ${C_DIM}└─${C_RESET} $b"
        done
        echo
    fi

    if [ "${#stale[@]}" -gt 0 ]; then
        echo -e "  ${C_WARN}${ICON_WARN_TRI} Stale Branches (Inactive >$CLEANUP_THRESHOLD days):${C_RESET}"
        for b in "${stale[@]}"; do
            echo -e "    ${C_DIM}└─${C_RESET} $b"
        done
        echo
    fi

    if [ "${#merged[@]}" -gt 0 ]; then
        printf "  %bWould you like to delete the %d merged branch(es) now? (y/N): %b" "$C_CYAN$C_BOLD" "${#merged[@]}" "$C_RESET"
        read -r do_del
        if [[ "$do_del" =~ ^[Yy]$ ]]; then
            for b in "${merged[@]}"; do
                if git branch -d "$b" 2>/dev/null; then
                    print_success "Deleted merged branch: $b"
                fi
            done
        fi
    fi
    echo
}

action_tags() {
    local limit="${1:-$DEFAULT_LIMIT}"
    echo -e "\n  ${C_BOLD}${ICON_TAG} REPOSITORY TAGS & RELEASES${C_RESET}\n"

    if ! git tag -l | head -1 >/dev/null 2>&1; then
        print_info "No tags found in repository."
        echo
        return 0
    fi

    git tag -l --sort=-creatordate --format='%(refname:short)|%(creatordate:relative)|%(objectname:short)|%(subject)' | head -n "$limit" | while IFS='|' read -r tag date hash msg; do
        printf "  %b%-22s%b %b%-16s%b %b%s%b  %s\n" \
            "$C_CYAN$C_BOLD" "$tag" "$C_RESET" \
            "$C_TIME" "$date" "$C_RESET" \
            "$C_DIM" "$hash" "$C_RESET" \
            "${msg:0:40}"
    done
    echo
}

action_stash() {
    echo -e "\n  ${C_BOLD}${ICON_STASH} STASHED CHANGES${C_RESET}\n"

    if ! git stash list | head -1 >/dev/null 2>&1; then
        print_info "No stashed changes in repository."
        echo
        return 0
    fi

    git stash list --format='%gd|%cr|%s' | while IFS='|' read -r stash_ref date msg; do
        printf "  %b%-12s%b %b%-16s%b %s\n" \
            "$C_YELLOW$C_BOLD" "$stash_ref" "$C_RESET" \
            "$C_TIME" "$date" "$C_RESET" \
            "$msg"
    done
    printf "\n  %bApply stash with: git stash apply <stash@{N}>%b\n\n" "$C_DIM" "$C_RESET"
}

action_worktrees() {
    echo -e "\n  ${C_BOLD}${ICON_WORKTREE} GIT WORKTREES${C_RESET}\n"
    local count=0
    while read -r wt_path wt_head wt_branch wt_extra; do
        [ -z "$wt_path" ] && continue
        count=$((count + 1))
        printf "  %b%-35s%b %b%-20s%b %b%s %s%b\n" \
            "$C_CYAN" "$wt_path" "$C_RESET" \
            "$C_GREEN$C_BOLD" "$wt_branch" "$C_RESET" \
            "$C_DIM" "$wt_head" "$wt_extra" "$C_RESET"
    done < <(git worktree list 2>/dev/null)

    if [ "$count" -eq 0 ]; then
        print_info "No worktrees found."
    fi
    echo
}

# ------------------------------------------------------------------------------
# 🦊 CI/CD INTEGRATION & REAL-TIME MONITORING
# ------------------------------------------------------------------------------

action_ci_status() {
    local target="$1"
    resolve_branch_target "$target" "-N"
    local branch="$RESOLVED_BRANCH"

    local clean_branch="${branch#origin/}"
    clean_branch="${clean_branch#upstream/}"

    echo -e "\n  ${C_BOLD}${ICON_CI} CI/CD PIPELINE STATUS: ${C_CYAN}$clean_branch${C_RESET}\n"

    # 1. Try Native GitHub CLI (gh)
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        echo -e "  ${C_DIM}Using GitHub CLI (gh)...${C_RESET}\n"
        if gh run list --branch "$clean_branch" --limit 3 2>/dev/null; then
            echo
            return 0
        fi
    fi

    # 2. Try Native GitLab CLI (glab)
    if command -v glab >/dev/null 2>&1 && glab auth status >/dev/null 2>&1; then
        echo -e "  ${C_DIM}Using GitLab CLI (glab)...${C_RESET}\n"
        if glab ci status --branch "$clean_branch" 2>/dev/null; then
            echo
            return 0
        fi
    fi

    # 3. REST API Fallback
    local platform
    platform=$(detect_remote_platform)
    if [ -z "$platform" ]; then
        render_error_box "Unable to detect remote platform" "Ensure remote origin points to GitHub or GitLab" "git remote -v"
    fi

    if [ "$platform" = "github" ]; then
        local token repo
        token=$(get_github_token)
        repo=$(parse_github_repo)

        if [ -z "$token" ]; then
            print_warn "No GitHub Token configured."
            echo -e "  ${C_DIM}Set GITHUB_TOKEN or install 'gh' CLI for instant CI integration.${C_RESET}\n"
            return 1
        fi

        local res
        res=$(curl -s -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$repo/actions/runs?branch=$clean_branch&per_page=1" 2>/dev/null)

        if [ -n "$res" ] && command -v jq >/dev/null 2>&1; then
            local count
            count=$(echo "$res" | jq '.total_count // 0' 2>/dev/null)
            if [ "$count" -gt 0 ]; then
                local w_name w_status w_conclusion w_id
                w_name=$(echo "$res" | jq -r '.workflow_runs[0].name' 2>/dev/null)
                w_status=$(echo "$res" | jq -r '.workflow_runs[0].status' 2>/dev/null)
                w_conclusion=$(echo "$res" | jq -r '.workflow_runs[0].conclusion' 2>/dev/null)
                w_id=$(echo "$res" | jq -r '.workflow_runs[0].id' 2>/dev/null)

                printf "  Workflow:   %b%s%b\n" "$C_BOLD" "$w_name" "$C_RESET"
                printf "  Run ID:     %s\n" "$w_id"
                printf "  Status:     "
                if [ "$w_status" = "completed" ]; then
                    [ "$w_conclusion" = "success" ] && echo -e "${C_GREEN}${ICON_CHECK} SUCCESS${C_RESET}"
                    [ "$w_conclusion" = "failure" ] && echo -e "${C_RED}${ICON_CROSS} FAILED${C_RESET}"
                    [ "$w_conclusion" = "cancelled" ] && echo -e "${C_YELLOW}CANCELLED${C_RESET}"
                else
                    echo -e "${C_YELLOW}⏳ $w_status${C_RESET}"
                fi
                echo
                return 0
            fi
        fi
        print_info "No workflow runs found for branch '$clean_branch'"
    fi
    echo
}

action_realtime_ci() {
    local target="$1"
    local interval="${2:-$DEFAULT_REFRESH_INTERVAL}"
    if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt "$MIN_INTERVAL" ]; then
        interval=$DEFAULT_REFRESH_INTERVAL
    fi

    resolve_branch_target "$target" "-R"
    local branch="$RESOLVED_BRANCH"
    local clean_branch="${branch#origin/}"

    # Setup trap for clean exit
    trap 'clear; echo -e "\n  ${C_YELLOW}Live monitoring stopped.${C_RESET}\n"; exit 0' INT TERM

    local iter=0
    while true; do
        iter=$((iter + 1))
        clear
        echo -e "  ${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "  ${C_BOLD}${C_CYAN}║${C_RESET}   ${C_RED}●${C_RESET} ${C_BOLD}LIVE CI/CD MONITOR${C_RESET}  ${C_DIM}(Press Ctrl+C to Exit)${C_RESET}               ${C_BOLD}${C_CYAN}║${C_RESET}"
        echo -e "  ${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════════════════════╝${C_RESET}\n"
        echo -e "  ${C_HEADER}Branch:${C_RESET} ${C_BOLD}$clean_branch${C_RESET}  ${C_DIM}│ Refresh: ${interval}s │ Iteration: #$iter │ Time: $(date '+%H:%M:%S')${C_RESET}\n"

        action_ci_status "$target" 2>/dev/null || true

        for ((s=interval; s>0; s--)); do
            printf "\r  ${C_DIM}Next update in %ds... (Press Ctrl+C to quit) ${C_RESET}" "$s"
            sleep 1
        done
    done
}

# ------------------------------------------------------------------------------
# 🎮 INTERACTIVE TUI (FZF Enhanced + Built-In Fallback)
# ------------------------------------------------------------------------------

interactive_mode() {
    # Check if FZF is installed for supreme interactive experience
    if command -v fzf >/dev/null 2>&1; then
        local selection
        selection=$(for ((i=1; i<=TOTAL_VISIBLE; i++)); do
            printf "%-3s | %-6s | %-32s | %-8s | %-15s | %s\n" \
                "${ROWS_ID[$i]}" "${ROWS_TYPE[$i]}" "${ROWS_BRANCH_TEXT[$i]}" "${ROWS_HASH[$i]}" "${ROWS_DATE[$i]}" "${ROWS_AUTHOR[$i]}"
        done | fzf --ansi --header="[ENTER: Checkout] [CTRL-S: Show] [CTRL-X: Stats] [CTRL-D: Delete]" \
                   --preview="git show --stat --color=always \$(echo {} | awk '{print \$7}') 2>/dev/null || git log -5 --oneline \$(echo {} | awk '{print \$5}')" \
                   --bind="ctrl-s:execute(git show --stat \$(echo {} | awk '{print \$7}'))" \
                   --height="70%" --reverse)

        if [ -n "$selection" ]; then
            local sel_id
            sel_id=$(echo "$selection" | awk '{print $1}')
            if [ -n "$sel_id" ]; then
                action_checkout "$sel_id"
            fi
        fi
        return 0
    fi

    # Built-in Interactive Menu Fallback
    render_table
    echo
    echo -e "  ${C_BOLD}${ICON_TIP} INTERACTIVE MENU${C_RESET}"
    echo -e "  ${C_CYAN}1)${C_RESET} Checkout Branch    ${C_CYAN}4)${C_RESET} Delete Branch    ${C_CYAN}7)${C_RESET} Team Velocity"
    echo -e "  ${C_CYAN}2)${C_RESET} Show Details       ${C_CYAN}5)${C_RESET} Branch Stats     ${C_CYAN}8)${C_RESET} Check Conflicts"
    echo -e "  ${C_CYAN}3)${C_RESET} Merge Branch       ${C_CYAN}6)${C_RESET} Compare Two      ${C_CYAN}0)${C_RESET} Exit"
    echo
    printf "  %bSelect option [1-8, 0 to exit]: %b" "$C_BOLD" "$C_RESET"
    read -r choice

    case "$choice" in
        1) printf "  Enter ID to checkout: "; read -r tid; action_checkout "$tid" ;;
        2) printf "  Enter ID to inspect: "; read -r tid; action_show "$tid" ;;
        3) printf "  Enter ID to merge: "; read -r tid; action_merge "$tid" ;;
        4) printf "  Enter ID to delete: "; read -r tid; action_delete "$tid" ;;
        5) printf "  Enter ID for stats: "; read -r tid; action_stats "$tid" ;;
        6) printf "  Enter comparison (ID1:ID2): "; read -r pair; action_compare "$pair" ;;
        7) action_velocity ;;
        8) printf "  Enter ID to test conflicts: "; read -r tid; action_conflicts "$tid" ;;
        0) exit 0 ;;
        *) render_error_box "Invalid selection" "Choose a number between 0 and 8" "git-record -i" ;;
    esac
}

# ------------------------------------------------------------------------------
# 📖 COMMAND LINE PARSER & MAIN DISPATCHER
# ------------------------------------------------------------------------------

show_help() {
    cat << EOF
${C_BOLD}╔══════════════════════════════════════════════════════════════════════════════╗
║                     📘 GIT-RECORD v${VERSION} - CLI SUITE                       ║
╚══════════════════════════════════════════════════════════════════════════════╝${C_RESET}

${C_HEADER}DESCRIPTION:${C_RESET}
  High-performance Git branch management, analytics, and workflow automation tool.

${C_HEADER}BASIC USAGE:${C_RESET}
  git-record [limit]               Display recent branch table (default: 10)
  git-record 25                    Display latest 25 branches
  git-record -l, --local           Show local branches only
  git-record -r, --remote          Show remote branches only
  git-record -a, --all             Show all branches without limits
  git-record -f, --filter <query>  Filter branches by name, author, or message
  git-record -u, --fetch           Fetch remote repository updates before rendering
  git-record -i, --interactive     Launch interactive TUI / FZF branch selector

${C_HEADER}WORKFLOW ACTIONS:${C_RESET}
  -c, --checkout <ID/branch>       Checkout branch (auto-tracks remote branches)
  -m, --merge <ID/branch>          Merge target branch into current branch
  -d, --delete <ID/branch>         Safely delete local branch
  -D, --force-delete <ID/branch>   Force delete local branch
  -b, --bulk-delete <ID1,ID2...>   Bulk delete multiple branches with review prompt
  -R, --rename <ID> [new-name]     Rename local branch safely
  -k, --copy <ID/branch>           Copy branch commit hash to system clipboard

${C_HEADER}INSPECTION & ANALYTICS:${C_RESET}
  -s, --show <ID/branch>           Show commit details and diffstat
  -X, --stats <ID/branch>          Deep metrics (ahead/behind, churn, top contributors)
  -C, --compare <ID1:ID2>          Two-way comparison between branches
  -M, --conflicts <ID> [base]      Predict potential merge conflicts in advance
  -V, --velocity [days]            Team commit velocity and activity breakdown
  -G, --graph                      Branch relationship topology tree
  -A, --cleanup                    Smart cleanup auditor (finds merged & stale branches)
  -T, --tags [limit]               List repository tags and releases
  -L, --stash                      View stash stack with relative timestamps
  -H, --history [limit]            Formatted direct commit log history
  -S, --search <code/regex>        Search code content across all branches
  -W, --worktrees                  List active Git worktrees

${C_HEADER}CI/CD INTEGRATION:${C_RESET}
  -N, --ci <ID/branch>             Check GitHub Actions or GitLab CI pipeline status
  --watch-ci <ID> [interval]       Real-time live CI/CD monitoring dashboard

${C_HEADER}SYSTEM & DIAGNOSTICS:${C_RESET}
  --sys-info, --doctor             Show OS, platform, shell, git, and integration diagnostics
  --no-color                       Disable colored output
  -v, --version                    Display version and platform information
  -h, --help                       Show this help manual

${C_HEADER}EXAMPLES:${C_RESET}
  git-record                       # Show latest 10 branches
  git-record -c 2                  # Checkout branch #2 from list
  git-record -X 3                  # Inspect deep statistics of branch #3
  git-record -C 1:4                # Compare branch #1 against branch #4
  git-record -M 5                  # Check if branch #5 will conflict with main
  git-record -V 30                 # Team velocity for the past 30 days
  git-record -A                    # Find and prune abandoned & merged branches
  git-record --sys-info            # Display system environment & compatibility

EOF
    exit 0
}

main() {
    # Check for standalone system diagnostics without requiring git repo
    for arg in "$@"; do
        if [ "$arg" = "--sys-info" ] || [ "$arg" = "--doctor" ] || [ "$arg" = "--info" ]; then
            action_sys_info
            exit 0
        elif [ "$arg" = "-v" ] || [ "$arg" = "--version" ]; then
            detect_os_environment
            echo "git-record v${VERSION} (${OS_NAME} - ${OS_ARCH})"
            exit 0
        fi
    done

    # Verify we are in a valid git repo and get repo info
    check_git_repo
    get_repo_info

    LIMIT=$DEFAULT_LIMIT
    FILTER_NAME=""
    FILTER_CODE=""
    MODE="DEFAULT"
    DO_FETCH=0
    ONLY_LOCAL=0
    ONLY_REMOTE=0

    # Action flags
    ACT_CHECKOUT=""
    ACT_MERGE=""
    ACT_DELETE=""
    ACT_FORCE_DELETE=""
    ACT_RENAME=""
    ACT_SHOW=""
    ACT_COPY_HASH=""
    ACT_COMPARE=""
    ACT_STATS=""
    ACT_CONFLICTS=""
    ACT_VELOCITY=""
    ACT_GRAPH=""
    ACT_CLEANUP=""
    ACT_TAGS=""
    ACT_STASH=""
    ACT_WORKTREES=""
    ACT_CI=""
    ACT_REALTIME_CI=""
    ACT_INTERACTIVE=0
    ACT_BULK_DELETE=""

    # Check for direct numeric argument: `git-record 20`
    if [ "$#" -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        LIMIT="$1"
        shift
    fi

    # Parse Long and Short Flags
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help) show_help ;;
            -v|--version) echo "git-record version $VERSION"; exit 0 ;;
            --no-color) COLOR_MODE="never"; setup_colors; shift ;;
            -u|--fetch) DO_FETCH=1; shift ;;
            -l|--local) ONLY_LOCAL=1; shift ;;
            -r|--remote) ONLY_REMOTE=1; shift ;;
            -a|--all) LIMIT=0; shift ;;
            -i|--interactive) ACT_INTERACTIVE=1; shift ;;
            -f|--filter) FILTER_NAME="$2"; shift 2 ;;
            -S|--search) FILTER_CODE="$2"; MODE="CODE_SEARCH"; shift 2 ;;
            -H|--history)
                MODE="HISTORY"
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    LIMIT="$1"
                    shift
                fi
                ;;
            -c|--checkout) ACT_CHECKOUT="$2"; shift 2 ;;
            -m|--merge) ACT_MERGE="$2"; shift 2 ;;
            -d|--delete) ACT_DELETE="$2"; shift 2 ;;
            -D|--force-delete) ACT_FORCE_DELETE="$2"; shift 2 ;;
            -b|--bulk-delete) ACT_BULK_DELETE="$2"; shift 2 ;;
            -R|--rename)
                ACT_RENAME="$2"
                shift 2
                if [ -n "$1" ] && [[ ! "$1" =~ ^- ]]; then
                    RENAME_NEW_NAME="$1"
                    shift
                fi
                ;;
            -s|--show) ACT_SHOW="$2"; shift 2 ;;
            -k|--copy) ACT_COPY_HASH="$2"; shift 2 ;;
            -C|--compare) ACT_COMPARE="$2"; shift 2 ;;
            -X|--stats) ACT_STATS="$2"; shift 2 ;;
            -M|--conflicts) ACT_CONFLICTS="$2"; shift 2 ;;
            -V|--velocity)
                ACT_VELOCITY=1
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    VELOCITY_DAYS="$1"
                    shift
                fi
                ;;
            -G|--graph) ACT_GRAPH=1; shift ;;
            -A|--cleanup|--prune) ACT_CLEANUP=1; shift ;;
            -T|--tags)
                ACT_TAGS=1
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    LIMIT="$1"
                    shift
                fi
                ;;
            -L|--stash) ACT_STASH=1; shift ;;
            -W|--worktrees) ACT_WORKTREES=1; shift ;;
            -N|--ci) ACT_CI="$2"; shift 2 ;;
            --watch-ci)
                ACT_REALTIME_CI="$2"
                shift 2
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    REALTIME_INTERVAL="$1"
                    shift
                fi
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    LIMIT="$1"
                    shift
                else
                    render_error_box "Unknown option: '$1'" "Use --help to view available flags and usage examples" "git-record --help"
                fi
                ;;
        esac
    done

    # Fetch updates if requested
    if [ "$DO_FETCH" -eq 1 ]; then
        printf "  %b%s Fetching remote updates...%b\r" "$C_DIM" "$ICON_SYNC" "$C_RESET"
        git fetch --all --prune --quiet 2>/dev/null || print_warn "Remote fetch timed out or failed. Continuing with local data."
    fi

    # Fast-path standalone features that do not need full branch table
    if [ "$ACT_VELOCITY" = 1 ]; then
        action_velocity "$VELOCITY_DAYS"
        exit 0
    fi
    if [ "$ACT_GRAPH" = 1 ]; then
        action_graph
        exit 0
    fi
    if [ "$ACT_CLEANUP" = 1 ]; then
        action_cleanup_audit
        exit 0
    fi
    if [ "$ACT_TAGS" = 1 ]; then
        action_tags "$LIMIT"
        exit 0
    fi
    if [ "$ACT_STASH" = 1 ]; then
        action_stash
        exit 0
    fi
    if [ "$ACT_WORKTREES" = 1 ]; then
        action_worktrees
        exit 0
    fi

    # Expand limit if action references higher ID
    for req_id in "$ACT_CHECKOUT" "$ACT_MERGE" "$ACT_DELETE" "$ACT_FORCE_DELETE" "$ACT_RENAME" "$ACT_SHOW" "$ACT_COPY_HASH" "$ACT_STATS" "$ACT_CONFLICTS" "$ACT_CI" "$ACT_REALTIME_CI"; do
        if [[ "$req_id" =~ ^[0-9]+$ ]] && [ "$req_id" -gt "$LIMIT" ]; then
            LIMIT=$req_id
        fi
    done

    # Load branch and ref data
    load_records

    # Dispatch requested actions
    if [ "$ACT_INTERACTIVE" -eq 1 ]; then
        interactive_mode
        exit 0
    elif [ -n "$ACT_CHECKOUT" ]; then
        action_checkout "$ACT_CHECKOUT"
        exit 0
    elif [ -n "$ACT_MERGE" ]; then
        action_merge "$ACT_MERGE"
        exit 0
    elif [ -n "$ACT_DELETE" ]; then
        action_delete "$ACT_DELETE" 0
        exit 0
    elif [ -n "$ACT_FORCE_DELETE" ]; then
        action_delete "$ACT_FORCE_DELETE" 1
        exit 0
    elif [ -n "$ACT_BULK_DELETE" ]; then
        action_bulk_delete "$ACT_BULK_DELETE"
        exit 0
    elif [ -n "$ACT_RENAME" ]; then
        action_rename "$ACT_RENAME" "$RENAME_NEW_NAME"
        exit 0
    elif [ -n "$ACT_SHOW" ]; then
        action_show "$ACT_SHOW"
        exit 0
    elif [ -n "$ACT_COPY_HASH" ]; then
        action_copy_hash "$ACT_COPY_HASH"
        exit 0
    elif [ -n "$ACT_COMPARE" ]; then
        action_compare "$ACT_COMPARE"
        exit 0
    elif [ -n "$ACT_STATS" ]; then
        action_stats "$ACT_STATS"
        exit 0
    elif [ -n "$ACT_CONFLICTS" ]; then
        action_conflicts "$ACT_CONFLICTS"
        exit 0
    elif [ -n "$ACT_CI" ]; then
        action_ci_status "$ACT_CI"
        exit 0
    elif [ -n "$ACT_REALTIME_CI" ]; then
        action_realtime_ci "$ACT_REALTIME_CI" "${REALTIME_INTERVAL:-5}"
        exit 0
    fi

    # Default view: Display Table & Command Center
    render_table
    print_command_center
}

# Execute main entrypoint
main "$@"
