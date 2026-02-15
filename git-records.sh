#!/bin/bash

# =========================================================
#  🎨 THEME & CONFIGURATION
# =========================================================
DEFAULT_LIMIT=10
STALE_DAYS=90 
CLEANUP_THRESHOLD=60
VELOCITY_DAYS=30

C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_RED=$'\e[31m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_BLUE=$'\e[34m'
C_CYAN=$'\e[36m'
C_MAGENTA=$'\e[35m'
C_WHITE=$'\e[37m'

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
ICON_STALE="⚠"
ICON_TIP="💡"
ICON_TEAM="👥"
ICON_LOG="📜"
ICON_SEARCH="🔍"
ICON_AHEAD="↑"
ICON_BEHIND="↓"
ICON_TAG="🏷️"
ICON_STASH="📦"
ICON_STATS="📊"
ICON_CLEANUP="🧹"
ICON_GRAPH="📈"
ICON_CONFLICT="⚔️"
ICON_CI="🔧"
ICON_GITHUB="🐙"
ICON_GITLAB="🦊"

set -o pipefail

# =========================================================
#  🛠 UTILITIES
# =========================================================

print_error() { echo -e "${C_RED}✖  $1${C_RESET}"; exit 1; }
print_succ()  { echo -e "${C_GREEN}✔  $1${C_RESET}"; }
print_warn()  { echo -e "${C_YELLOW}⚠  $1${C_RESET}"; }
print_info()  { echo -e "${C_CYAN}ℹ  $1${C_RESET}"; }

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
  if command -v pbcopy >/dev/null 2>&1; then 
    echo -n "$1" | pbcopy
  elif command -v xclip >/dev/null 2>&1; then 
    echo -n "$1" | xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then 
    echo -n "$1" | xsel --clipboard
  else
    echo -e "${C_DIM}Hash: ${C_BOLD}$1${C_RESET}"
    return 1
  fi
}

draw_bar() {
    local value=$1
    local max=$2
    local width=${3:-20}
    local char=${4:-"█"}
    local color=${5:-$C_GREEN}
    
    [ "$max" -eq 0 ] && max=1
    local filled=$((value * width / max))
    [ "$filled" -gt "$width" ] && filled=$width
    
    echo -n "${color}"
    repeat "$char" "$filled"
    echo -n "${C_DIM}"
    repeat "░" $((width - filled))
    echo -n "${C_RESET}"
}

# =========================================================
#  🌐 API INTEGRATION
# =========================================================

get_github_token() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN"
    elif [ -n "$GH_TOKEN" ]; then
        echo "$GH_TOKEN"
    else
        git config --global github.token 2>/dev/null
    fi
}

get_gitlab_token() {
    if [ -n "$GITLAB_TOKEN" ]; then
        echo "$GITLAB_TOKEN"
    else
        git config --global gitlab.token 2>/dev/null
    fi
}

detect_remote_platform() {
    local remote_url=$(git config --get remote.origin.url 2>/dev/null)
    [ -z "$remote_url" ] && return 1
    
    if [[ "$remote_url" =~ github\.com ]]; then
        echo "github"
    elif [[ "$remote_url" =~ gitlab\.com ]]; then
        echo "gitlab"
    else
        return 1
    fi
}

parse_github_repo() {
    local url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    fi
}

parse_gitlab_repo() {
    local url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ gitlab\.com[:/]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    fi
}

fetch_github_ci_status() {
    local repo=$1
    local branch=$2
    local token=$(get_github_token)
    [ -z "$token" ] && return 1
    
    curl -s -H "Authorization: token $token" \
         -H "Accept: application/vnd.github.v3+json" \
         "https://api.github.com/repos/$repo/commits/$branch/status" 2>/dev/null
}

fetch_gitlab_ci_status() {
    local repo=$1
    local branch=$2
    local token=$(get_gitlab_token)
    [ -z "$token" ] && return 1
    
    local project_id=$(echo "$repo" | sed 's/\//%2F/g')
    curl -s -H "PRIVATE-TOKEN: $token" \
         "https://gitlab.com/api/v4/projects/$project_id/repository/commits/$branch" 2>/dev/null
}

# =========================================================
#  📊 ANALYTICS & STATISTICS
# =========================================================

calculate_commit_frequency() {
    local branch=$1
    local days=${2:-30}
    local since=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)
    
    git log --since="$since" --format='%cd' --date=short "$branch" 2>/dev/null | \
        sort | uniq -c | awk '{sum+=$1} END {print (NR>0 ? sum/NR : 0)}'
}

get_branch_metrics() {
    local branch=$1
    local base=${2:-"origin/main"}
    
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="origin/master"
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="main"
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="master"
    
    local commits=$(git rev-list --count "$base..$branch" 2>/dev/null || echo 0)
    local files=$(git diff --name-only "$base...$branch" 2>/dev/null | wc -l)
    local additions=$(git diff --numstat "$base...$branch" 2>/dev/null | awk '{add+=$1} END {print add+0}')
    local deletions=$(git diff --numstat "$base...$branch" 2>/dev/null | awk '{del+=$2} END {print del+0}')
    local authors=$(git log --format='%an' "$base..$branch" 2>/dev/null | sort -u | wc -l)
    
    echo "$commits|$files|$additions|$deletions|$authors"
}

calculate_team_velocity() {
    local days=${1:-30}
    local since=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null)
    
    echo -e "\n  ${C_BOLD}${ICON_GRAPH} TEAM VELOCITY (Last $days days)${C_RESET}\n"
    
    echo -e "  ${C_HEADER}Commits by Author:${C_RESET}"
    git log --since="$since" --format='%an' --all 2>/dev/null | \
        sort | uniq -c | sort -rn | head -10 | while read count author; do
        printf "    %-25s " "$author"
        draw_bar "$count" 100 20
        printf " %3d\n" "$count"
    done
    
    echo
    echo -e "  ${C_HEADER}Daily Commit Activity:${C_RESET}"
    git log --since="$since" --format='%cd' --date=short --all 2>/dev/null | \
        sort | uniq -c | tail -14 | while read count date; do
        printf "    %-12s " "$date"
        draw_bar "$count" 50 20
        printf " %3d\n" "$count"
    done
    
    echo
    echo -e "  ${C_HEADER}Overall Statistics:${C_RESET}"
    total_commits=$(git log --since="$since" --all --oneline 2>/dev/null | wc -l)
    total_authors=$(git log --since="$since" --format='%an' --all 2>/dev/null | sort -u | wc -l)
    avg_per_day=$((total_commits / days))
    
    echo -e "    ${C_CYAN}Total Commits:${C_RESET}  $total_commits"
    echo -e "    ${C_CYAN}Active Authors:${C_RESET} $total_authors"
    echo -e "    ${C_CYAN}Avg/Day:${C_RESET}        $avg_per_day"
}

