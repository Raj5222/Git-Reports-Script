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
    
    # Check for GitHub (github.com or self-hosted with 'github' in domain)
    if [[ "$remote_url" =~ github\.com ]] || [[ "$remote_url" =~ github ]]; then
        echo "github"
    # Check for GitLab (gitlab.com or self-hosted with 'gitlab' in domain)
    elif [[ "$remote_url" =~ gitlab ]]; then
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
    # Match: gitlab.com or gitlab.anything.com or anything.gitlab.com
    if [[ "$url" =~ gitlab.*[:/]([^/]+)/([^/.]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    elif [[ "$url" =~ [:/]([^/]+)/([^/.]+)\.git ]]; then
        # Fallback: extract owner/repo from any gitlab URL
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
}

get_gitlab_domain() {
    local url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" =~ ^https?://([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$url" =~ @([^:]+): ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "gitlab.com"  # fallback
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

fetch_github_workflows() {
    local repo=$1
    local branch=$2
    local token=$(get_github_token)
    [ -z "$token" ] && return 1
    
    # Get workflow runs for this branch
    curl -s -H "Authorization: token $token" \
         -H "Accept: application/vnd.github.v3+json" \
         "https://api.github.com/repos/$repo/actions/runs?branch=$branch&per_page=1" 2>/dev/null
}

fetch_github_workflow_jobs() {
    local repo=$1
    local run_id=$2
    local token=$(get_github_token)
    [ -z "$token" ] && return 1
    
    curl -s -H "Authorization: token $token" \
         -H "Accept: application/vnd.github.v3+json" \
         "https://api.github.com/repos/$repo/actions/runs/$run_id/jobs" 2>/dev/null
}

fetch_github_commit() {
    local repo=$1
    local branch=$2
    local token=$(get_github_token)
    [ -z "$token" ] && return 1
    
    curl -s -H "Authorization: token $token" \
         -H "Accept: application/vnd.github.v3+json" \
         "https://api.github.com/repos/$repo/commits/$branch" 2>/dev/null
}

fetch_github_pulls() {
    local repo=$1
    local branch=$2
    local token=$(get_github_token)
    [ -z "$token" ] && return 1
    
    # URL encode the branch name
    local encoded_branch=$(echo "$branch" | sed 's/\//%2F/g')
    
    curl -s -H "Authorization: token $token" \
         -H "Accept: application/vnd.github.v3+json" \
         "https://api.github.com/repos/$repo/pulls?head=$branch&state=open" 2>/dev/null
}

fetch_gitlab_ci_status() {
    local repo=$1
    local branch=$2
    local token=$(get_gitlab_token)
    [ -z "$token" ] && return 1
    
    local gitlab_domain=$(get_gitlab_domain)
    local project_path=$(echo "$repo" | sed 's/\//%2F/g')
    
    # URL encode the branch name (handle slashes and special chars)
    local encoded_branch=$(echo "$branch" | sed 's/\//%2F/g' | sed 's/ /%20/g')
    
    # First, try to get the numeric project ID
    local project_data=$(curl -s -H "PRIVATE-TOKEN: $token" \
         "https://${gitlab_domain}/api/v4/projects/$project_path" 2>/dev/null)
    
    local project_id=$(echo "$project_data" | jq -r '.id' 2>/dev/null)
    
    # If we got a numeric ID, use that (more reliable)
    if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
        curl -s -H "PRIVATE-TOKEN: $token" \
             "https://${gitlab_domain}/api/v4/projects/$project_id/repository/commits/$encoded_branch" 2>/dev/null
    else
        # Fallback to project path
        curl -s -H "PRIVATE-TOKEN: $token" \
             "https://${gitlab_domain}/api/v4/projects/$project_path/repository/commits/$encoded_branch" 2>/dev/null
    fi
}

fetch_gitlab_merge_requests() {
    local repo=$1
    local branch=$2
    local token=$(get_gitlab_token)
    [ -z "$token" ] && return 1
    
    local gitlab_domain=$(get_gitlab_domain)
    local project_path=$(echo "$repo" | sed 's/\//%2F/g')
    
    # Get project ID
    local project_data=$(curl -s -H "PRIVATE-TOKEN: $token" \
         "https://${gitlab_domain}/api/v4/projects/$project_path" 2>/dev/null)
    local project_id=$(echo "$project_data" | jq -r '.id' 2>/dev/null)
    
    if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
        # Get MRs for this branch (source_branch)
        curl -s -H "PRIVATE-TOKEN: $token" \
             "https://${gitlab_domain}/api/v4/projects/$project_id/merge_requests?source_branch=$branch&state=opened" 2>/dev/null
    fi
}

fetch_gitlab_pipeline_details() {
    local repo=$1
    local pipeline_id=$2
    local token=$(get_gitlab_token)
    [ -z "$token" ] && return 1
    
    local gitlab_domain=$(get_gitlab_domain)
    local project_path=$(echo "$repo" | sed 's/\//%2F/g')
    
    # Get project ID
    local project_data=$(curl -s -H "PRIVATE-TOKEN: $token" \
         "https://${gitlab_domain}/api/v4/projects/$project_path" 2>/dev/null)
    local project_id=$(echo "$project_data" | jq -r '.id' 2>/dev/null)
    
    if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
        # Get pipeline jobs
        curl -s -H "PRIVATE-TOKEN: $token" \
             "https://${gitlab_domain}/api/v4/projects/$project_id/pipelines/$pipeline_id/jobs" 2>/dev/null
    fi
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
ACT_INTERACTIVE=0
ACT_STATUS=""
ACT_BULK_DELETE=""
ACT_STATS=""
ACT_VELOCITY=""
ACT_CLEANUP=""
ACT_GRAPH=""
ACT_CONFLICTS=""
ACT_CI=""
ACT_DIFF=""
ACT_REALTIME_CI=""

if [[ "$1" =~ ^[0-9]+$ ]]; then LIMIT="$1"; shift; fi

while getopts ":f:S:Huc:m:d:r:s:k:t:C:D:TLiP:b:VGAX:M:N:R:h" opt; do
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
    D) ACT_DIFF="$OPTARG" ;;
    T) ACT_TAGS=1 ;;
    L) ACT_STASH=1 ;;
    i) ACT_INTERACTIVE=1 ;;
    P) ACT_STATUS="$OPTARG" ;;
    b) ACT_BULK_DELETE="$OPTARG" ;;
    V) ACT_VELOCITY=1 ;;
    G) ACT_GRAPH=1 ;;
    A) ACT_CLEANUP=1 ;;
    X) ACT_STATS="$OPTARG" ;;
    M) ACT_CONFLICTS="$OPTARG" ;;
    N) ACT_CI="$OPTARG" ;;
    R) ACT_REALTIME_CI="$OPTARG" ;;
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
  -D <ID1:ID2> Compare commits (detailed diff)
  -P <ID>     Show push/pull status (ahead/behind)

BASIC FEATURES:
  -T          Show repository tags
  -L          Show stash list
  -i          Interactive mode

🚀 ADVANCED FEATURES (NEW):
  -V          Team velocity dashboard
  -G          Branch dependency graph
  -A          Smart cleanup suggestions
  -X <ID>     Detailed branch statistics
  -M <ID>     Predict merge conflicts
  -N <ID>     CI/CD status (GitHub/GitLab)
  -R <ID> [interval]  Real-time CI/CD monitoring (default: 5s)

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
  git-record -N 3                 # Check CI/CD status (snapshot)
  git-record -R 3                 # Monitor CI/CD (5s refresh)
  git-record -R 3 2               # Monitor CI/CD (2s refresh)
  git-record -C 1:5               # Compare branches 1 and 5
  git-record -D 1:3               # Compare commits 1 and 3

EOF
      exit 0 
      ;;
    \?) print_error "Invalid option: -$OPTARG. Use -h for help." ;;
  esac
done

# Shift to remove processed options
shift $((OPTIND - 1))

# Capture any remaining arguments (for refresh interval in -R)
EXTRA_ARGS=("$@")

# Dynamic Limit Expansion
for req_id in "$ACT_CHECKOUT" "$ACT_TEAM" "$ACT_MERGE" "$ACT_DELETE" "$ACT_RENAME" "$ACT_SHOW" "$ACT_COPY_HASH" "$ACT_STATUS" "$ACT_STATS" "$ACT_CONFLICTS" "$ACT_CI" "$ACT_REALTIME_CI"; do
    # Only process if it's a valid number
    if [[ "$req_id" =~ ^[0-9]+$ ]]; then
        if [ "$req_id" -gt "$LIMIT" ]; then 
            LIMIT=$req_id
        fi
    fi
done

if [ -n "$ACT_COMPARE" ]; then
    IFS=':' read -r ID1 ID2 <<< "$ACT_COMPARE"
    for id in "$ID1" "$ID2"; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            if [ "$id" -gt "$LIMIT" ]; then 
                LIMIT=$id
            fi
        fi
    done
