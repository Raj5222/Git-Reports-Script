#!/bin/bash

# =========================================================
# ERROR UI (Red highlighted, professional)
# =========================================================
print_error() {
  RED="\033[1;31m"
  RESET="\033[0m"

  echo
  echo -e "${RED}┌─ ERROR ───────────────────────────────────────────────┐${RESET}"
  printf "${RED}│ %-52s │${RESET}\n" "Message : $1"

  [ -n "$2" ] && printf "${RED}│ %-52s │${RESET}\n" "Hint    : $2"
  [ -n "$3" ] && printf "${RED}│ %-52s │${RESET}\n" "Example : $3"

  echo -e "${RED}└────────────────────────────────────────────────────────┘${RESET}"
  exit 1
}

set -o pipefail

# =========================================================
# DEFAULT LIMIT
# =========================================================
DEFAULT_LIMIT=10
INPUT_LIMIT="$1"

# =========================================================
# GIT REPOSITORY CHECK
# =========================================================
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && print_error \
  "Not a Git repository" \
  "Run this command inside a Git project"

cd "$REPO_ROOT" || print_error "Unable to access Git repository"

# =========================================================
# STRICT INPUT VALIDATION (NO AUTO ADJUST)
# =========================================================
if [ -z "$INPUT_LIMIT" ]; then
  LIMIT="$DEFAULT_LIMIT"

elif ! [[ "$INPUT_LIMIT" =~ ^[0-9]+$ ]]; then
  print_error \
    "Invalid argument" \
    "Please provide a positive number" \
    "git-records 10"

elif [ "$INPUT_LIMIT" = "0" ]; then
  print_error \
    "Invalid limit value" \
    "Limit must be greater than zero" \
    "git-records 5"

elif [[ "$INPUT_LIMIT" =~ ^0[0-9]+$ ]]; then
  print_error \
    "Invalid number format" \
    "Leading zeros are not allowed" \
    "git-records 5"

# Hard safety limit (prevents overflow & head crash)
elif [ "${#INPUT_LIMIT}" -gt 6 ]; then
  print_error \
    "Limit value is too large" \
    "Please provide a reasonable number" \
    "git-records 100"

else
  LIMIT="$INPUT_LIMIT"
fi

# =========================================================
# COUNTS (DISPLAY ONLY)
# =========================================================
LOCAL_COUNT=$(git for-each-ref refs/heads | wc -l)
REMOTE_COUNT=$(git for-each-ref refs/remotes | wc -l)
TOTAL_COUNT=$((LOCAL_COUNT + REMOTE_COUNT))
CURRENT_BRANCH=$(git branch --show-current)

# =========================================================
# COLORS
# =========================================================
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# =========================================================
# SUMMARY
# =========================================================
echo -e "${CYAN}Git Records${RESET}"
echo "Repository : $REPO_ROOT"
echo "--------------------------------"
echo -e "Current Branch : ${GREEN}$CURRENT_BRANCH${RESET}"
echo -e "Local Records  : ${YELLOW}$LOCAL_COUNT${RESET}"
echo -e "Remote Records : ${YELLOW}$REMOTE_COUNT${RESET}"
echo -e "Total Records  : ${YELLOW}$TOTAL_COUNT${RESET}"
echo -e "Showing Latest : ${YELLOW}$LIMIT${RESET}"
echo

# =========================================================
# TABLE HEADER
# =========================================================
echo -e "${CYAN}+----+--------+-----------------+------------------------------------------+${RESET}"
echo -e "${CYAN}| No | TYPE   | LAST COMMIT     | BRANCH                                   |${RESET}"
echo -e "${CYAN}+----+--------+-----------------+------------------------------------------+${RESET}"

# =========================================================
# TABLE DATA
# =========================================================
i=1
git for-each-ref \
  --sort=-committerdate \
  --format='%(HEAD)|%(refname)|%(committerdate:relative)|%(refname:short)' \
  refs/heads refs/remotes 2>/dev/null |
head -n "$LIMIT" |
while IFS='|' read -r head fullref time branch; do

  if [[ "$fullref" == refs/heads/* ]]; then
    type="LOCAL"
  else
    type="REMOTE"
  fi

  if [ "$head" = "*" ]; then
    printf "${GREEN}| %-2d | %-6s | %-15s | %-40s |${RESET}\n" \
      "$i" "$type" "$time" "$branch"
  else
    printf "| %-2d | %-6s | %-15s | %-40s |\n" \
      "$i" "$type" "$time" "$branch"
  fi

  i=$((i + 1))
done

# =========================================================
# FOOTER
# =========================================================
echo -e "${CYAN}+----+--------+-----------------+------------------------------------------+${RESET}"