generate_branch_graph() {
    echo -e "\n  ${C_BOLD}${ICON_GRAPH} BRANCH DEPENDENCY GRAPH${C_RESET}\n"
    
    branches=($(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | head -20))
    main_branch="main"
    git rev-parse --verify main >/dev/null 2>&1 || main_branch="master"
    
    echo -e "  ${C_HEADER}Branch Relationships:${C_RESET}\n"
    
    for branch in "${branches[@]}"; do
        [ "$branch" == "$main_branch" ] && continue
        
        ahead=$(git rev-list --count "$main_branch..$branch" 2>/dev/null || echo 0)
        behind=$(git rev-list --count "$branch..$main_branch" 2>/dev/null || echo 0)
        
        level="  "
        [ "$ahead" -gt 20 ] && level="    "
        [ "$ahead" -gt 50 ] && level="      "
        
        printf "${level}${C_CYAN}├─${C_RESET} %-30s " "$branch"
        [ "$ahead" -gt 0 ] && printf "${C_GREEN}+%d${C_RESET} " "$ahead"
        [ "$behind" -gt 0 ] && printf "${C_RED}-%d${C_RESET} " "$behind"
        
        total=$((ahead + behind))
        if [ "$total" -gt 100 ]; then
            printf "${C_RED}[highly diverged]${C_RESET}"
        elif [ "$total" -gt 50 ]; then
            printf "${C_YELLOW}[diverged]${C_RESET}"
        elif [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            printf "${C_GREEN}[in sync]${C_RESET}"
        fi
        echo
    done
    echo
}

predict_merge_conflicts() {
    local branch1=$1
    local branch2=${2:-"main"}
    
    git rev-parse --verify "$branch2" >/dev/null 2>&1 || branch2="master"
    
    echo -e "\n  ${C_BOLD}${ICON_CONFLICT} MERGE CONFLICT PREDICTION${C_RESET}"
    echo -e "  ${C_CYAN}$branch1${C_RESET} ${C_DIM}into${C_RESET} ${C_CYAN}$branch2${C_RESET}\n"
    
    files1=($(git diff --name-only "$branch2...$branch1" 2>/dev/null))
    files2=($(git diff --name-only "$branch1...$branch2" 2>/dev/null))
    
    conflicts=()
    for f1 in "${files1[@]}"; do
        for f2 in "${files2[@]}"; do
            if [ "$f1" == "$f2" ]; then
                conflicts+=("$f1")
            fi
        done
    done
    
    if [ ${#conflicts[@]} -eq 0 ]; then
        echo -e "  ${C_GREEN}✓ No potential conflicts detected${C_RESET}"
        echo -e "  ${C_DIM}Branches modify different files${C_RESET}\n"
        return 0
    fi
    
    echo -e "  ${C_YELLOW}⚠ Potential conflicts in ${#conflicts[@]} file(s):${C_RESET}\n"
    
    for file in "${conflicts[@]}"; do
        changes1=$(git diff "$branch2" "$branch1" -- "$file" 2>/dev/null | grep "^[+-]" | grep -v "^[+-]\{3\}" | wc -l)
        changes2=$(git diff "$branch1" "$branch2" -- "$file" 2>/dev/null | grep "^[+-]" | grep -v "^[+-]\{3\}" | wc -l)
        
        printf "    ${C_RED}⚔${C_RESET}  %-40s " "$file"
        printf "${C_YELLOW}%d/%d changes${C_RESET}\n" "$changes1" "$changes2"
    done
    
    echo
    echo -e "  ${C_HEADER}Recommendation:${C_RESET}"
    echo -e "  ${C_DIM}Review these files before merging${C_RESET}"
    echo -e "  ${C_DIM}Use: git diff $branch2...$branch1 -- <file>${C_RESET}\n"
}

suggest_cleanup() {
    echo -e "\n  ${C_BOLD}${ICON_CLEANUP} SMART CLEANUP SUGGESTIONS${C_RESET}\n"
    
    stale_branches=()
    merged_branches=()
    abandoned_branches=()
    now=$(date +%s)
    threshold=$((CLEANUP_THRESHOLD * 86400))
    
    main_branch="main"
    git rev-parse --verify main >/dev/null 2>&1 || main_branch="master"
    
    while IFS='|' read -r branch date timestamp; do
        [ "$branch" == "$main_branch" ] || [ "$branch" == "$(git branch --show-current)" ] && continue
        
        if git branch --merged "$main_branch" | grep -q "^\s*$branch$" 2>/dev/null; then
            merged_branches+=("$branch")
            continue
        fi
        
        age=$((now - timestamp))
        if [ "$age" -gt "$threshold" ]; then
            commits=$(git log --since="60 days ago" --oneline "$branch" 2>/dev/null | wc -l)
            if [ "$commits" -eq 0 ]; then
                abandoned_branches+=("$branch")
            else
                stale_branches+=("$branch")
            fi
        fi
    done < <(git for-each-ref --format='%(refname:short)|%(committerdate:relative)|%(committerdate:unix)' refs/heads 2>/dev/null)
    
    total_suggestions=$((${#merged_branches[@]} + ${#stale_branches[@]} + ${#abandoned_branches[@]}))
    
    if [ "$total_suggestions" -eq 0 ]; then
        echo -e "  ${C_GREEN}✓ No cleanup needed!${C_RESET}"
        echo -e "  ${C_DIM}All branches are active and unmerged${C_RESET}\n"
        return 0
    fi
    
    if [ ${#merged_branches[@]} -gt 0 ]; then
        echo -e "  ${C_GREEN}✓ Merged Branches${C_RESET} ${C_DIM}(safe to delete)${C_RESET}"
        for branch in "${merged_branches[@]}"; do
            echo -e "    ${C_DIM}└─${C_RESET} $branch"
        done
        echo
    fi
    
    if [ ${#abandoned_branches[@]} -gt 0 ]; then
        echo -e "  ${C_RED}⚠ Abandoned Branches${C_RESET} ${C_DIM}(no activity >60 days)${C_RESET}"
        for branch in "${abandoned_branches[@]}"; do
            echo -e "    ${C_DIM}└─${C_RESET} $branch"
        done
        echo
    fi
    
    if [ ${#stale_branches[@]} -gt 0 ]; then
        echo -e "  ${C_YELLOW}⚠ Stale Branches${C_RESET} ${C_DIM}(inactive >$CLEANUP_THRESHOLD days)${C_RESET}"
        for branch in "${stale_branches[@]}"; do
            echo -e "    ${C_DIM}└─${C_RESET} $branch"
        done
        echo
    fi
    
    echo -e "  ${C_BOLD}Quick Actions:${C_RESET}"
    [ ${#merged_branches[@]} -gt 0 ] && echo -e "  ${C_CYAN}Delete merged:${C_RESET}     git branch -d ${merged_branches[*]}"
    [ ${#abandoned_branches[@]} -gt 0 ] && echo -e "  ${C_CYAN}Force delete old:${C_RESET}  git branch -D ${abandoned_branches[*]}"
    echo
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
ACT_COMPARE=""
ACT_TAGS=""
ACT_STASH=""
ACT_EXPORT=""
ACT_INTERACTIVE=0
ACT_STATUS=""
ACT_BULK_DELETE=""
ACT_STATS=""
ACT_VELOCITY=""
ACT_CLEANUP=""
ACT_GRAPH=""
ACT_CONFLICTS=""
ACT_CI=""

if [[ "$1" =~ ^[0-9]+$ ]]; then LIMIT="$1"; shift; fi

while getopts ":f:S:Huc:m:d:r:s:k:t:C:TLe:iP:b:VGAX:M:N:h" opt; do
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
    C) ACT_COMPARE="$OPTARG" ;;
    T) ACT_TAGS=1 ;;
    L) ACT_STASH=1 ;;
    e) ACT_EXPORT="$OPTARG" ;;
    i) ACT_INTERACTIVE=1 ;;
    P) ACT_STATUS="$OPTARG" ;;
    b) ACT_BULK_DELETE="$OPTARG" ;;
    V) ACT_VELOCITY=1 ;;
    G) ACT_GRAPH=1 ;;
    A) ACT_CLEANUP=1 ;;
    X) ACT_STATS="$OPTARG" ;;
    M) ACT_CONFLICTS="$OPTARG" ;;
    N) ACT_CI="$OPTARG" ;;
    h) cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                           GIT-RECORD                           ║
╚════════════════════════════════════════════════════════════════╝

BASIC USAGE:
  git-record [limit]              Show branches (default: 10)
  git-record 50                   Show 50 branches
  git-record -f <text>            Filter branches by name
  git-record -H                   Show commit history
  git-record -u                   Fetch updates before display

WORKFLOW ACTIONS:
  -c <ID>     Checkout branch by ID
  -m <ID>     Merge branch into current
  -d <ID>     Delete branch by ID
  -r <ID>     Rename branch (interactive)
  -b <IDs>    Bulk delete branches (comma-separated)

INSPECTION:
  -s <ID>     Show commit details
  -t <ID>     Show branch contributors
  -k <ID>     Copy commit hash to clipboard
  -S <text>   Search code across branches
  -C <ID1:ID2> Compare two branches
  -P <ID>     Show push/pull status (ahead/behind)

BASIC FEATURES:
  -T          Show repository tags
  -L          Show stash list
  -e <format> Export data (csv|json|md)
  -i          Interactive mode

🚀 ADVANCED FEATURES (NEW):
  -V          Team velocity dashboard
  -G          Branch dependency graph
  -A          Smart cleanup suggestions
  -X <ID>     Detailed branch statistics
  -M <ID>     Predict merge conflicts
  -N <ID>     CI/CD status (GitHub/GitLab)

API INTEGRATION:
  GitHub: Set GITHUB_TOKEN or GH_TOKEN environment variable
          Or: git config --global github.token YOUR_TOKEN
  
  GitLab: Set GITLAB_TOKEN environment variable
          Or: git config --global gitlab.token YOUR_TOKEN

EXAMPLES:
  git-record -V                   # Team velocity last 30 days
  git-record -G                   # Visualize branch relationships
  git-record -A                   # Get cleanup recommendations
  git-record -X 3                 # Detailed stats for branch #3
  git-record -M 5                 # Check merge conflicts
  git-record -N 3                 # Check CI/CD status
  git-record -C 1:5 -M 1          # Compare and check conflicts

EOF
      exit 0 
      ;;
    \?) print_error "Invalid option: -$OPTARG. Use -h for help." ;;
  esac
done

# Dynamic Limit Expansion
for req_id in "$ACT_CHECKOUT" "$ACT_TEAM" "$ACT_MERGE" "$ACT_DELETE" "$ACT_RENAME" "$ACT_SHOW" "$ACT_COPY_HASH" "$ACT_STATUS" "$ACT_STATS" "$ACT_CONFLICTS" "$ACT_CI"; do
    if [[ "$req_id" =~ ^[0-9]+$ ]] && [ "$req_id" -gt "$LIMIT" ]; then LIMIT=$req_id; fi
done

if [ -n "$ACT_COMPARE" ]; then
    IFS=':' read -r ID1 ID2 <<< "$ACT_COMPARE"
    for id in "$ID1" "$ID2"; do
        if [[ "$id" =~ ^[0-9]+$ ]] && [ "$id" -gt "$LIMIT" ]; then LIMIT=$id; fi
    done
fi

if [ "$DO_FETCH" -eq 1 ]; then
  echo -e "${C_DIM}Fetching updates...${C_RESET}"
  git fetch --all --prune --quiet 2>/dev/null || print_warn "Fetch failed - continuing with local data"
fi

# =========================================================
#  📊 DATA ENGINE
# =========================================================

declare -a ROWS_ID ROWS_BRANCH_TEXT ROWS_BRANCH_REF ROWS_HASH ROWS_DATE ROWS_AUTHOR ROWS_AGE_RAW ROWS_MESSAGE

load_data() {
  CUR_BRANCH=$(git branch --show-current)
  [ -z "$CUR_BRANCH" ] && CUR_BRANCH="(detached HEAD)"
  REPO_NAME=$(basename "$REPO_ROOT")
  COUNT_LOC=$(git for-each-ref refs/heads 2>/dev/null | wc -l)
  COUNT_REM=$(git for-each-ref refs/remotes 2>/dev/null | wc -l)

  W_ID=2; W_BRANCH=15; W_HASH=7; W_DATE=15; W_AUTHOR=10; W_MESSAGE=20
  count=0

  if [ "$MODE" == "HISTORY" ]; then
      while IFS='|' read -r hash subject shorthash date author ts; do
          add_row "commit/$hash" "$subject" "$shorthash" "$date" "$author" "$ts" "$subject"
      done < <(git log -n "$LIMIT" --format='%H|%s|%h|%cr|%an|%ct' 2>/dev/null)
  elif [ "$MODE" == "CODE_SEARCH" ]; then
      echo -e "${C_CYAN}${ICON_SEARCH} Searching file content for '${C_BOLD}$FILTER_CODE${C_RESET}${C_CYAN}'...${C_RESET}"
      
      branches=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null)
      found_branches=()
      
      for branch in $branches; do
          if git grep -q "$FILTER_CODE" "$branch" 2>/dev/null; then
              found_branches+=("$branch")
              [ "${#found_branches[@]}" -ge "$LIMIT" ] && break
          fi
      done
      
      if [ ${#found_branches[@]} -eq 0 ]; then
          echo -e "${C_RED}✖ No matches found for: '$FILTER_CODE'${C_RESET}"
          exit 0
      fi

      for branch in "${found_branches[@]}"; do
          fullref=$(git rev-parse --symbolic-full-name "$branch" 2>/dev/null)
          [ -z "$fullref" ] && continue
          IFS='|' read -r hash date author ts msg < <(git show -s --format='%h|%cr|%an|%ct|%s' "$fullref" 2>/dev/null)
          add_row "$fullref" "$branch" "$hash" "$date" "$author" "$ts" "$msg"
      done
  else
      while IFS='|' read -r fullref branch hash date author ts msg; do
          if [ -n "$FILTER_NAME" ] && [[ ! "$branch" =~ $FILTER_NAME ]]; then continue; fi
          add_row "$fullref" "$branch" "$hash" "$date" "$author" "$ts" "$msg"
      done < <(git for-each-ref --sort=-committerdate --format='%(refname)|%(refname:short)|%(objectname:short)|%(committerdate:relative)|%(authorname)|%(committerdate:unix)|%(subject)' refs/heads refs/remotes 2>/dev/null)
  fi
  
  W_ID=$((W_ID + 2)); W_BRANCH=$((W_BRANCH + 2)); W_HASH=$((W_HASH + 2))
  W_DATE=$((W_DATE + 2)); W_AUTHOR=$((W_AUTHOR + 2))
  TOTAL_VISIBLE=$count
}

add_row() {
    local ref=$1 txt=$2 hash=$3 date=$4 author=$5 ts=$6 msg=$7
    [ "$count" -ge "$LIMIT" ] && return
    count=$((count + 1))
    ROWS_ID[$count]="$count"
    ROWS_BRANCH_TEXT[$count]="$txt"
    ROWS_BRANCH_REF[$count]="$ref"
    ROWS_HASH[$count]="$hash"
    ROWS_DATE[$count]="$date"
    ROWS_AUTHOR[$count]="$author"
    ROWS_AGE_RAW[$count]="$ts"
    ROWS_MESSAGE[$count]="${msg:0:30}"
    
    [ "${#count}" -gt "$((W_ID - 2))" ] && W_ID=$((${#count} + 2))
    [ "${#txt}" -gt "$((W_BRANCH - 2))" ] && W_BRANCH=$((${#txt} + 2))
    [ "${#hash}" -gt "$((W_HASH - 2))" ] && W_HASH=$((${#hash} + 2))
    [ "${#date}" -gt "$((W_DATE - 2))" ] && W_DATE=$((${#date} + 2))
    [ "${#author}" -gt "$((W_AUTHOR - 2))" ] && W_AUTHOR=$((${#author} + 2))
}

get_branch_status() {
    local branch=$1
    upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    
    if [ -n "$upstream" ]; then
        ahead=$(git rev-list --count "$upstream..$branch" 2>/dev/null || echo 0)
        behind=$(git rev-list --count "$branch..$upstream" 2>/dev/null || echo 0)
        
        if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
            echo "${C_YELLOW}${ICON_AHEAD}${ahead} ${ICON_BEHIND}${behind}${C_RESET}"
        elif [ "$ahead" -gt 0 ]; then
            echo "${C_GREEN}${ICON_AHEAD}${ahead}${C_RESET}"
        elif [ "$behind" -gt 0 ]; then
            echo "${C_RED}${ICON_BEHIND}${behind}${C_RESET}"
        else
            echo "${C_DIM}✓${C_RESET}"
        fi
    else
        echo "${C_DIM}-${C_RESET}"
    fi
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
      echo -e "  ${C_CYAN}${ICON_SEARCH} CODE SEARCH: ${C_RESET}${C_DIM}'$FILTER_CODE'${C_RESET}"
  fi
  echo

  printf "  ${C_BORDER}┌"; repeat "─" $W_ID; printf "┬"; repeat "─" $W_BRANCH; printf "┬"; repeat "─" $W_HASH; printf "┬"; repeat "─" $W_DATE; printf "┬"; repeat "─" $W_AUTHOR; printf "┐${C_RESET}\n"
  printf "  ${C_BORDER}│${C_HEADER}"; print_cell "ID" "$((W_ID-2))" ""; printf "  ${C_BORDER}│${C_HEADER}"; print_cell "$col_name" "$((W_BRANCH-2))" ""; printf "  ${C_BORDER}│${C_HEADER}"; print_cell "COMMIT" "$((W_HASH-2))" ""; printf "  ${C_BORDER}│${C_HEADER}"; print_cell "TIME" "$((W_DATE-2))" ""; printf "  ${C_BORDER}│${C_HEADER}"; print_cell "UPDATED BY" "$((W_AUTHOR-2))" ""; printf "  ${C_BORDER}│${C_RESET}\n"
  printf "  ${C_BORDER}├"; repeat "─" $W_ID; printf "┼"; repeat "─" $W_BRANCH; printf "┼"; repeat "─" $W_HASH; printf "┼"; repeat "─" $W_DATE; printf "┼"; repeat "─" $W_AUTHOR; printf "┤${C_RESET}\n"

  NOW=$(date +%s); STALE_SEC=$((STALE_DAYS * 86400))
  
  for ((i=1; i<=TOTAL_VISIBLE; i++)); do
    txt="${ROWS_BRANCH_TEXT[$i]}"; ref="${ROWS_BRANCH_REF[$i]}"; ts="${ROWS_AGE_RAW[$i]}"
    is_head=0; [ "$txt" == "$CUR_BRANCH" ] && [ "$MODE" != "HISTORY" ] && is_head=1
    
    printf "  ${C_BORDER}│${C_RESET}"
    [ "$is_head" -eq 1 ] && print_cell "${ROWS_ID[$i]}" "$((W_ID-2))" "${C_CURRENT}${C_BOLD}" || print_cell "${ROWS_ID[$i]}" "$((W_ID-2))" "${C_DIM}"
    printf "  ${C_BORDER}│${C_RESET}"
    
    if [ "$MODE" == "HISTORY" ]; then 
        print_cell "$txt" "$((W_BRANCH-2))" "${C_LOCAL}"
    elif [ "$is_head" -eq 1 ]; then 
        print_cell "${ICON_ARROW} ${txt}" "$((W_BRANCH-2))" "${C_CURRENT}${C_BOLD}"
    elif [[ "$ref" == refs/heads/* ]]; then 
        if [ $((NOW - ts)) -gt "$STALE_SEC" ]; then
            print_cell "${ICON_STALE} ${txt}" "$((W_BRANCH-2))" "${C_WARN}"
        else
            print_cell "  ${txt}" "$((W_BRANCH-2))" "${C_LOCAL}"
        fi
    else
        if [[ "$txt" == origin/* ]]; then
            display="origin/${C_REMOTE_TXT}${txt#origin/}"
        else
            display="$txt"
        fi
        print_cell "  ${display}" "$((W_BRANCH-2))" "${C_REMOTE}"
    fi
    
    printf "  ${C_BORDER}│${C_RESET}"
    [ "$is_head" -eq 1 ] && print_cell "${ROWS_HASH[$i]}" "$((W_HASH-2))" "${C_CURRENT}" || print_cell "${ROWS_HASH[$i]}" "$((W_HASH-2))" "${C_DIM}"
    printf "  ${C_BORDER}│${C_RESET}"
    [ "$is_head" -eq 1 ] && print_cell "${ROWS_DATE[$i]}" "$((W_DATE-2))" "${C_CURRENT}" || print_cell "${ROWS_DATE[$i]}" "$((W_DATE-2))" "${C_TIME}"
    printf "  ${C_BORDER}│${C_RESET}"
    [ "$is_head" -eq 1 ] && print_cell "${ROWS_AUTHOR[$i]}" "$((W_AUTHOR-2))" "${C_CURRENT}" || print_cell "${ROWS_AUTHOR[$i]}" "$((W_AUTHOR-2))" "${C_AUTHOR}"
    printf "  ${C_BORDER}│${C_RESET}\n"
  done
  
  printf "  ${C_BORDER}└"; repeat "─" $W_ID; printf "┴"; repeat "─" $W_BRANCH; printf "┴"; repeat "─" $W_HASH; printf "┴"; repeat "─" $W_DATE; printf "┴"; repeat "─" $W_AUTHOR; printf "┘${C_RESET}\n"
}

print_suggestions() {
  echo
  echo -e "  ${C_BOLD}${ICON_TIP} COMMAND CENTER${C_RESET}"
  echo
  printf "  ${C_CYAN}%-30s${C_RESET}  ${C_CYAN}%-30s${C_RESET}  ${C_CYAN}%-30s${C_RESET}\n" "🚀 WORKFLOW" "🔍 INSPECT" "📊 ANALYTICS"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -c <ID>" "git-record -s <ID>" "git-record -V"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Checkout)" "(Details)" "(Team Velocity)"
  echo
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -m <ID>" "git-record -C <ID:ID>" "git-record -G"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Merge)" "(Compare)" "(Branch Graph)"
  echo
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -b <IDs>" "git-record -M <ID>" "git-record -A"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Bulk Delete)" "(Conflicts)" "(Cleanup)"
  echo
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -e csv" "git-record -X <ID>" "git-record -N <ID>"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Export)" "(Statistics)" "(CI Status)"
  echo
  echo -e "  ${C_DIM}Use -h for complete help | -i for interactive mode${C_RESET}"
  echo
}

# =========================================================
#  ⚡ EXECUTION - ADVANCED FEATURES FIRST
# =========================================================

if [ -n "$ACT_VELOCITY" ]; then
    calculate_team_velocity
    exit 0
fi

if [ -n "$ACT_GRAPH" ]; then
    generate_branch_graph
    exit 0
fi

if [ -n "$ACT_CLEANUP" ]; then
    suggest_cleanup
    exit 0
fi

if [ -n "$ACT_TAGS" ]; then
    echo -e "\n  ${C_BOLD}${ICON_TAG} REPOSITORY TAGS${C_RESET}\n"
    if ! git tag -l | head -1 >/dev/null 2>&1; then
        echo -e "  ${C_DIM}No tags found${C_RESET}\n"
        exit 0
    fi
    git tag -l --sort=-creatordate --format='  %(refname:short)|%(creatordate:relative)|%(subject)' | head -n "${LIMIT}" | while IFS='|' read -r tag date msg; do
        printf "  ${C_CYAN}%-20s${C_RESET} ${C_DIM}%-15s${C_RESET} %s\n" "$tag" "$date" "$msg"
    done
    echo
    exit 0
fi

if [ -n "$ACT_STASH" ]; then
    echo -e "\n  ${C_BOLD}${ICON_STASH} STASH LIST${C_RESET}\n"
    if ! git stash list | head -1 >/dev/null 2>&1; then
        echo -e "  ${C_DIM}No stashed changes${C_RESET}\n"
        exit 0
    fi
    git stash list --format='  %C(yellow)%gd%C(reset)|%C(cyan)%cr%C(reset)|%s' | head -n "${LIMIT}" | while IFS='|' read -r stash date msg; do
        printf "%s  ${C_DIM}%-15s${C_RESET} %s\n" "$stash" "$date" "$msg"
    done
    echo -e "\n  ${C_DIM}Use: git stash apply <stash@{N}> to restore${C_RESET}\n"
    exit 0
fi

# =========================================================
# LOAD DATA - CRITICAL
# =========================================================

load_data

# =========================================================
# HANDLE -X, -M, -N BEFORE TABLE DISPLAY
# =========================================================

if [ -n "$ACT_STATS" ]; then
    branch="${ROWS_BRANCH_TEXT[$ACT_STATS]}"
    
    if [ -z "$branch" ]; then
        echo -e "\n  ${C_RED}✖ Invalid branch ID: $ACT_STATS${C_RESET}"
        echo -e "  ${C_DIM}Available IDs: 1-$TOTAL_VISIBLE${C_RESET}\n"
        exit 1
    fi
    
    echo -e "\n  ${C_BOLD}${ICON_STATS} BRANCH STATISTICS: ${C_CYAN}$branch${C_RESET}\n"
    
    IFS='|' read -r commits files additions deletions authors < <(get_branch_metrics "$branch")
    freq=$(calculate_commit_frequency "$branch" 30)
    
    echo -e "  ${C_HEADER}Commit Activity:${C_RESET}"
    printf "    %-20s %s\n" "Total Commits:" "$commits"
    printf "    %-20s %.2f per day\n" "Frequency:" "$freq"
    printf "    %-20s %s\n" "Contributors:" "$authors"
    echo
    
    echo -e "  ${C_HEADER}Code Changes:${C_RESET}"
    printf "    %-20s %s\n" "Files Modified:" "$files"
    printf "    %-20s ${C_GREEN}+%s${C_RESET}\n" "Lines Added:" "$additions"
    printf "    %-20s ${C_RED}-%s${C_RESET}\n" "Lines Deleted:" "$deletions"
    printf "    %-20s %s\n" "Net Change:" "$((additions - deletions))"
    echo
    
    echo -e "  ${C_HEADER}Recent Activity (Last 10 commits):${C_RESET}"
    git log --oneline -10 "$branch" 2>/dev/null | sed 's/^/    /' || echo "    ${C_DIM}No commits found${C_RESET}"
    echo
    exit 0
fi

if [ -n "$ACT_CONFLICTS" ]; then
    branch="${ROWS_BRANCH_TEXT[$ACT_CONFLICTS]}"
    
    if [ -z "$branch" ]; then
        echo -e "\n  ${C_RED}✖ Invalid branch ID: $ACT_CONFLICTS${C_RESET}"
        echo -e "  ${C_DIM}Available IDs: 1-$TOTAL_VISIBLE${C_RESET}\n"
        exit 1
    fi
    
    clean_branch="$branch"
    [[ "$branch" == origin/* ]] && clean_branch="${branch#origin/}"
    
    predict_merge_conflicts "$clean_branch"
    exit 0
fi

if [ -n "$ACT_CI" ]; then
    branch="${ROWS_BRANCH_TEXT[$ACT_CI]}"
    
    if [ -z "$branch" ]; then
        echo -e "\n  ${C_RED}✖ Invalid branch ID: $ACT_CI${C_RESET}"
        echo -e "  ${C_DIM}Available IDs: 1-$TOTAL_VISIBLE${C_RESET}\n"
        exit 1
    fi
    
    echo -e "\n  ${C_BOLD}${ICON_CI} CI/CD STATUS${C_RESET}"
    echo -e "  ${C_DIM}Branch: ${C_CYAN}$branch${C_RESET}\n"
    
    platform=$(detect_remote_platform)
    
    if [ -z "$platform" ]; then
        echo -e "  ${C_YELLOW}⚠ Remote platform not detected${C_RESET}"
        echo -e "  ${C_DIM}This feature requires a GitHub or GitLab repository${C_RESET}\n"
        echo -e "  ${C_HEADER}Your remote URL:${C_RESET}"
        git config --get remote.origin.url 2>/dev/null | sed 's/^/    /' || echo "    ${C_DIM}No remote configured${C_RESET}"
        echo
        exit 1
    fi
    
    if [ "$platform" == "github" ]; then
        token=$(get_github_token)
        if [ -z "$token" ]; then
            echo -e "  ${C_CYAN}${ICON_GITHUB} GitHub${C_RESET}\n"
            echo -e "  ${C_YELLOW}⚠ No GitHub API token configured${C_RESET}\n"
            echo -e "  ${C_HEADER}To enable CI/CD status:${C_RESET}"
            echo -e "  ${C_DIM}1. Create token: https://github.com/settings/tokens${C_RESET}"
            echo -e "  ${C_DIM}2. Set environment variable:${C_RESET}"
            echo -e "     ${C_CYAN}export GITHUB_TOKEN=\"ghp_your_token\"${C_RESET}"
            echo -e "  ${C_DIM}   OR set in git config:${C_RESET}"
            echo -e "     ${C_CYAN}git config --global github.token ghp_your_token${C_RESET}"
            echo
            exit 1
        fi
    elif [ "$platform" == "gitlab" ]; then
        token=$(get_gitlab_token)
        if [ -z "$token" ]; then
            echo -e "  ${C_CYAN}${ICON_GITLAB} GitLab${C_RESET}\n"
            echo -e "  ${C_YELLOW}⚠ No GitLab API token configured${C_RESET}\n"
            echo -e "  ${C_HEADER}To enable CI/CD status:${C_RESET}"
            echo -e "  ${C_DIM}1. Create token: https://gitlab.com/-/profile/personal_access_tokens${C_RESET}"
            echo -e "  ${C_DIM}2. Set environment variable:${C_RESET}"
            echo -e "     ${C_CYAN}export GITLAB_TOKEN=\"glpat_your_token\"${C_RESET}"
            echo -e "  ${C_DIM}   OR set in git config:${C_RESET}"
            echo -e "     ${C_CYAN}git config --global gitlab.token glpat_your_token${C_RESET}"
            echo
            exit 1
        fi
    fi
    
    clean_branch="$branch"
    [[ "$branch" == origin/* ]] && clean_branch="${branch#origin/}"
    
    if [ "$platform" == "github" ]; then
        echo -e "  ${C_CYAN}${ICON_GITHUB} GitHub${C_RESET}\n"
        repo=$(parse_github_repo)
        
        if [ -z "$repo" ]; then
            echo -e "  ${C_RED}✖ Could not parse repository from remote URL${C_RESET}\n"
            exit 1
        fi
        
        status=$(fetch_github_ci_status "$repo" "$clean_branch")
        
        if [ -n "$status" ] && command -v jq >/dev/null 2>&1; then
            state=$(echo "$status" | jq -r '.state' 2>/dev/null)
            total=$(echo "$status" | jq -r '.total_count' 2>/dev/null)
            
            case "$state" in
                success) echo -e "  ${C_GREEN}✓ Build Passing${C_RESET} ($total checks)" ;;
                pending) echo -e "  ${C_YELLOW}⏳ Build Pending${C_RESET} ($total checks)" ;;
                failure) echo -e "  ${C_RED}✗ Build Failed${C_RESET} ($total checks)" ;;
                *) 
                    echo -e "  ${C_YELLOW}⚠ No CI status available${C_RESET}"
                    echo -e "  ${C_DIM}Branch may not be pushed or has no CI workflow${C_RESET}"
                    ;;
            esac
            
            if [ "$state" != "null" ] && [ -n "$state" ]; then
                echo
                echo -e "  ${C_HEADER}Check Details:${C_RESET}"
                echo "$status" | jq -r '.statuses[] | "    \(.context): \(.state)"' 2>/dev/null | head -10
            fi
        else
            echo -e "  ${C_YELLOW}⚠ Could not fetch CI status${C_RESET}"
            echo -e "  ${C_DIM}Possible reasons:${C_RESET}"
            echo -e "  ${C_DIM}- Branch not pushed to remote${C_RESET}"
            echo -e "  ${C_DIM}- No GitHub Actions configured${C_RESET}"
            echo -e "  ${C_DIM}- API rate limit exceeded${C_RESET}"
            echo -e "  ${C_DIM}- jq not installed (required)${C_RESET}"
        fi
        
    elif [ "$platform" == "gitlab" ]; then
        echo -e "  ${C_CYAN}${ICON_GITLAB} GitLab${C_RESET}\n"
        repo=$(parse_gitlab_repo)
        
        if [ -z "$repo" ]; then
            echo -e "  ${C_RED}✖ Could not parse repository${C_RESET}\n"
            exit 1
        fi
        
        status=$(fetch_gitlab_ci_status "$repo" "$clean_branch")
        
        if [ -n "$status" ] && command -v jq >/dev/null 2>&1; then
            pipeline=$(echo "$status" | jq -r '.last_pipeline.status' 2>/dev/null)
            
            case "$pipeline" in
                success) echo -e "  ${C_GREEN}✓ Pipeline Passed${C_RESET}" ;;
                running) echo -e "  ${C_YELLOW}⏳ Pipeline Running${C_RESET}" ;;
                failed) echo -e "  ${C_RED}✗ Pipeline Failed${C_RESET}" ;;
                pending) echo -e "  ${C_YELLOW}⏳ Pipeline Pending${C_RESET}" ;;
                *)
                    echo -e "  ${C_YELLOW}⚠ No pipeline status${C_RESET}"
                    echo -e "  ${C_DIM}Branch may not be pushed or has no CI${C_RESET}"
                    ;;
            esac
        else
            echo -e "  ${C_YELLOW}⚠ Could not fetch pipeline status${C_RESET}"
            echo -e "  ${C_DIM}Possible reasons:${C_RESET}"
            echo -e "  ${C_DIM}- Branch not pushed${C_RESET}"
            echo -e "  ${C_DIM}- No GitLab CI configured${C_RESET}"
            echo -e "  ${C_DIM}- API rate limit${C_RESET}"
            echo -e "  ${C_DIM}- jq not installed${C_RESET}"
        fi
    fi
    
    echo
    exit 0
fi

# =========================================================
# OTHER ACTIONS
# =========================================================

if [ -n "$ACT_EXPORT" ]; then
    FORMAT="${ACT_EXPORT,,}"
    EXPORT_FILE="git-branches-$(date +%Y%m%d-%H%M%S).$FORMAT"
    
    case "$FORMAT" in
        csv)
            echo "ID,Branch,Commit,Date,Author" > "$EXPORT_FILE"
            for ((i=1; i<=TOTAL_VISIBLE; i++)); do
                echo "$i,\"${ROWS_BRANCH_TEXT[$i]}\",${ROWS_HASH[$i]},\"${ROWS_DATE[$i]}\",\"${ROWS_AUTHOR[$i]}\"" >> "$EXPORT_FILE"
            done
            print_succ "Exported to $EXPORT_FILE"
            ;;
        json)
            if command -v jq >/dev/null 2>&1; then
                echo "[" > "$EXPORT_FILE"
                for ((i=1; i<=TOTAL_VISIBLE; i++)); do
                    [ $i -gt 1 ] && echo "," >> "$EXPORT_FILE"
                    cat >> "$EXPORT_FILE" <<-EOF
  {
    "id": $i,
    "branch": "${ROWS_BRANCH_TEXT[$i]}",
    "commit": "${ROWS_HASH[$i]}",
    "date": "${ROWS_DATE[$i]}",
    "author": "${ROWS_AUTHOR[$i]}",
    "timestamp": ${ROWS_AGE_RAW[$i]}
  }
EOF
                done
                echo "]" >> "$EXPORT_FILE"
                print_succ "Exported to $EXPORT_FILE"
            else
                print_error "jq not installed"
            fi
            ;;
        md)
            echo "# Git Branches - $(date)" > "$EXPORT_FILE"
            echo "" >> "$EXPORT_FILE"
            echo "| ID | Branch | Commit | Date | Author |" >> "$EXPORT_FILE"
            echo "|---:|--------|--------|------|--------|" >> "$EXPORT_FILE"
            for ((i=1; i<=TOTAL_VISIBLE; i++)); do
                echo "| $i | ${ROWS_BRANCH_TEXT[$i]} | ${ROWS_HASH[$i]} | ${ROWS_DATE[$i]} | ${ROWS_AUTHOR[$i]} |" >> "$EXPORT_FILE"
            done
            print_succ "Exported to $EXPORT_FILE"
            ;;
        *)
            print_error "Unknown format. Use: csv, json, or md"
            ;;
    esac
    exit 0
fi

if [ -n "$ACT_COMPARE" ]; then
    IFS=':' read -r ID1 ID2 <<< "$ACT_COMPARE"
    B1="${ROWS_BRANCH_TEXT[$ID1]}"; B2="${ROWS_BRANCH_TEXT[$ID2]}"
    [ -z "$B1" ] || [ -z "$B2" ] && print_error "Invalid branch IDs"
    
    echo -e "\n  ${C_BOLD}${ICON_SEARCH} COMPARING BRANCHES${C_RESET}"
    echo -e "  ${C_CYAN}$B1${C_RESET} ${C_DIM}vs${C_RESET} ${C_CYAN}$B2${C_RESET}\n"
    
    echo -e "  ${C_HEADER}Commits in $B1 but not in $B2:${C_RESET}"
    git log --oneline "$B2..$B1" --no-merges | head -10 | sed 's/^/  /' || echo "  ${C_DIM}(none)${C_RESET}"
    
    echo -e "\n  ${C_HEADER}Commits in $B2 but not in $B1:${C_RESET}"
    git log --oneline "$B1..$B2" --no-merges | head -10 | sed 's/^/  /' || echo "  ${C_DIM}(none)${C_RESET}"
    
    echo -e "\n  ${C_HEADER}File changes:${C_RESET}"
    git diff --stat "$B1...$B2" | sed 's/^/  /'
    echo
    exit 0
fi

if [ -n "$ACT_STATUS" ]; then
    branch="${ROWS_BRANCH_TEXT[$ACT_STATUS]}"
    [ -z "$branch" ] && print_error "Invalid branch ID"
    
    echo -e "\n  ${C_BOLD}Branch Status: ${C_CYAN}$branch${C_RESET}\n"
    status=$(get_branch_status "$branch")
    echo -e "  Push/Pull Status: $status\n"
    
    upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    if [ -n "$upstream" ]; then
        echo -e "  ${C_HEADER}Upstream:${C_RESET} $upstream"
        echo -e "  ${C_HEADER}Last sync:${C_RESET} $(git show -s --format='%cr' "$upstream")\n"
    else
        echo -e "  ${C_DIM}No upstream tracking branch${C_RESET}\n"
    fi
    exit 0
fi

if [ -n "$ACT_BULK_DELETE" ]; then
    IFS=',' read -ra IDS <<< "$ACT_BULK_DELETE"
    echo -e "\n  ${C_YELLOW}Preparing to delete ${#IDS[@]} branches:${C_RESET}"
    
    for id in "${IDS[@]}"; do
        id=$(echo "$id" | xargs)
        branch="${ROWS_BRANCH_TEXT[$id]}"
        [ -n "$branch" ] && echo -e "    ${C_DIM}[$id]${C_RESET} $branch"
    done
    
    echo
    read -p "  Confirm deletion? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        deleted=0
        for id in "${IDS[@]}"; do
            id=$(echo "$id" | xargs)
            branch="${ROWS_BRANCH_TEXT[$id]}"
            if [ -n "$branch" ] && [[ "${ROWS_BRANCH_REF[$id]}" == refs/heads/* ]]; then
                if git branch -D "$branch" 2>/dev/null; then
                    echo -e "  ${C_GREEN}✔${C_RESET} Deleted: $branch"
                    ((deleted++))
                else
                    echo -e "  ${C_RED}✖${C_RESET} Failed: $branch"
                fi
            fi
        done
        echo -e "\n  ${C_GREEN}Deleted $deleted/${#IDS[@]} branches${C_RESET}\n"
    else
        echo -e "  ${C_DIM}Cancelled${C_RESET}\n"
    fi
    exit 0
fi

if [ -n "$ACT_TEAM" ]; then
    id=$ACT_TEAM; name="${ROWS_BRANCH_TEXT[$id]}"; ref="${ROWS_BRANCH_REF[$id]}"
    [ -z "$name" ] && print_error "Invalid branch ID"
    
    BASE=""; for b in master main staging develop; do 
        git show-ref --verify --quiet "refs/remotes/origin/$b" && BASE="origin/$b" && break
    done
    
    echo -e "\n  ${C_BOLD}${ICON_TEAM} CONTRIBUTORS: ${C_BLUE}${name}${C_RESET}\n"
    if [ -n "$BASE" ]; then 
        git shortlog -sn --no-merges "$BASE..$ref" 2>/dev/null | sed 's/^/   /'
    else 
        git shortlog -sn --no-merges -n 10 "$ref" 2>/dev/null | sed 's/^/   /'
    fi
    echo
    exit 0
fi

if [ "$ACT_INTERACTIVE" -eq 1 ]; then
    render_table
    echo
    echo -e "  ${C_BOLD}Interactive Mode${C_RESET}"
    echo -e "  ${C_HEADER}Basic Actions:${C_RESET}"
    echo -e "  ${C_CYAN}1)${C_RESET} Checkout  ${C_CYAN}2)${C_RESET} Show  ${C_CYAN}3)${C_RESET} Merge  ${C_CYAN}4)${C_RESET} Delete  ${C_CYAN}5)${C_RESET} Compare"
    echo -e "  ${C_HEADER}Advanced:${C_RESET}"
    echo -e "  ${C_CYAN}6)${C_RESET} Statistics  ${C_CYAN}7)${C_RESET} Velocity  ${C_CYAN}8)${C_RESET} Conflicts  ${C_CYAN}9)${C_RESET} CI Status  ${C_CYAN}0)${C_RESET} Exit"
    echo
    read -p "  Enter choice: " choice
    
    case $choice in
        1) read -p "  Branch ID to checkout: " ACT_CHECKOUT ;;
        2) read -p "  Branch ID to show: " ACT_SHOW ;;
        3) read -p "  Branch ID to merge: " ACT_MERGE ;;
        4) read -p "  Branch ID to delete: " ACT_DELETE ;;
        5) read -p "  Compare (ID1:ID2): " ACT_COMPARE ;;
        6) read -p "  Branch ID for statistics: " ACT_STATS ;;
        7) calculate_team_velocity; exit 0 ;;
        8) read -p "  Branch ID to check conflicts: " ACT_CONFLICTS ;;
        9) read -p "  Branch ID for CI status: " ACT_CI ;;
        0) exit 0 ;;
        *) print_error "Invalid choice" ;;
    esac
fi

# =========================================================
# DISPLAY TABLE IF NO ACTION
# =========================================================

if [ -z "$ACT_CHECKOUT" ] && [ -z "$ACT_MERGE" ] && [ -z "$ACT_DELETE" ] && [ -z "$ACT_RENAME" ] && [ -z "$ACT_SHOW" ] && [ -z "$ACT_COPY_HASH" ]; then
    render_table
    print_suggestions
    exit 0
fi

# =========================================================
# EXECUTE WORKFLOW ACTIONS
# =========================================================

if [ -n "$ACT_CHECKOUT" ]; then
    name="${ROWS_BRANCH_TEXT[$ACT_CHECKOUT]}"
    ref="${ROWS_BRANCH_REF[$ACT_CHECKOUT]}"
    [ -z "$name" ] && print_error "Invalid branch ID"
    
    if [[ "$ref" == refs/heads/* ]]; then
        git checkout "$name" && print_succ "Checked out: $name"
    else
        clean="${name#*/}"
        if git show-ref --verify --quiet "refs/heads/$clean"; then
            git checkout "$clean" && print_succ "Checked out existing: $clean"
        else
            git checkout -b "$clean" --track "$name" 2>/dev/null && print_succ "Created and checked out: $clean"
        fi
    fi
    
elif [ -n "$ACT_SHOW" ]; then
    hash="${ROWS_HASH[$ACT_SHOW]}"
    [ -z "$hash" ] && print_error "Invalid branch ID"
    git show --stat "$hash"
    
elif [ -n "$ACT_DELETE" ]; then
    name="${ROWS_BRANCH_TEXT[$ACT_DELETE]}"
    ref="${ROWS_BRANCH_REF[$ACT_DELETE]}"
    [ -z "$name" ] && print_error "Invalid branch ID"
    
    [[ "$ref" != refs/heads/* ]] && print_error "Can only delete local branches"
    [ "$name" == "$CUR_BRANCH" ] && print_error "Cannot delete current branch"
    
    if [[ "$name" =~ ^(master|main|develop|staging|production)$ ]]; then
        print_warn "This looks like a protected branch: $name"
        read -p "Are you sure? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && exit 0
    fi
    
    git branch -D "$name" 2>/dev/null && print_succ "Deleted: $name"
    
elif [ -n "$ACT_MERGE" ]; then
    name="${ROWS_BRANCH_TEXT[$ACT_MERGE]}"
    [ -z "$name" ] && print_error "Invalid branch ID"
    
    echo -e "${C_CYAN}Merging $name into $CUR_BRANCH...${C_RESET}"
    git merge "$name" && print_succ "Merge completed"
    
elif [ -n "$ACT_RENAME" ]; then
    old_name="${ROWS_BRANCH_TEXT[$ACT_RENAME]}"
    ref="${ROWS_BRANCH_REF[$ACT_RENAME]}"
    [ -z "$old_name" ] && print_error "Invalid branch ID"
    
    [[ "$ref" != refs/heads/* ]] && print_error "Can only rename local branches"
    
    echo -e "  Current name: ${C_CYAN}$old_name${C_RESET}"
    read -p "  New name: " new_name
    
    [ -z "$new_name" ] && print_error "Name cannot be empty"
    
    git branch -m "$old_name" "$new_name" 2>/dev/null && print_succ "Renamed: $old_name → $new_name"
    
elif [ -n "$ACT_COPY_HASH" ]; then
    hash="${ROWS_HASH[$ACT_COPY_HASH]}"
    [ -z "$hash" ] && print_error "Invalid branch ID"
    
    if copy_to_clipboard "$hash"; then
        echo -e "${C_DIM}Hash: ${C_BOLD}$hash${C_RESET}"
        print_succ "Commit hash copied to clipboard"
    fi
fi
