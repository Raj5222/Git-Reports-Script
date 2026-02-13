#!/bin/bash

# =========================================================
#  🎨 THEME & CONFIGURATION
# =========================================================
DEFAULT_LIMIT=10
STALE_DAYS=90 

C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_RED=$'\e[31m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_BLUE=$'\e[34m'
C_CYAN=$'\e[36m'
C_MAGENTA=$'\e[35m'

C_REPO=$'\033[38;5;39m'       
C_CURRENT=$'\033[38;5;46m'    
C_REMOTE=$'\033[38;5;244m'    
C_REMOTE_TXT=$'\033[38;5;39m' 
C_LOCAL=$'\033[38;5;255m'     
C_AUTHOR=$'\033[38;5;208m'    
C_TIME=$'\033[38;5;33m'       
C_WARN=$'\033[38;5;196m'      
C_BORDER=$'\033[38;5;237m'    
C_HEADER=$'\033[38;5;250m'    

ICON_REPO="📦"
ICON_BRANCH="🌿"
ICON_ARROW="➜"
ICON_STALE="!"
ICON_TIP="💡"
ICON_TEAM="👥"
ICON_LOG="📜"
ICON_SEARCH="🔍"

set -o pipefail

# =========================================================
#  🛡 DEPENDENCY CHECK & AUTO-INSTALLER
# =========================================================

check_and_install_deps() {
    local missing_deps=()
    
    # 1. Check for Git (Essential)
    if ! command -v git >/dev/null 2>&1; then missing_deps+=("git"); fi
    
    # 2. Check for Clipboard support (For -k feature)
    # We prefer xclip for Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
            missing_deps+=("xclip")
        fi
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "\n  ${C_YELLOW}${C_BOLD}⚠️  MISSING DEPENDENCIES:${C_RESET} ${missing_deps[*]}"
        read -p "  Would you like to install them now? (y/n): " confirm
        if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
            echo -e "  ${C_CYAN}Installing dependencies...${C_RESET}"
            sudo apt update && sudo apt install -y "${missing_deps[@]}"
            if [ $? -eq 0 ]; then
                echo -e "  ${C_GREEN}✔ Installation successful!${C_RESET}\n"
            else
                echo -e "  ${C_RED}✖ Installation failed. Please install manually: sudo apt install ${missing_deps[*]}${C_RESET}\n"
                exit 1
            fi
        else
            echo -e "  ${C_DIM}Continuing without optional tools...${C_RESET}\n"
        fi
    fi
}

# =========================================================
#  🛠 UTILITIES
# =========================================================

print_error() { echo -e "${C_RED}✖  $1${C_RESET}"; exit 1; }
print_succ()  { echo -e "${C_GREEN}✔  $1${C_RESET}"; }

visible_len() {
  local clean=$(echo -e "$1" | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g")
  echo ${#clean}
}

repeat() {
  if [ "$2" -gt 0 ]; then printf "%0.s$1" $(seq 1 "$2"); fi
}

print_cell() {
  local txt="$1"; local w="$2"; local col="$3"
  local vlen=$(visible_len "$txt")
  local pad=$((w - vlen))
  [ "$pad" -lt 0 ] && pad=0
  printf "%b%s%b" "$col" "$txt" "${C_RESET}"
  repeat " " "$pad"
}

copy_to_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then echo -n "$1" | pbcopy
  elif command -v xclip >/dev/null 2>&1; then echo -n "$1" | xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then echo -n "$1" | xsel --clipboard
  else
      check_and_install_deps;
      echo -e "${C_DIM}Hash: ${C_BOLD}$1${C_RESET}"
      return 1
  fi
}

# =========================================================
#  🚀 SETUP
# =========================================================

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && print_error "Not a git repository"
cd "$REPO_ROOT" || exit 1

LIMIT=$DEFAULT_LIMIT
FILTER_NAME=""
FILTER_CODE=""
MODE="DEFAULT"
DO_FETCH=0

ACT_CHECKOUT=""
ACT_MERGE=""
ACT_DELETE=""
ACT_RENAME=""
ACT_SHOW=""
ACT_TEAM=""
ACT_COPY_HASH=""

if [[ "$1" =~ ^[0-9]+$ ]]; then LIMIT="$1"; shift; fi

while getopts ":f:S:Huc:m:d:r:s:k:t:h" opt; do
  case ${opt} in
    f) FILTER_NAME="$OPTARG" ;;
    S) FILTER_CODE="$OPTARG"; MODE="CODE_SEARCH" ;;
    H) MODE="HISTORY" ;; 
    u) DO_FETCH=1 ;;
    c) ACT_CHECKOUT="$OPTARG" ;;
    t) ACT_TEAM="$OPTARG" ;;
    m) ACT_MERGE="$OPTARG" ;;
    d) ACT_DELETE="$OPTARG" ;;
    r) ACT_RENAME="$OPTARG" ;;
    s) ACT_SHOW="$OPTARG" ;;
    k) ACT_COPY_HASH="$OPTARG" ;;
    h) echo "Usage: git-record [limit] [-S 'code search'] [-H history] [-f filter]"; exit 0 ;;
  esac