fi

# =========================================================
# INPUT VALIDATION - Validate all flags BEFORE loading data
# =========================================================

validate_branch_id() {
    local value=$1
    local flag=$2
    local flag_name=$3
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo -e "\n${C_RED}✖ Invalid branch ID: ${C_BOLD}$value${C_RESET}"
        echo -e "${C_DIM}Branch ID must be a positive number${C_RESET}"
        echo -e "${C_DIM}Usage: git-record $flag <ID>${C_RESET}"
        echo -e "${C_DIM}Example: git-record $flag 3${C_RESET}\n"
        exit 1
    fi
}

validate_comparison() {
    local value=$1
    local flag=$2
    
    if ! [[ "$value" =~ ^[0-9]+:[0-9]+$ ]]; then
        echo -e "\n${C_RED}✖ Invalid comparison format: ${C_BOLD}$value${C_RESET}"
        echo -e "${C_DIM}Format must be: <ID1>:<ID2>${C_RESET}"
        echo -e "${C_DIM}Usage: git-record $flag <ID1:ID2>${C_RESET}"
        echo -e "${C_DIM}Example: git-record $flag 1:5${C_RESET}\n"
        exit 1
    fi
}

# Validate all single-ID flags
[ -n "$ACT_CHECKOUT" ] && validate_branch_id "$ACT_CHECKOUT" "-c" "Checkout"
[ -n "$ACT_MERGE" ] && validate_branch_id "$ACT_MERGE" "-m" "Merge"
[ -n "$ACT_DELETE" ] && validate_branch_id "$ACT_DELETE" "-d" "Delete"
[ -n "$ACT_RENAME" ] && validate_branch_id "$ACT_RENAME" "-r" "Rename"
[ -n "$ACT_SHOW" ] && validate_branch_id "$ACT_SHOW" "-s" "Show"
[ -n "$ACT_COPY_HASH" ] && validate_branch_id "$ACT_COPY_HASH" "-k" "Copy hash"
[ -n "$ACT_TEAM" ] && validate_branch_id "$ACT_TEAM" "-t" "Team contributors"
[ -n "$ACT_STATUS" ] && validate_branch_id "$ACT_STATUS" "-P" "Push/pull status"
[ -n "$ACT_STATS" ] && validate_branch_id "$ACT_STATS" "-X" "Statistics"
[ -n "$ACT_CONFLICTS" ] && validate_branch_id "$ACT_CONFLICTS" "-M" "Merge conflicts"
[ -n "$ACT_CI" ] && validate_branch_id "$ACT_CI" "-N" "CI/CD status"
[ -n "$ACT_REALTIME_CI" ] && validate_branch_id "$ACT_REALTIME_CI" "-R" "Real-time CI/CD"

# Validate comparison format
[ -n "$ACT_COMPARE" ] && validate_comparison "$ACT_COMPARE" "-C"
[ -n "$ACT_DIFF" ] && validate_comparison "$ACT_DIFF" "-D"