done

# Dynamic Limit Expansion
for req_id in "$ACT_CHECKOUT" "$ACT_TEAM" "$ACT_MERGE" "$ACT_DELETE" "$ACT_RENAME" "$ACT_SHOW" "$ACT_COPY_HASH"; do
    if [[ "$req_id" =~ ^[0-9]+$ ]] && [ "$req_id" -gt "$LIMIT" ]; then LIMIT=$req_id; fi
done

if [ "$DO_FETCH" -eq 1 ]; then
  echo -e "${C_DIM}Fetching updates...${C_RESET}"
  git fetch --all --prune --quiet
fi

# =========================================================
#  📊 DATA ENGINE
# =========================================================

declare -a ROWS_ID ROWS_BRANCH_TEXT ROWS_BRANCH_REF ROWS_HASH ROWS_DATE ROWS_AUTHOR ROWS_AGE_RAW

load_data() {
  CUR_BRANCH=$(git branch --show-current)
  REPO_NAME=$(basename "$REPO_ROOT")
  COUNT_LOC=$(git for-each-ref refs/heads | wc -l)
  COUNT_REM=$(git for-each-ref refs/remotes | wc -l)

  W_ID=2; W_BRANCH=15; W_HASH=7; W_DATE=15; W_AUTHOR=10;
  local count=0
  local raw_refs=""

  if [ "$MODE" == "HISTORY" ]; then
      local git_cmd="git log -n $LIMIT --format='%H|%s|%h|%cr|%an|%ct'"
      while IFS='|' read -r fullref branch hash date author ts; do
          add_row "$fullref" "$branch" "$hash" "$date" "$author" "$ts"
      done < <(eval "$git_cmd")
  elif [ "$MODE" == "CODE_SEARCH" ]; then
      echo -e "${C_CYAN}${ICON_SEARCH} Searching file content for '${C_BOLD}$FILTER_CODE${C_RESET}${C_CYAN}'...${C_RESET}"
      # Optimized grep: searches local branches and origin remotes only for speed
      raw_refs=$(git grep -I -l "$FILTER_CODE" refs/heads refs/remotes/origin | sed 's/:.*//' | sort -u | head -n "$LIMIT")
      
      if [ -z "$raw_refs" ]; then
          echo -e "${C_RED}✖ No matches found for: '$FILTER_CODE'${C_RESET}"
          exit 0
      fi

      for ref in $raw_refs; do
          fullref=$(git rev-parse --symbolic-full-name "$ref" 2>/dev/null)
          [ -z "$fullref" ] && continue
          read -r hash date author ts < <(git show -s --format='%h|%cr|%an|%ct' "$fullref")
          branch=${fullref#refs/heads/}; branch=${branch#refs/remotes/}
          add_row "$fullref" "$branch" "$hash" "$date" "$author" "$ts"
      done
  else
      local git_cmd="git for-each-ref --sort=-committerdate --format='%(refname)|%(refname:short)|%(objectname:short)|%(committerdate:relative)|%(authorname)|%(committerdate:unix)' refs/heads refs/remotes"
      while IFS='|' read -r fullref branch hash date author ts; do
          if [ -n "$FILTER_NAME" ] && [[ ! "$branch" =~ $FILTER_NAME ]]; then continue; fi
          add_row "$fullref" "$branch" "$hash" "$date" "$author" "$ts"
      done < <(eval "$git_cmd")
  fi
  W_ID=$((W_ID)); W_BRANCH=$((W_BRANCH + 2)); W_HASH=$((W_HASH + 2)); W_DATE=$((W_DATE + 2)); W_AUTHOR=$((W_AUTHOR + 2));
  TOTAL_VISIBLE=$count
}

add_row() {
    local ref=$1 txt=$2 hash=$3 date=$4 author=$5 ts=$6
    [ "$count" -ge "$LIMIT" ] && return
    count=$((count + 1))
    ROWS_ID[$count]="$count"; ROWS_BRANCH_TEXT[$count]="$txt"; ROWS_BRANCH_REF[$count]="$ref"
    ROWS_HASH[$count]="$hash"; ROWS_DATE[$count]="$date"; ROWS_AUTHOR[$count]="$author"; ROWS_AGE_RAW[$count]="$ts"
    [ "${#count}" -gt "$W_ID" ] && W_ID=${#count}
    [ "${#txt}" -gt "$W_BRANCH" ] && W_BRANCH=${#txt}
    [ "${#hash}" -gt "$W_HASH" ] && W_HASH=${#hash}
    [ "${#date}" -gt "$W_DATE" ] && W_DATE=${#date}
    [ "${#author}" -gt "$W_AUTHOR" ] && W_AUTHOR=${#author}
}

render_table() {
  echo
  echo -e "  ${C_HEADER}REPOSITORY         CURRENT BRANCH${C_RESET}"
  echo -e "  ${C_BOLD}${C_REPO}${ICON_REPO} ${REPO_NAME^^}      ${C_CURRENT}${ICON_BRANCH} ${CUR_BRANCH}${C_RESET}"
  echo -e "  ${C_DIM}──────────────────────────────────────────${C_RESET}"
  
  col_name="BRANCH NAME"
  if [ "$MODE" == "HISTORY" ]; then 
      echo -e "  ${C_YELLOW}${ICON_LOG} HISTORY MODE: ${C_RESET}${C_DIM}Direct Commit Log${C_RESET}"
      col_name="COMMIT MESSAGE"
  elif [ "$MODE" == "CODE_SEARCH" ]; then
      echo -e "  ${C_CYAN}${ICON_SEARCH} SEARCH RESULTS: ${C_RESET}${C_DIM}'$FILTER_CODE'${C_RESET}"
  fi
  echo

  printf "  ${C_BORDER}┌"; repeat "─" $((W_ID+2)); printf "┬"; repeat "─" $((W_BRANCH+2)); printf "┬"; repeat "─" $((W_HASH+2)); printf "┬"; repeat "─" $((W_DATE+2)); printf "┬"; repeat "─" $((W_AUTHOR+2)); printf "┐${C_RESET}\n"
  printf "  ${C_BORDER}│${C_HEADER} "; print_cell "ID" "$W_ID" ""; printf " ${C_BORDER}│${C_HEADER} "; print_cell "$col_name" "$W_BRANCH" ""; printf " ${C_BORDER}│${C_HEADER} "; print_cell "COMMIT" "$W_HASH" ""; printf " ${C_BORDER}│${C_HEADER} "; print_cell "TIME" "$W_DATE" ""; printf " ${C_BORDER}│${C_HEADER} "; print_cell "UPDATED BY" "$W_AUTHOR" ""; printf " ${C_BORDER}│${C_RESET}\n"
  printf "  ${C_BORDER}├"; repeat "─" $((W_ID+2)); printf "┼"; repeat "─" $((W_BRANCH+2)); printf "┼"; repeat "─" $((W_HASH+2)); printf "┼"; repeat "─" $((W_DATE+2)); printf "┼"; repeat "─" $((W_AUTHOR+2)); printf "┤${C_RESET}\n"

  NOW=$(date +%s); STALE_SEC=$((STALE_DAYS * 86400))
  for ((i=1; i<=TOTAL_VISIBLE; i++)); do
    txt="${ROWS_BRANCH_TEXT[$i]}"; ref="${ROWS_BRANCH_REF[$i]}"; ts="${ROWS_AGE_RAW[$i]}"
    is_head=0; [ "$txt" == "$CUR_BRANCH" ] && [ "$MODE" != "HISTORY" ] && is_head=1
    
    printf "  ${C_BORDER}│${C_RESET} "; [ "$is_head" -eq 1 ] && print_cell "${ROWS_ID[$i]}" "$W_ID" "${C_CURRENT}${C_BOLD}" || print_cell "${ROWS_ID[$i]}" "$W_ID" "${C_DIM}"
    printf " ${C_BORDER}│${C_RESET} "
    if [ "$MODE" == "HISTORY" ]; then print_cell "$txt" "$W_BRANCH" "${C_LOCAL}"
    elif [ "$is_head" -eq 1 ]; then print_cell "${ICON_ARROW} ${txt}" "$W_BRANCH" "${C_CURRENT}${C_BOLD}"
    elif [[ "$ref" == refs/heads/* ]]; then [ $((NOW - ts)) -gt "$STALE_SEC" ] && print_cell "  ${ICON_STALE} ${txt}" "$W_BRANCH" "${C_WARN}" || print_cell "  ${txt}" "$W_BRANCH" "${C_LOCAL}"
    else
        pad=$((W_BRANCH - (${#txt} + 2))); printf "  "
        [[ "$txt" == origin/* ]] && printf "${C_REMOTE}origin/${C_REMOTE_TXT}${txt#origin/}${C_RESET}" || printf "${C_REMOTE}${txt}${C_RESET}"
        repeat " " "$pad"
    fi
    printf " ${C_BORDER}│${C_RESET} "; [ "$is_head" -eq 1 ] && print_cell "${ROWS_HASH[$i]}" "$W_HASH" "${C_CURRENT}" || print_cell "${ROWS_HASH[$i]}" "$W_HASH" "${C_DIM}"
    printf " ${C_BORDER}│${C_RESET} "; [ "$is_head" -eq 1 ] && print_cell "${ROWS_DATE[$i]}" "$W_DATE" "${C_CURRENT}" || print_cell "${ROWS_DATE[$i]}" "$W_DATE" "${C_TIME}"
    printf " ${C_BORDER}│${C_RESET} "; [ "$is_head" -eq 1 ] && print_cell "${ROWS_AUTHOR[$i]}" "$W_AUTHOR" "${C_CURRENT}" || print_cell "${ROWS_AUTHOR[$i]}" "$W_AUTHOR" "${C_AUTHOR}"
    printf " ${C_BORDER}│${C_RESET}\n"
  done
  printf "  ${C_BORDER}└"; repeat "─" $((W_ID+2)); printf "┴"; repeat "─" $((W_BRANCH+2)); printf "┴"; repeat "─" $((W_HASH+2)); printf "┴"; repeat "─" $((W_DATE+2)); printf "┴"; repeat "─" $((W_AUTHOR+2)); printf "┘${C_RESET}\n"
}

# =========================================================
#  ⚡ EXECUTION
# =========================================================

load_data

print_suggestions() {
  echo
  echo -e "  ${C_BOLD}${ICON_TIP} COMMAND CENTER${C_RESET}"
  echo
  printf "  ${C_CYAN}%-26s${C_RESET}  ${C_CYAN}%-26s${C_RESET}  ${C_CYAN}%-26s${C_RESET}\n" "🚀 WORKFLOW" "🔍 INSPECT" "🛠  MANAGE"
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "git-record -c <ID>" "git-record -t <ID>" "git-record -d <ID>"
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "(Checkout ID)" "(Show Contributors)" "(Delete Branch)"
  echo
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "git-record -H" "git-record -s <ID>" "git-record -m <ID>"
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "(Branch History)" "(Commit Details)" "(Merge into Current)"
  echo
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "git-record -f <text>" "git-record -S <text>" "git-record -r <ID>"
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "(Filter Name)" "(Search Code)" "(Rename Branch)"
  echo
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "git-record <limit>" "git-record -u" "git-record -k <ID>"
  printf "  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}  ${C_DIM}%-26s${C_RESET}\n" "(e.g. 50 records)" "(Fetch & Prune)" "(Copy Hash)"
  echo
}

if [ -n "$ACT_TEAM" ]; then
    id=$ACT_TEAM; name="${ROWS_BRANCH_TEXT[$id]}"; ref="${ROWS_BRANCH_REF[$id]}"
    BASE=""; for b in master main staging develop; do git show-ref --verify --quiet "refs/remotes/origin/$b" && BASE="origin/$b" && break; done
    echo -e "\n  ${C_BOLD}${ICON_TEAM} DIRECT CONTRIBUTORS: ${C_BLUE}${name}${C_RESET}"
    if [ -n "$BASE" ]; then git shortlog -sn --no-merges "$BASE..$ref" | sed 's/^/   ✔ /'
    else git shortlog -sn --no-merges -n 10 "$ref" | sed 's/^/   ✔ /'; fi
    echo; exit 0
fi

if [ -z "$ACT_CHECKOUT" ] && [ -z "$ACT_MERGE" ] && [ -z "$ACT_DELETE" ] && [ -z "$ACT_RENAME" ] && [ -z "$ACT_SHOW" ] && [ -z "$ACT_COPY_HASH" ]; then
    render_table;
    print_suggestions;
    check_and_install_deps;
    exit 0;
fi

if [ -n "$ACT_CHECKOUT" ]; then
    name="${ROWS_BRANCH_TEXT[$ACT_CHECKOUT]}"; ref="${ROWS_BRANCH_REF[$ACT_CHECKOUT]}"
    [[ "$ref" == refs/heads/* ]] && git checkout "$name" || (clean=${name#*/}; git checkout "$clean" 2>/dev/null || git checkout -b "$clean" --track "$name")
elif [ -n "$ACT_SHOW" ]; then
    git show --stat "${ROWS_HASH[$ACT_SHOW]}"
elif [ -n "$ACT_DELETE" ]; then
    git branch -D "${ROWS_BRANCH_TEXT[$ACT_DELETE]}" && print_succ "Deleted branch."
elif [ -n "$ACT_MERGE" ]; then
    git merge "${ROWS_BRANCH_TEXT[$ACT_MERGE]}"
elif [ -n "$ACT_COPY_HASH" ]; then
    copy_to_clipboard "${ROWS_HASH[$ACT_COPY_HASH]}" && echo -e "${C_DIM}Hash: ${C_BOLD}${ROWS_HASH[$ACT_COPY_HASH]}${C_RESET}" && print_succ "Commit Hash copied."
fi