# Validate bulk delete (comma-separated IDs)
if [ -n "$ACT_BULK_DELETE" ]; then
    IFS=',' read -ra IDS <<< "$ACT_BULK_DELETE"
    for id in "${IDS[@]}"; do
        id=$(echo "$id" | xargs)  # Trim whitespace
        if ! [[ "$id" =~ ^[0-9]+$ ]]; then
            echo -e "\n${C_RED}✖ Invalid branch ID in bulk delete: ${C_BOLD}$id${C_RESET}"
            echo -e "${C_DIM}All IDs must be numbers${C_RESET}"
            echo -e "${C_DIM}Usage: git-record -b <ID1,ID2,ID3>${C_RESET}"
            echo -e "${C_DIM}Example: git-record -b 2,5,7${C_RESET}\n"
            exit 1
        fi
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
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -b <IDs>" "git-record -D <ID:ID>" "git-record -A"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Bulk Delete)" "(Commit Diff)" "(Cleanup)"
  echo
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "git-record -R <ID>" "git-record -X <ID>" "git-record -N <ID>"
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "(Real-time CI)" "(Statistics)" "(CI Status)"
  echo
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "" "git-record -M <ID>" ""
  printf "  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}  ${C_DIM}%-30s${C_RESET}\n" "" "(Conflicts)" ""
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
        echo -e "  ${C_YELLOW}⚠ Could not detect Git platform${C_RESET}"
        echo -e "  ${C_DIM}Supported platforms:${C_RESET}"
        echo -e "  ${C_DIM}- GitHub (github.com or self-hosted)${C_RESET}"
        echo -e "  ${C_DIM}- GitLab (gitlab.com or self-hosted)${C_RESET}\n"
        echo -e "  ${C_HEADER}Your remote URL:${C_RESET}"
        remote_url=$(git config --get remote.origin.url 2>/dev/null)
        echo -e "    ${C_CYAN}$remote_url${C_RESET}\n"
        echo -e "  ${C_DIM}Tip: URL must contain 'github' or 'gitlab'${C_RESET}"
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
            gitlab_domain=$(get_gitlab_domain)
            echo -e "  ${C_CYAN}${ICON_GITLAB} GitLab${C_RESET}\n"
            echo -e "  ${C_DIM}Server: $gitlab_domain${C_RESET}\n"
            echo -e "  ${C_YELLOW}⚠ No GitLab API token configured${C_RESET}\n"
            echo -e "  ${C_HEADER}To enable CI/CD status:${C_RESET}"
            if [ "$gitlab_domain" == "gitlab.com" ]; then
                echo -e "  ${C_DIM}1. Create token: https://gitlab.com/-/profile/personal_access_tokens${C_RESET}"
            else
                echo -e "  ${C_DIM}1. Create token: https://$gitlab_domain/-/profile/personal_access_tokens${C_RESET}"
            fi
            echo -e "  ${C_DIM}2. Set environment variable:${C_RESET}"
            echo -e "     ${C_CYAN}export GITLAB_TOKEN=\"glpat_your_token\"${C_RESET}"
            echo -e "  ${C_DIM}   OR set in git config:${C_RESET}"
            echo -e "     ${C_CYAN}git config --global gitlab.token glpat_your_token${C_RESET}"
            echo -e "\n  ${C_DIM}Required scopes: api, read_api, read_repository${C_RESET}"
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
        
        echo -e "  ${C_DIM}Repository: $repo${C_RESET}"
        echo -e "  ${C_DIM}Branch: $clean_branch${C_RESET}\n"
        
        # Try to get workflows first (GitHub Actions)
        workflows=$(fetch_github_workflows "$repo" "$clean_branch")
        
        if [ -n "$workflows" ] && [ "$workflows" != "null" ]; then
            run_count=$(echo "$workflows" | jq '.total_count' 2>/dev/null)
            
            if [ "$run_count" -gt 0 ]; then
                # Workflow exists - show full details
                # (Keep existing detailed workflow display code here)
                run_id=$(echo "$workflows" | jq -r '.workflow_runs[0].id' 2>/dev/null)
                run_name=$(echo "$workflows" | jq -r '.workflow_runs[0].name' 2>/dev/null)
                run_status=$(echo "$workflows" | jq -r '.workflow_runs[0].status' 2>/dev/null)
                run_conclusion=$(echo "$workflows" | jq -r '.workflow_runs[0].conclusion' 2>/dev/null)
                
                # Display status based on workflow state
                if [ "$run_status" == "completed" ]; then
                    case "$run_conclusion" in
                        success) echo -e "  ${C_GREEN}✓ Workflow Passed${C_RESET}" ;;
                        failure) echo -e "  ${C_RED}✗ Workflow Failed${C_RESET}" ;;
                        cancelled) echo -e "  ${C_YELLOW}⊗ Workflow Cancelled${C_RESET}" ;;
                        skipped) echo -e "  ${C_DIM}⊘ Workflow Skipped${C_RESET}" ;;
                        *) echo -e "  ${C_YELLOW}? Unknown: $run_conclusion${C_RESET}" ;;
                    esac
                elif [ "$run_status" == "in_progress" ]; then
                    echo -e "  ${C_YELLOW}⏳ Workflow Running${C_RESET}"
                elif [ "$run_status" == "queued" ]; then
                    echo -e "  ${C_CYAN}○ Workflow Queued${C_RESET}"
                else
                    echo -e "  ${C_YELLOW}? Status: $run_status${C_RESET}"
                fi
                
                echo
                echo -e "  ${C_HEADER}Workflow:${C_RESET} $run_name"
                echo -e "  ${C_HEADER}Run ID:${C_RESET} $run_id"
            else
                # No workflow runs found
                echo -e "  ${C_YELLOW}⚠ No CI/CD Configured${C_RESET}\n"
                echo -e "  ${C_HEADER}Reason:${C_RESET}"
                echo -e "    This repository has no GitHub Actions workflows\n"
                echo -e "  ${C_HEADER}To enable CI/CD:${C_RESET}"
                echo -e "    1. Create ${C_CYAN}.github/workflows/ci.yml${C_RESET}"
                echo -e "    2. Add workflow configuration"
                echo -e "    3. Push to GitHub\n"
                echo -e "  ${C_DIM}Example workflow:${C_RESET}"
                echo -e "    ${C_CYAN}https://docs.github.com/en/actions/quickstart${C_RESET}"
            fi
        else
            # Fallback to old status API
            status=$(fetch_github_ci_status "$repo" "$clean_branch")
            
            if [ -n "$status" ] && command -v jq >/dev/null 2>&1; then
                state=$(echo "$status" | jq -r '.state' 2>/dev/null)
                total=$(echo "$status" | jq -r '.total_count' 2>/dev/null)
                
                if [ "$total" == "0" ] || [ "$total" == "null" ]; then
                    # No checks configured
                    echo -e "  ${C_YELLOW}⚠ No CI/CD Configured${C_RESET}\n"
                    echo -e "  ${C_HEADER}Reason:${C_RESET}"
                    echo -e "    No GitHub Actions or status checks found\n"
                    echo -e "  ${C_HEADER}This repository doesn't have:${C_RESET}"
                    echo -e "    • GitHub Actions workflows (${C_CYAN}.github/workflows/${C_RESET})"
                    echo -e "    • External CI services (Travis, CircleCI, etc.)\n"
                    echo -e "  ${C_HEADER}To add CI/CD:${C_RESET}"
                    echo -e "    Create ${C_CYAN}.github/workflows/ci.yml${C_RESET} with:"
                    echo -e "    ${C_DIM}───────────────────────────────${C_RESET}"
                    echo -e "    ${C_DIM}name: CI${C_RESET}"
                    echo -e "    ${C_DIM}on: [push]${C_RESET}"
                    echo -e "    ${C_DIM}jobs:${C_RESET}"
                    echo -e "    ${C_DIM}  build:${C_RESET}"
                    echo -e "    ${C_DIM}    runs-on: ubuntu-latest${C_RESET}"
                    echo -e "    ${C_DIM}    steps:${C_RESET}"
                    echo -e "    ${C_DIM}      - uses: actions/checkout@v2${C_RESET}"
                    echo -e "    ${C_DIM}      - run: npm install${C_RESET}"
                    echo -e "    ${C_DIM}───────────────────────────────${C_RESET}"
                else
                    # Has status checks
                    case "$state" in
                        success) echo -e "  ${C_GREEN}✓ Build Passing${C_RESET} ($total checks)" ;;
                        pending) echo -e "  ${C_YELLOW}⏳ Build Pending${C_RESET} ($total checks)" ;;
                        failure) echo -e "  ${C_RED}✗ Build Failed${C_RESET} ($total checks)" ;;
                        *) echo -e "  ${C_YELLOW}? Unknown state: $state${C_RESET}" ;;
                    esac
                    
                    echo
                    echo -e "  ${C_HEADER}Check Details:${C_RESET}"
                    echo "$status" | jq -r '.statuses[] | "    \(.context): \(.state)"' 2>/dev/null
                fi
            else
                # API call failed
                echo -e "  ${C_RED}✖ Could not fetch CI status${C_RESET}\n"
                echo -e "  ${C_HEADER}Possible reasons:${C_RESET}"
                echo -e "    • API token not configured"
                echo -e "    • Network error"
                echo -e "    • API rate limit exceeded"
                echo -e "    • Repository not accessible\n"
                echo -e "  ${C_HEADER}Check:${C_RESET}"
                echo -e "    ${C_CYAN}echo \$GITHUB_TOKEN${C_RESET}"
            fi
        fi
        
    elif [ "$platform" == "gitlab" ]; then
        echo -e "  ${C_CYAN}${ICON_GITLAB} GitLab${C_RESET}\n"
        repo=$(parse_gitlab_repo)
        gitlab_domain=$(get_gitlab_domain)
        
        if [ -z "$repo" ]; then
            echo -e "  ${C_RED}✖ Could not parse repository${C_RESET}\n"
            exit 1
        fi
        
        echo -e "  ${C_DIM}Server: $gitlab_domain${C_RESET}"
        echo -e "  ${C_DIM}Repository: $repo${C_RESET}"
        echo -e "  ${C_DIM}Branch: $clean_branch${C_RESET}\n"
        
        status=$(fetch_gitlab_ci_status "$repo" "$clean_branch")
        
        if [ -n "$status" ] && command -v jq >/dev/null 2>&1; then
            # Check for error first
            error=$(echo "$status" | jq -r '.error' 2>/dev/null)
            if [ -n "$error" ] && [ "$error" != "null" ]; then
                echo -e "  ${C_RED}✖ API Error: $error${C_RESET}\n"
                exit 1
            fi
            
            pipeline=$(echo "$status" | jq -r '.last_pipeline.status' 2>/dev/null)
            
            case "$pipeline" in
                success) echo -e "  ${C_GREEN}✓ Pipeline Passed${C_RESET}" ;;
                running) echo -e "  ${C_YELLOW}⏳ Pipeline Running${C_RESET}" ;;
                failed) echo -e "  ${C_RED}✗ Pipeline Failed${C_RESET}" ;;
                pending) echo -e "  ${C_YELLOW}⏳ Pipeline Pending${C_RESET}" ;;
                manual) echo -e "  ${C_BLUE}⚙️  Pipeline Manual${C_RESET} ${C_DIM}(requires manual trigger)${C_RESET}" ;;
                skipped) echo -e "  ${C_DIM}⊘ Pipeline Skipped${C_RESET}" ;;
                canceled) echo -e "  ${C_YELLOW}⊗ Pipeline Canceled${C_RESET}" ;;
                created) echo -e "  ${C_CYAN}○ Pipeline Created${C_RESET}" ;;
                *)
                    if [ "$pipeline" == "null" ] || [ -z "$pipeline" ]; then
                        echo -e "  ${C_YELLOW}⚠ No pipeline status${C_RESET}"
                        echo -e "  ${C_DIM}Branch may not be pushed or has no CI${C_RESET}"
                    else
                        echo -e "  ${C_YELLOW}? Unknown status: $pipeline${C_RESET}"
                    fi
                    ;;
            esac
            
            # Show pipeline details if available
            if [ "$pipeline" != "null" ] && [ -n "$pipeline" ]; then
                echo
                echo -e "  ${C_HEADER}Pipeline Details:${C_RESET}"
                
                # Pipeline info
                pipeline_id=$(echo "$status" | jq -r '.last_pipeline.id' 2>/dev/null)
                pipeline_iid=$(echo "$status" | jq -r '.last_pipeline.iid' 2>/dev/null)
                pipeline_source=$(echo "$status" | jq -r '.last_pipeline.source' 2>/dev/null)
                pipeline_ref=$(echo "$status" | jq -r '.last_pipeline.ref' 2>/dev/null)
                pipeline_created=$(echo "$status" | jq -r '.last_pipeline.created_at' 2>/dev/null)
                pipeline_updated=$(echo "$status" | jq -r '.last_pipeline.updated_at' 2>/dev/null)
                pipeline_url=$(echo "$status" | jq -r '.last_pipeline.web_url' 2>/dev/null)
                
                # Commit info
                commit_author=$(echo "$status" | jq -r '.author_name' 2>/dev/null)
                commit_email=$(echo "$status" | jq -r '.author_email' 2>/dev/null)
                commit_date=$(echo "$status" | jq -r '.committed_date' 2>/dev/null)
                commit_title=$(echo "$status" | jq -r '.title' 2>/dev/null)
                commit_id=$(echo "$status" | jq -r '.short_id' 2>/dev/null)
                
                # Display pipeline info
                if [ "$pipeline_id" != "null" ] && [ -n "$pipeline_id" ]; then
                    echo -e "    ${C_CYAN}Pipeline:${C_RESET} #$pipeline_iid (ID: $pipeline_id)"
                fi
                
                if [ "$pipeline_ref" != "null" ] && [ -n "$pipeline_ref" ]; then
                    echo -e "    ${C_CYAN}Branch:${C_RESET} $pipeline_ref"
                fi
                
                if [ "$pipeline_source" != "null" ] && [ -n "$pipeline_source" ]; then
                    echo -e "    ${C_CYAN}Triggered by:${C_RESET} $pipeline_source"
                fi
                
                echo
                echo -e "  ${C_HEADER}Last Commit:${C_RESET}"
                
                if [ "$commit_id" != "null" ] && [ -n "$commit_id" ]; then
                    echo -e "    ${C_CYAN}SHA:${C_RESET} $commit_id"
                fi
                
                if [ "$commit_author" != "null" ] && [ -n "$commit_author" ]; then
                    if [ "$commit_email" != "null" ] && [ -n "$commit_email" ]; then
                        echo -e "    ${C_CYAN}Author:${C_RESET} $commit_author <$commit_email>"
                    else
                        echo -e "    ${C_CYAN}Author:${C_RESET} $commit_author"
                    fi
                fi
                
                if [ "$commit_date" != "null" ] && [ -n "$commit_date" ]; then
                    # Convert to relative time
                    commit_ts=$(date -d "$commit_date" +%s 2>/dev/null || echo "")
                    if [ -n "$commit_ts" ]; then
                        now_ts=$(date +%s)
                        diff_sec=$((now_ts - commit_ts))
                        
                        if [ $diff_sec -lt 60 ]; then
                            rel_time="$diff_sec seconds ago"
                        elif [ $diff_sec -lt 3600 ]; then
                            rel_time="$((diff_sec / 60)) minutes ago"
                        elif [ $diff_sec -lt 86400 ]; then
                            rel_time="$((diff_sec / 3600)) hours ago"
                        else
                            rel_time="$((diff_sec / 86400)) days ago"
                        fi
                        
                        echo -e "    ${C_CYAN}Committed:${C_RESET} $rel_time"
                    else
                        echo -e "    ${C_CYAN}Committed:${C_RESET} $commit_date"
                    fi
                fi
                
                if [ "$commit_title" != "null" ] && [ -n "$commit_title" ]; then
                    # Truncate if too long
                    if [ ${#commit_title} -gt 70 ]; then
                        commit_title="${commit_title:0:70}..."
                    fi
                    echo -e "    ${C_CYAN}Message:${C_RESET} ${C_DIM}\"$commit_title\"${C_RESET}"
                fi
                
                echo
                echo -e "  ${C_HEADER}Pipeline Timeline:${C_RESET}"
                
                if [ "$pipeline_created" != "null" ] && [ -n "$pipeline_created" ]; then
                    created_ts=$(date -d "$pipeline_created" +%s 2>/dev/null || echo "")
                    if [ -n "$created_ts" ]; then
                        now_ts=$(date +%s)
                        diff_sec=$((now_ts - created_ts))
                        
                        if [ $diff_sec -lt 60 ]; then
                            rel_time="$diff_sec seconds ago"
                        elif [ $diff_sec -lt 3600 ]; then
                            rel_time="$((diff_sec / 60)) minutes ago"
                        elif [ $diff_sec -lt 86400 ]; then
                            rel_time="$((diff_sec / 3600)) hours ago"
                        else
                            rel_time="$((diff_sec / 86400)) days ago"
                        fi
                        
                        echo -e "    ${C_CYAN}Created:${C_RESET} $rel_time"
                        
                        # Calculate duration if pipeline has been updated
                        if [ "$pipeline_updated" != "null" ] && [ -n "$pipeline_updated" ]; then
                            updated_ts=$(date -d "$pipeline_updated" +%s 2>/dev/null || echo "")
                            if [ -n "$updated_ts" ]; then
                                duration=$((updated_ts - created_ts))
                                
                                if [ $duration -lt 60 ]; then
                                    duration_str="${duration}s"
                                elif [ $duration -lt 3600 ]; then
                                    min=$((duration / 60))
                                    sec=$((duration % 60))
                                    duration_str="${min}m ${sec}s"
                                else
                                    hour=$((duration / 3600))
                                    min=$(((duration % 3600) / 60))
                                    duration_str="${hour}h ${min}m"
                                fi
                                
                                # Show last action time
                                diff_sec=$((now_ts - updated_ts))
                                if [ $diff_sec -lt 60 ]; then
                                    last_action="$diff_sec seconds ago"
                                elif [ $diff_sec -lt 3600 ]; then
                                    last_action="$((diff_sec / 60)) minutes ago"
                                elif [ $diff_sec -lt 86400 ]; then
                                    last_action="$((diff_sec / 3600)) hours ago"
                                else
                                    last_action="$((diff_sec / 86400)) days ago"
                                fi
                                
                                echo -e "    ${C_CYAN}Last action:${C_RESET} $last_action"
                                
                                # Show duration based on status
                                if [[ "$pipeline" == "running" ]]; then
                                    echo -e "    ${C_CYAN}Running for:${C_RESET} $duration_str"
                                else
                                    echo -e "    ${C_CYAN}Duration:${C_RESET} $duration_str"
                                fi
                            fi
                        fi
                    else
                        echo -e "    ${C_CYAN}Created:${C_RESET} $pipeline_created"
                    fi
                fi
                
                # Fetch and display job details
                if [ "$pipeline_id" != "null" ] && [ -n "$pipeline_id" ]; then
                    jobs=$(fetch_gitlab_pipeline_details "$repo" "$pipeline_id")
                    
                    if [ -n "$jobs" ] && [ "$jobs" != "[]" ]; then
                        job_count=$(echo "$jobs" | jq 'length' 2>/dev/null)
                        
                        if [ "$job_count" -gt 0 ]; then
                            echo
                            echo -e "  ${C_HEADER}Pipeline Jobs ($job_count total):${C_RESET}"
                            
                            # Count jobs by status
                            success_count=$(echo "$jobs" | jq '[.[] | select(.status=="success")] | length' 2>/dev/null)
                            failed_count=$(echo "$jobs" | jq '[.[] | select(.status=="failed")] | length' 2>/dev/null)
                            running_count=$(echo "$jobs" | jq '[.[] | select(.status=="running")] | length' 2>/dev/null)
                            pending_count=$(echo "$jobs" | jq '[.[] | select(.status=="pending")] | length' 2>/dev/null)
                            created_count=$(echo "$jobs" | jq '[.[] | select(.status=="created")] | length' 2>/dev/null)
                            manual_count=$(echo "$jobs" | jq '[.[] | select(.status=="manual")] | length' 2>/dev/null)
                            skipped_count=$(echo "$jobs" | jq '[.[] | select(.status=="skipped")] | length' 2>/dev/null)
                            canceled_count=$(echo "$jobs" | jq '[.[] | select(.status=="canceled")] | length' 2>/dev/null)
                            
                            # Show summary
                            summary=""
                            [ "$success_count" -gt 0 ] && summary="$summary ${C_GREEN}✓ $success_count passed${C_RESET}"
                            [ "$failed_count" -gt 0 ] && summary="$summary ${C_RED}✗ $failed_count failed${C_RESET}"
                            [ "$running_count" -gt 0 ] && summary="$summary ${C_YELLOW}⏳ $running_count running${C_RESET}"
                            [ "$pending_count" -gt 0 ] && summary="$summary ${C_CYAN}⊙ $pending_count pending${C_RESET}"
                            [ "$created_count" -gt 0 ] && summary="$summary ${C_CYAN}○ $created_count waiting${C_RESET}"
                            [ "$manual_count" -gt 0 ] && summary="$summary ${C_BLUE}⚙ $manual_count manual${C_RESET}"
                            [ "$canceled_count" -gt 0 ] && summary="$summary ${C_YELLOW}⊗ $canceled_count canceled${C_RESET}"
                            [ "$skipped_count" -gt 0 ] && summary="$summary ${C_DIM}⊘ $skipped_count skipped${C_RESET}"
                            
                            if [ -n "$summary" ]; then
                                echo -e "   $summary"
                                echo
                            fi
                            
                            # Show individual jobs (limit to 10)
                            echo "$jobs" | jq -r '.[] | "\(.stage)|\(.name)|\(.status)|\(.duration)"' 2>/dev/null | head -10 | while IFS='|' read -r stage name status duration; do
                                # Format status with icon and color
                                case "$status" in
                                    success) status_icon="${C_GREEN}✓${C_RESET}" ;;
                                    failed) status_icon="${C_RED}✗${C_RESET}" ;;
                                    running) status_icon="${C_YELLOW}⏳${C_RESET}" ;;
                                    pending) status_icon="${C_CYAN}○${C_RESET}" ;;
                                    manual) status_icon="${C_BLUE}⚙${C_RESET}" ;;
                                    skipped) status_icon="${C_DIM}⊘${C_RESET}" ;;
                                    canceled) status_icon="${C_YELLOW}⊗${C_RESET}" ;;
                                    created) status_icon="${C_CYAN}○${C_RESET}" ;;
                                    *) status_icon="${C_DIM}?${C_RESET}" ;;
                                esac
                                
                                # Format duration
                                if [ "$duration" != "null" ] && [ -n "$duration" ]; then
                                    # Convert decimal to integer (bash doesn't support floats)
                                    duration_int=$(echo "$duration" | cut -d. -f1)
                                    
                                    # Handle empty or invalid values
                                    if [ -z "$duration_int" ] || [ "$duration_int" == "null" ]; then
                                        duration_str="-"
                                    elif [ "$duration_int" -lt 60 ]; then
                                        duration_str="${duration_int}s"
                                    elif [ "$duration_int" -lt 3600 ]; then
                                        min=$((duration_int / 60))
                                        sec=$((duration_int % 60))
                                        duration_str="${min}m ${sec}s"
                                    else
                                        hour=$((duration_int / 3600))
                                        min=$(((duration_int % 3600) / 60))
                                        duration_str="${hour}h ${min}m"
                                    fi
                                else
                                    duration_str="-"
                                fi
                                
                                printf "    %s %-12s %-30s %s\n" "$status_icon" "$stage" "$name" "${C_DIM}$duration_str${C_RESET}"
                            done
                            
                            if [ "$job_count" -gt 10 ]; then
                                echo -e "    ${C_DIM}... and $((job_count - 10)) more jobs${C_RESET}"
                            fi
                        fi
                    fi
                fi
                
                if [ "$pipeline_url" != "null" ] && [ -n "$pipeline_url" ]; then
                    echo
                    echo -e "  ${C_CYAN}View Full Pipeline:${C_RESET} $pipeline_url"
                fi
            fi
            
            # Check for merge requests
            mrs=$(fetch_gitlab_merge_requests "$repo" "$clean_branch")
            if [ -n "$mrs" ] && [ "$mrs" != "[]" ] && [ "$mrs" != "null" ]; then
                mr_count=$(echo "$mrs" | jq 'length' 2>/dev/null)
                
                if [ "$mr_count" -gt 0 ]; then
                    echo
                    echo -e "  ${C_HEADER}Merge Request:${C_RESET}"
                    
                    # Get first MR details
                    mr_title=$(echo "$mrs" | jq -r '.[0].title' 2>/dev/null)
                    mr_state=$(echo "$mrs" | jq -r '.[0].state' 2>/dev/null)
                    mr_author=$(echo "$mrs" | jq -r '.[0].author.name' 2>/dev/null)
                    mr_created=$(echo "$mrs" | jq -r '.[0].created_at' 2>/dev/null)
                    mr_updated=$(echo "$mrs" | jq -r '.[0].updated_at' 2>/dev/null)
                    mr_url=$(echo "$mrs" | jq -r '.[0].web_url' 2>/dev/null)
                    mr_iid=$(echo "$mrs" | jq -r '.[0].iid' 2>/dev/null)
                    
                    # Approval info
                    mr_upvotes=$(echo "$mrs" | jq -r '.[0].upvotes' 2>/dev/null)
                    mr_downvotes=$(echo "$mrs" | jq -r '.[0].downvotes' 2>/dev/null)
                    mr_approvals=$(echo "$mrs" | jq -r '.[0].user_notes_count' 2>/dev/null)
                    
                    # Target branch
                    mr_target=$(echo "$mrs" | jq -r '.[0].target_branch' 2>/dev/null)
                    
                    if [ "$mr_title" != "null" ] && [ -n "$mr_title" ]; then
                        # Truncate if too long
                        if [ ${#mr_title} -gt 60 ]; then
                            mr_title="${mr_title:0:60}..."
                        fi
                        echo -e "    ${C_CYAN}Title:${C_RESET} !$mr_iid - $mr_title"
                    fi
                    
                    if [ "$mr_target" != "null" ] && [ -n "$mr_target" ]; then
                        echo -e "    ${C_CYAN}Target:${C_RESET} $mr_target"
                    fi
                    
                    if [ "$mr_author" != "null" ] && [ -n "$mr_author" ]; then
                        echo -e "    ${C_CYAN}Created by:${C_RESET} $mr_author"
                    fi
                    
                    if [ "$mr_created" != "null" ] && [ -n "$mr_created" ]; then
                        created_ts=$(date -d "$mr_created" +%s 2>/dev/null || echo "")
                        if [ -n "$created_ts" ]; then
                            now_ts=$(date +%s)
                            diff_sec=$((now_ts - created_ts))
                            
                            if [ $diff_sec -lt 3600 ]; then
                                rel_time="$((diff_sec / 60)) minutes ago"
                            elif [ $diff_sec -lt 86400 ]; then
                                rel_time="$((diff_sec / 3600)) hours ago"
                            else
                                rel_time="$((diff_sec / 86400)) days ago"
                            fi
                            
                            echo -e "    ${C_CYAN}Opened:${C_RESET} $rel_time"
                        fi
                    fi
                    
                    if [ "$mr_updated" != "null" ] && [ -n "$mr_updated" ] && [ "$mr_updated" != "$mr_created" ]; then
                        updated_ts=$(date -d "$mr_updated" +%s 2>/dev/null || echo "")
                        if [ -n "$updated_ts" ]; then
                            now_ts=$(date +%s)
                            diff_sec=$((now_ts - updated_ts))
                            
                            if [ $diff_sec -lt 3600 ]; then
                                rel_time="$((diff_sec / 60)) minutes ago"
                            elif [ $diff_sec -lt 86400 ]; then
                                rel_time="$((diff_sec / 3600)) hours ago"
                            else
                                rel_time="$((diff_sec / 86400)) days ago"
                            fi
                            
                            echo -e "    ${C_CYAN}Updated:${C_RESET} $rel_time"
                        fi
                    fi
                    
                    # Show approval status
                    if [ "$mr_upvotes" != "null" ] && [ "$mr_upvotes" -gt 0 ]; then
                        echo -e "    ${C_GREEN}Approvals:${C_RESET} 👍 $mr_upvotes"
                    fi
                    
                    if [ "$mr_downvotes" != "null" ] && [ "$mr_downvotes" -gt 0 ]; then
                        echo -e "    ${C_RED}Rejections:${C_RESET} 👎 $mr_downvotes"
                    fi
                    
                    if [ "$mr_url" != "null" ] && [ -n "$mr_url" ]; then
                        echo -e "    ${C_CYAN}View MR:${C_RESET} $mr_url"
                    fi
                    
                    if [ "$mr_count" -gt 1 ]; then
                        echo -e "    ${C_DIM}... and $((mr_count - 1)) more MR(s)${C_RESET}"
                    fi
                fi
            fi
        else
            echo -e "  ${C_YELLOW}⚠ Could not fetch pipeline status${C_RESET}"
            echo -e "  ${C_DIM}Possible reasons:${C_RESET}"
            echo -e "  ${C_DIM}- Branch not pushed${C_RESET}"
            echo -e "  ${C_DIM}- No GitLab CI configured${C_RESET}"
            echo -e "  ${C_DIM}- API rate limit${C_RESET}"
            echo -e "  ${C_DIM}- Token lacks permissions${C_RESET}"
            echo -e "  ${C_DIM}- jq not installed${C_RESET}"
        fi
    fi
    
    echo
    exit 0
fi

# =========================================================
# HELPER FUNCTIONS
# =========================================================

# Helper function for formatting duration
format_duration() {
    local seconds=$1
    if [ $seconds -lt 60 ]; then
        echo "${seconds}s"
    elif [ $seconds -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m"
    fi
}

# Helper function for formatting time ago
format_time_ago() {
    local then=$1
    local now=$(date +%s)
    local diff=$((now - then))
    
    if [ $diff -lt 60 ]; then
        echo "$diff seconds"
    elif [ $diff -lt 3600 ]; then
        echo "$((diff / 60)) minutes"
    elif [ $diff -lt 86400 ]; then
        echo "$((diff / 3600)) hours"
    else
        echo "$((diff / 86400)) days"
    fi
}

# =========================================================
# REAL-TIME CI/CD MONITORING
# =========================================================

if [ -n "$ACT_REALTIME_CI" ]; then
    branch="${ROWS_BRANCH_TEXT[$ACT_REALTIME_CI]}"
    
    if [ -z "$branch" ]; then
        echo -e "\n  ${C_RED}✖ Invalid branch ID: $ACT_REALTIME_CI${C_RESET}"
        echo -e "  ${C_DIM}Available IDs: 1-$TOTAL_VISIBLE${C_RESET}\n"
        exit 1
    fi
    
    # Parse optional refresh interval (default: 5 seconds)
    REFRESH_INTERVAL=5
    if [ -n "${EXTRA_ARGS[0]}" ]; then
        if [[ "${EXTRA_ARGS[0]}" =~ ^[0-9]+$ ]]; then
            REFRESH_INTERVAL="${EXTRA_ARGS[0]}"
            # Validate range (1-60 seconds)
            if [ "$REFRESH_INTERVAL" -lt 1 ]; then
                REFRESH_INTERVAL=1
                echo -e "${C_YELLOW}⚠ Minimum refresh interval is 1s${C_RESET}"
                sleep 1
            elif [ "$REFRESH_INTERVAL" -gt 60 ]; then
                REFRESH_INTERVAL=60
                echo -e "${C_YELLOW}⚠ Maximum refresh interval is 60s${C_RESET}"
                sleep 1
            fi
        else
            echo -e "${C_YELLOW}⚠ Invalid interval '${EXTRA_ARGS[0]}', using default 5s${C_RESET}"
            sleep 1
        fi
    fi
    
    # Remove remote prefix for API calls
    clean_branch=$(echo "$branch" | sed 's|^origin/||' | sed 's|^upstream/||')
    
    platform=$(detect_remote_platform)
    
    if [ -z "$platform" ]; then
        echo -e "\n  ${C_YELLOW}⚠ Could not detect Git platform${C_RESET}"
        echo -e "  ${C_DIM}Supported: GitHub, GitLab (including self-hosted)${C_RESET}\n"
        exit 1
    fi
    
    # Get repository info
    if [ "$platform" == "github" ]; then
        repo=$(parse_github_repo)
    else
        repo=$(parse_gitlab_repo)
    fi
    
    # Initial clear and header setup
    clear
    
    # Trap Ctrl+C for clean exit
    trap 'clear; echo -e "\n${C_YELLOW}⊗ Monitoring stopped${C_RESET}\n"; exit 0' INT
    
    # Initialize tracking variables
    last_status=""
    last_pipeline_id=""
    iteration=0
    start_time=$(date +%s)
    
    # Main monitoring loop
    while true; do
        iteration=$((iteration + 1))
        current_time=$(date '+%H:%M:%S')
        elapsed=$(($(date +%s) - start_time))
        
        # Clear screen completely for each update to prevent content mixup
        clear
        
        # Premium header
        echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║                                                                ║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET}        ${C_RED}●${C_RESET} ${C_BOLD}LIVE CI/CD MONITORING${C_RESET}  ${C_DIM}Press Ctrl+C to exit${C_RESET}      ${C_BOLD}${C_CYAN}║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║                                                                ║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════════════════════╝${C_RESET}\n"
        
        # Info bar
        platform_icon=$([ "$platform" == "github" ] && echo "🐙" || echo "🦊")
        platform_name=$([ "$platform" == "github" ] && echo "GitHub" || echo "GitLab")
        
        echo -e "  ${C_HEADER}┌─ Configuration${C_RESET}"
        echo -e "  ${C_HEADER}│${C_RESET}"
        echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Branch:${C_RESET}   ${C_BOLD}$branch${C_RESET}"
        echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Platform:${C_RESET} $platform_icon ${C_BOLD}$platform_name${C_RESET}"
        
        if [ "$platform" == "gitlab" ]; then
            gitlab_domain=$(get_gitlab_domain)
            echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Server:${C_RESET}   ${C_BOLD}$gitlab_domain${C_RESET}"
        fi
        
        echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Refresh:${C_RESET}  ${C_BOLD}Every ${REFRESH_INTERVAL}s${C_RESET}"
        echo -e "  ${C_HEADER}└─${C_RESET}\n"
        
        echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
        
        # Update header
        echo -e "  ${C_BOLD}${C_HEADER}╭─ Update #$iteration${C_RESET} ${C_DIM}│${C_RESET} ${C_CYAN}$current_time${C_RESET} ${C_DIM}│${C_RESET} ${C_DIM}Runtime: $(format_duration $elapsed)${C_RESET}"
        echo -e "  ${C_HEADER}│${C_RESET}"
        
        # Fetch and display status based on platform
        if [ "$platform" == "github" ]; then
            # GitHub monitoring
            workflows=$(fetch_github_workflows "$repo" "$clean_branch")
            
            if [ -n "$workflows" ] && [ "$workflows" != "null" ]; then
                run_count=$(echo "$workflows" | jq '.total_count' 2>/dev/null)
                
                if [ "$run_count" -gt 0 ]; then
                    run_id=$(echo "$workflows" | jq -r '.workflow_runs[0].id' 2>/dev/null)
                    run_name=$(echo "$workflows" | jq -r '.workflow_runs[0].name' 2>/dev/null)
                    run_status=$(echo "$workflows" | jq -r '.workflow_runs[0].status' 2>/dev/null)
                    run_conclusion=$(echo "$workflows" | jq -r '.workflow_runs[0].conclusion' 2>/dev/null)
                    run_number=$(echo "$workflows" | jq -r '.workflow_runs[0].run_number' 2>/dev/null)
                    run_created=$(echo "$workflows" | jq -r '.workflow_runs[0].created_at' 2>/dev/null)
                    run_updated=$(echo "$workflows" | jq -r '.workflow_runs[0].updated_at' 2>/dev/null)
                    
                    # Detect status change
                    current_status="${run_status}-${run_conclusion}"
                    if [ "$current_status" != "$last_status" ] && [ -n "$last_status" ]; then
                        echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}⚡ STATUS CHANGED${C_RESET} ${C_DIM}${last_status}${C_RESET} → ${C_BOLD}${current_status}${C_RESET}"
                        echo -e "  ${C_HEADER}│${C_RESET}"
                    fi
                    last_status="$current_status"
                    
                    # Status badge with animation
                    if [ "$run_status" == "completed" ]; then
                        case "$run_conclusion" in
                            success) echo -e "  ${C_HEADER}├─${C_RESET} ${C_GREEN}●●●●●●●●●●${C_RESET} ${C_BOLD}${C_GREEN}PASSED${C_RESET} ✓" ;;
                            failure) echo -e "  ${C_HEADER}├─${C_RESET} ${C_RED}●●●●●●●●●●${C_RESET} ${C_BOLD}${C_RED}FAILED${C_RESET} ✗" ;;
                            cancelled) echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}○○○○○○○○○○${C_RESET} ${C_BOLD}${C_YELLOW}CANCELLED${C_RESET} ⊗" ;;
                            *) echo -e "  ${C_HEADER}├─${C_RESET} ${C_DIM}○○○○○○○○○○${C_RESET} ${C_BOLD}${run_conclusion^^}${C_RESET}" ;;
                        esac
                    elif [ "$run_status" == "in_progress" ]; then
                        # Animated progress
                        progress_pos=$((iteration % 10))
                        progress_bar=""
                        for i in {0..9}; do
                            [ $i -eq $progress_pos ] && progress_bar="${progress_bar}${C_YELLOW}●${C_RESET}" || progress_bar="${progress_bar}${C_DIM}○${C_RESET}"
                        done
                        echo -e "  ${C_HEADER}├─${C_RESET} ${progress_bar} ${C_BOLD}${C_YELLOW}RUNNING${C_RESET} ⏳"
                    elif [ "$run_status" == "queued" ]; then
                        echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}○○○○○○○○○○${C_RESET} ${C_BOLD}${C_CYAN}QUEUED${C_RESET} ○"
                    fi
                    
                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_DIM}Workflow: ${C_RESET}${run_name}  ${C_DIM}│${C_RESET}  ${C_DIM}Run: ${C_RESET}#$run_number  ${C_DIM}│${C_RESET}  ${C_DIM}ID: ${C_RESET}$run_id"
                    echo -e "  ${C_HEADER}│${C_RESET}"
                    
                    # Timeline
                    if [ "$run_created" != "null" ] && [ -n "$run_created" ]; then
                        created_ts=$(date -d "$run_created" +%s 2>/dev/null || echo "")
                        now_ts=$(date +%s)
                        
                        if [ -n "$created_ts" ] && [ "$run_updated" != "null" ] && [ -n "$run_updated" ]; then
                            updated_ts=$(date -d "$run_updated" +%s 2>/dev/null || echo "")
                            if [ -n "$updated_ts" ]; then
                                duration=$((updated_ts - created_ts))
                                elapsed_since_start=$((now_ts - created_ts))
                                
                                if [ "$run_status" == "in_progress" ]; then
                                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Duration:${C_RESET} ${C_BOLD}$(format_duration $elapsed_since_start)${C_RESET} ${C_DIM}(running)${C_RESET}"
                                else
                                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Duration:${C_RESET} ${C_BOLD}$(format_duration $duration)${C_RESET}"
                                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Finished:${C_RESET} ${C_DIM}$(format_time_ago $updated_ts) ago${C_RESET}"
                                fi
                            fi
                        fi
                    fi
                    
                    # Jobs
                    jobs=$(fetch_github_workflow_jobs "$repo" "$run_id")
                    if [ -n "$jobs" ]; then
                        job_count=$(echo "$jobs" | jq '.total_count' 2>/dev/null)
                        
                        if [ "$job_count" -gt 0 ]; then
                            echo -e "  ${C_HEADER}│${C_RESET}"
                            echo -e "  ${C_HEADER}├─${C_RESET} ${C_BOLD}Jobs Summary${C_RESET} ${C_DIM}($job_count total)${C_RESET}"
                            
                            success=$(echo "$jobs" | jq '[.jobs[] | select(.conclusion=="success")] | length' 2>/dev/null)
                            failed=$(echo "$jobs" | jq '[.jobs[] | select(.conclusion=="failure")] | length' 2>/dev/null)
                            running=$(echo "$jobs" | jq '[.jobs[] | select(.status=="in_progress")] | length' 2>/dev/null)
                            queued=$(echo "$jobs" | jq '[.jobs[] | select(.status=="queued")] | length' 2>/dev/null)
                            
                            echo -e "  ${C_HEADER}├─${C_RESET} ${C_GREEN}✓ $success${C_RESET}  ${C_RED}✗ $failed${C_RESET}  ${C_YELLOW}⏳ $running${C_RESET}  ${C_CYAN}○ $queued${C_RESET}"
                            echo -e "  ${C_HEADER}│${C_RESET}"
                            
                            # Show jobs (max 15 to prevent screen overflow)
                            local job_num=0
                            echo "$jobs" | jq -r '.jobs[] | "\(.name)|\(.status)|\(.conclusion)|\(.started_at)|\(.completed_at)"' 2>/dev/null | head -15 | while IFS='|' read -r name status conclusion started completed; do
                                job_num=$((job_num + 1))
                                
                                case "$status" in
                                    completed)
                                        case "$conclusion" in
                                            success) icon="${C_GREEN}✓${C_RESET}" ;;
                                            failure) icon="${C_RED}✗${C_RESET}" ;;
                                            *) icon="${C_DIM}?${C_RESET}" ;;
                                        esac
                                        ;;
                                    in_progress) icon="${C_YELLOW}⏳${C_RESET}" ;;
                                    *) icon="${C_CYAN}○${C_RESET}" ;;
                                esac
                                
                                # Duration
                                dur_str="-"
                                if [ "$started" != "null" ] && [ "$completed" != "null" ]; then
                                    start_ts=$(date -d "$started" +%s 2>/dev/null || echo "")
                                    complete_ts=$(date -d "$completed" +%s 2>/dev/null || echo "")
                                    if [ -n "$start_ts" ] && [ -n "$complete_ts" ]; then
                                        dur=$((complete_ts - start_ts))
                                        dur_str=$(format_duration $dur)
                                    fi
                                elif [ "$started" != "null" ] && [ "$status" == "in_progress" ]; then
                                    start_ts=$(date -d "$started" +%s 2>/dev/null || echo "")
                                    if [ -n "$start_ts" ]; then
                                        dur=$((now_ts - start_ts))
                                        dur_str="${C_YELLOW}$(format_duration $dur)${C_RESET} ${C_DIM}...${C_RESET}"
                                    fi
                                fi
                                
                                # Truncate long names
                                if [ ${#name} -gt 45 ]; then
                                    name="${name:0:42}..."
                                fi
                                
                                echo -e "  ${C_HEADER}├──${C_RESET} $icon  ${C_DIM}$(printf '%-45s' "$name")${C_RESET}  $dur_str"
                            done
                            
                            if [ "$job_count" -gt 15 ]; then
                                echo -e "  ${C_HEADER}├──${C_RESET} ${C_DIM}... and $((job_count - 15)) more jobs${C_RESET}"
                            fi
                        fi
                    fi
                else
                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}⚠ No workflows found${C_RESET}"
                fi
            else
                echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}⚠ No workflow data available${C_RESET}"
            fi
            
        else
            # GitLab monitoring
            status=$(fetch_gitlab_ci_status "$repo" "$clean_branch")
            
            if [ -n "$status" ] && command -v jq >/dev/null 2>&1; then
                pipeline=$(echo "$status" | jq -r '.last_pipeline.status' 2>/dev/null)
                pipeline_id=$(echo "$status" | jq -r '.last_pipeline.id' 2>/dev/null)
                
                # Detect change
                if [ "$pipeline_id" != "$last_pipeline_id" ] && [ -n "$last_pipeline_id" ]; then
                    echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}⚡ NEW PIPELINE${C_RESET} ${C_DIM}#$last_pipeline_id${C_RESET} → ${C_BOLD}#$pipeline_id${C_RESET}"
                    echo -e "  ${C_HEADER}│${C_RESET}"
                fi
                last_pipeline_id="$pipeline_id"
                
                # Status badge
                case "$pipeline" in
                    success) echo -e "  ${C_HEADER}├─${C_RESET} ${C_GREEN}●●●●●●●●●●${C_RESET} ${C_BOLD}${C_GREEN}PASSED${C_RESET} ✓" ;;
                    running)
                        progress_pos=$((iteration % 10))
                        progress_bar=""
                        for i in {0..9}; do
                            [ $i -eq $progress_pos ] && progress_bar="${progress_bar}${C_YELLOW}●${C_RESET}" || progress_bar="${progress_bar}${C_DIM}○${C_RESET}"
                        done
                        echo -e "  ${C_HEADER}├─${C_RESET} ${progress_bar} ${C_BOLD}${C_YELLOW}RUNNING${C_RESET} ⏳"
                        ;;
                    failed) echo -e "  ${C_HEADER}├─${C_RESET} ${C_RED}●●●●●●●●●●${C_RESET} ${C_BOLD}${C_RED}FAILED${C_RESET} ✗" ;;
                    pending) echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}○○○○○○○○○○${C_RESET} ${C_BOLD}${C_CYAN}PENDING${C_RESET} ○" ;;
                    manual) echo -e "  ${C_HEADER}├─${C_RESET} ${C_BLUE}⚙⚙⚙⚙⚙⚙⚙⚙⚙⚙${C_RESET} ${C_BOLD}${C_BLUE}MANUAL${C_RESET} ⚙" ;;
                    canceled) echo -e "  ${C_HEADER}├─${C_RESET} ${C_YELLOW}○○○○○○○○○○${C_RESET} ${C_BOLD}${C_YELLOW}CANCELED${C_RESET} ⊗" ;;
                    skipped) echo -e "  ${C_HEADER}├─${C_RESET} ${C_DIM}⊘⊘⊘⊘⊘⊘⊘⊘⊘⊘${C_RESET} ${C_BOLD}${C_DIM}SKIPPED${C_RESET} ⊘" ;;
                    created) echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}○○○○○○○○○○${C_RESET} ${C_BOLD}${C_CYAN}CREATED${C_RESET} ○" ;;
                    *) echo -e "  ${C_HEADER}├─${C_RESET} ${C_DIM}??????????${C_RESET} ${C_BOLD}${pipeline^^}${C_RESET}" ;;
                esac
                
                pipeline_iid=$(echo "$status" | jq -r '.last_pipeline.iid' 2>/dev/null)
                echo -e "  ${C_HEADER}├─${C_RESET} ${C_DIM}Pipeline: ${C_RESET}#$pipeline_iid  ${C_DIM}│${C_RESET}  ${C_DIM}ID: ${C_RESET}$pipeline_id"
                echo -e "  ${C_HEADER}│${C_RESET}"
                
                # Timeline
                pipeline_created=$(echo "$status" | jq -r '.last_pipeline.created_at' 2>/dev/null)
                pipeline_updated=$(echo "$status" | jq -r '.last_pipeline.updated_at' 2>/dev/null)
                
                if [ "$pipeline_created" != "null" ]; then
                    created_ts=$(date -d "$pipeline_created" +%s 2>/dev/null || echo "")
                    now_ts=$(date +%s)
                    
                    if [ -n "$created_ts" ] && [ "$pipeline_updated" != "null" ]; then
                        updated_ts=$(date -d "$pipeline_updated" +%s 2>/dev/null || echo "")
                        if [ -n "$updated_ts" ]; then
                            duration=$((updated_ts - created_ts))
                            elapsed=$((now_ts - created_ts))
                            
                            if [ "$pipeline" == "running" ]; then
                                echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Duration:${C_RESET} ${C_BOLD}$(format_duration $elapsed)${C_RESET} ${C_DIM}(running)${C_RESET}"
                            else
                                echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Duration:${C_RESET} ${C_BOLD}$(format_duration $duration)${C_RESET}"
                                echo -e "  ${C_HEADER}├─${C_RESET} ${C_CYAN}Finished:${C_RESET} ${C_DIM}$(format_time_ago $updated_ts) ago${C_RESET}"
                            fi
                        fi
                    fi
                fi
                
                # Jobs
                if [ "$pipeline_id" != "null" ]; then
                    jobs=$(fetch_gitlab_pipeline_details "$repo" "$pipeline_id")
                    
                    if [ -n "$jobs" ] && [ "$jobs" != "[]" ]; then
                        job_count=$(echo "$jobs" | jq 'length' 2>/dev/null)
                        
                        if [ "$job_count" -gt 0 ]; then
                            echo -e "  ${C_HEADER}│${C_RESET}"
                            echo -e "  ${C_HEADER}├─${C_RESET} ${C_BOLD}Jobs Summary${C_RESET} ${C_DIM}($job_count total)${C_RESET}"
                            
                            success=$(echo "$jobs" | jq '[.[] | select(.status=="success")] | length' 2>/dev/null)
                            failed=$(echo "$jobs" | jq '[.[] | select(.status=="failed")] | length' 2>/dev/null)
                            running=$(echo "$jobs" | jq '[.[] | select(.status=="running")] | length' 2>/dev/null)
                            pending=$(echo "$jobs" | jq '[.[] | select(.status=="pending")] | length' 2>/dev/null)
                            created=$(echo "$jobs" | jq '[.[] | select(.status=="created")] | length' 2>/dev/null)
                            manual=$(echo "$jobs" | jq '[.[] | select(.status=="manual")] | length' 2>/dev/null)
                            
                            echo -e "  ${C_HEADER}├─${C_RESET} ${C_GREEN}✓ $success${C_RESET}  ${C_RED}✗ $failed${C_RESET}  ${C_YELLOW}⏳ $running${C_RESET}  ${C_CYAN}○ $((pending + created))${C_RESET}  ${C_BLUE}⚙ $manual${C_RESET}"
                            echo -e "  ${C_HEADER}│${C_RESET}"
                            
                            # Show jobs (max 15)
                            echo "$jobs" | jq -r '.[] | "\(.stage)|\(.name)|\(.status)|\(.duration)"' 2>/dev/null | head -15 | while IFS='|' read -r stage name stat duration; do
                                case "$stat" in
                                    success) icon="${C_GREEN}✓${C_RESET}" ;;
                                    failed) icon="${C_RED}✗${C_RESET}" ;;
                                    running) icon="${C_YELLOW}⏳${C_RESET}" ;;
                                    pending|created) icon="${C_CYAN}○${C_RESET}" ;;
                                    manual) icon="${C_BLUE}⚙${C_RESET}" ;;
                                    *) icon="${C_DIM}?${C_RESET}" ;;
                                esac
                                
                                # Duration
                                dur_str="-"
                                if [ "$duration" != "null" ] && [ -n "$duration" ]; then
                                    duration_int=$(echo "$duration" | cut -d. -f1)
                                    if [ -n "$duration_int" ] && [ "$duration_int" != "null" ]; then
                                        dur_str=$(format_duration $duration_int)
                                    fi
                                fi
                                
                                # Truncate long names
                                if [ ${#name} -gt 30 ]; then
                                    name="${name:0:27}..."
                                fi
                                
                                echo -e "  ${C_HEADER}├──${C_RESET} $icon  ${C_DIM}$(printf '%-12s' "$stage")${C_RESET}  $(printf '%-30s' "$name")  ${C_DIM}$dur_str${C_RESET}"
                            done
                            
                            if [ "$job_count" -gt 15 ]; then
                                echo -e "  ${C_HEADER}├──${C_RESET} ${C_DIM}... and $((job_count - 15)) more jobs${C_RESET}"
                            fi
                        fi
                    fi
                fi
            fi
        fi
        
        # Footer
        echo -e "  ${C_HEADER}│${C_RESET}"
        echo -e "  ${C_HEADER}╰─${C_RESET}${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
        
        # Countdown with progress bar
        for ((i=REFRESH_INTERVAL; i>0; i--)); do
            progress=$((100 - (i * 100 / REFRESH_INTERVAL)))
            bar_length=$((progress / 2))
            bar=""
            for ((j=0; j<50; j++)); do
                if [ $j -lt $bar_length ]; then
                    bar="${bar}${C_CYAN}━${C_RESET}"
                else
                    bar="${bar}${C_DIM}━${C_RESET}"
                fi
            done
            
            echo -ne "\r  ${C_DIM}Next refresh:${C_RESET} ${bar} ${C_BOLD}${i}s${C_RESET}  ${C_DIM}│${C_RESET}  ${C_DIM}Press Ctrl+C to stop${C_RESET}     "
            sleep 1
        done
        
        # Small delay before next refresh to show "Refreshing..."
        echo -ne "\r  ${C_DIM}Refreshing...${C_RESET}                                                                       \r"
        sleep 0.1
    done
    
    exit 0
fi

# =========================================================
# OTHER ACTIONS
# =========================================================

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

if [ -n "$ACT_DIFF" ]; then
    IFS=':' read -r ID1 ID2 <<< "$ACT_DIFF"
    
    commit1="${ROWS_HASH[$ID1]}"
    commit2="${ROWS_HASH[$ID2]}"
    branch1="${ROWS_BRANCH_TEXT[$ID1]}"
    branch2="${ROWS_BRANCH_TEXT[$ID2]}"
    
    if [ -z "$commit1" ] || [ -z "$commit2" ]; then
        echo -e "\n  ${C_RED}✖ Invalid branch IDs: $ID1, $ID2${C_RESET}"
        echo -e "  ${C_DIM}Available IDs: 1-$TOTAL_VISIBLE${C_RESET}\n"
        exit 1
    fi
    
    echo -e "\n  ${C_BOLD}${ICON_SEARCH} COMMIT COMPARISON${C_RESET}\n"
    
    # Show commit details
    echo -e "  ${C_HEADER}Commit 1:${C_RESET}"
    echo -e "    ${C_CYAN}Branch:${C_RESET} $branch1"
    echo -e "    ${C_CYAN}SHA:${C_RESET} $commit1"
    git log -1 --format="    ${C_CYAN}Author:${C_RESET} %an <%ae>%n    ${C_CYAN}Date:${C_RESET} %cr%n    ${C_CYAN}Message:${C_RESET} %s" "$commit1" 2>/dev/null
    
    echo
    echo -e "  ${C_HEADER}Commit 2:${C_RESET}"
    echo -e "    ${C_CYAN}Branch:${C_RESET} $branch2"
    echo -e "    ${C_CYAN}SHA:${C_RESET} $commit2"
    git log -1 --format="    ${C_CYAN}Author:${C_RESET} %an <%ae>%n    ${C_CYAN}Date:${C_RESET} %cr%n    ${C_CYAN}Message:${C_RESET} %s" "$commit2" 2>/dev/null
    
    echo
    echo -e "  ${C_HEADER}Summary:${C_RESET}"
    
    # Get diff stats
    files_changed=$(git diff --numstat "$commit1" "$commit2" 2>/dev/null | wc -l)
    additions=$(git diff --numstat "$commit1" "$commit2" 2>/dev/null | awk '{add+=$1} END {print add+0}')
    deletions=$(git diff --numstat "$commit1" "$commit2" 2>/dev/null | awk '{del+=$2} END {print del+0}')
    
    echo -e "    ${C_CYAN}Files changed:${C_RESET} $files_changed"
    echo -e "    ${C_GREEN}Additions:${C_RESET}    +$additions lines"
    echo -e "    ${C_RED}Deletions:${C_RESET}    -$deletions lines"
    echo -e "    ${C_CYAN}Net change:${C_RESET}   $((additions - deletions)) lines"
    
    echo
    echo -e "  ${C_HEADER}Changed Files:${C_RESET}"
    git diff --stat "$commit1" "$commit2" 2>/dev/null | head -20 | sed 's/^/    /'
    
    total_files=$(git diff --name-only "$commit1" "$commit2" 2>/dev/null | wc -l)
    if [ "$total_files" -gt 20 ]; then
        echo -e "    ${C_DIM}... and $((total_files - 20)) more files${C_RESET}"
    fi
    
    echo
    echo -e "  ${C_HEADER}File-by-File Changes:${C_RESET}"
    git diff --name-status "$commit1" "$commit2" 2>/dev/null | head -15 | while IFS=$'\t' read -r status file; do
        case "$status" in
            A) echo -e "    ${C_GREEN}+${C_RESET} ${C_DIM}Added:${C_RESET}    $file" ;;
            M) echo -e "    ${C_YELLOW}~${C_RESET} ${C_DIM}Modified:${C_RESET} $file" ;;
            D) echo -e "    ${C_RED}-${C_RESET} ${C_DIM}Deleted:${C_RESET}  $file" ;;
            R*) echo -e "    ${C_CYAN}→${C_RESET} ${C_DIM}Renamed:${C_RESET}  $file" ;;
            *) echo -e "    ${C_DIM}?${C_RESET} $status: $file" ;;
        esac
    done
    
    if [ "$total_files" -gt 15 ]; then
        echo -e "    ${C_DIM}... and $((total_files - 15)) more files${C_RESET}"
    fi
    
    echo
    echo -e "  ${C_HEADER}View Full Diff:${C_RESET}"
    echo -e "    ${C_CYAN}git diff $commit1 $commit2${C_RESET}"
    echo -e "    ${C_CYAN}git diff $commit1 $commit2 -- <file>${C_RESET} ${C_DIM}(for specific file)${C_RESET}"
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
