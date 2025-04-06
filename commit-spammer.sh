#!/bin/bash

# Function to determine OS type
detect_os() {
  case "$(uname -s)" in
    Linux*)     OS="Linux";;
    Darwin*)    OS="macOS";;
    CYGWIN*)    OS="Windows";;
    MINGW*)     OS="Windows";;
    MSYS*)      OS="Windows";;
    *)          OS="Unknown";;
  esac
  echo "$OS"
}

# Function for cross-platform date manipulation
get_date() {
  local os=$(detect_os)
  local date_str="$1"
  local format="$2"
  local operation="$3"

  if [[ "$os" == "macOS" ]]; then
    if [[ -z "$operation" ]]; then
      date -j -f "%Y-%m-%d" "$date_str" +"$format" 2>/dev/null || { echo "Invalid date" >&2; exit 1; }
    elif [[ "$operation" == "+1day" ]]; then
      date -j -v+1d -f "%Y-%m-%d" "$date_str" +"%Y-%m-%d" 2>/dev/null || { echo "Invalid date" >&2; exit 1; }
    fi
  else
    if [[ -z "$operation" ]]; then
      date -d "$date_str" +"$format" 2>/dev/null || { echo "Invalid date" >&2; exit 1; }
    elif [[ "$operation" == "+1day" ]]; then
      date -d "$date_str + 1 day" +"%Y-%m-%d" 2>/dev/null || { echo "Invalid date" >&2; exit 1; }
    fi
  fi
}

# Function to get current date in YYYY-MM-DD format
get_current_date() {
  date +"%Y-%m-%d"
}

# Function to compare dates (returns 1 if date1 <= date2, 0 otherwise)
compare_dates() {
  local date1="$1"
  local date2="$2"
  local os=$(detect_os)

  if [[ "$os" == "macOS" ]]; then
    local epoch1=$(date -j -f "%Y-%m-%d" "$date1" +%s 2>/dev/null) || { echo "Invalid date" >&2; exit 1; }
    local epoch2=$(date -j -f "%Y-%m-%d" "$date2" +%s 2>/dev/null) || { echo "Invalid date" >&2; exit 1; }
  else
    local epoch1=$(date -d "$date1" +%s 2>/dev/null) || { echo "Invalid date" >&2; exit 1; }
    local epoch2=$(date -d "$date2" +%s 2>/dev/null) || { echo "Invalid date" >&2; exit 1; }
  fi

  [[ $epoch1 -le $epoch2 ]] && echo 1 || echo 0
}

# Function to get a random number between 1 and max
get_random() {
  local max=$1
  echo $(( (RANDOM % max) + 1 ))
}

# Function to check if Git is installed
check_git() {
  if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install Git from https://git-scm.com/downloads and try again."
    exit 1
  fi
}

# Function to check Git configuration
check_git_config() {
  local git_user=$(git config --global user.name)
  local git_email=$(git config --global user.email)

  if [[ -z "$git_user" || -z "$git_email" ]]; then
    echo "$msg_git_fail"
    echo "$git_tutorial"
    exit 1
  fi
}

# Function to check if a directory is a Git repository
is_git_repo() {
  local dir="$1"
  [[ -d "$dir/.git" ]] && return 0 || return 1
}

# Function to count existing commits for a specific date
count_commits_for_date() {
  local check_date="$1"
  local git_count=$(git log --after="$check_date 00:00:00" --before="$check_date 23:59:59" --oneline 2>/dev/null | wc -l)
  # Trim whitespace and ensure it's a number
  git_count=$(echo "$git_count" | tr -d '[:space:]')
  if [[ -z "$git_count" || ! "$git_count" =~ ^[0-9]+$ ]]; then
    git_count=0
  fi

  local log_count=$(grep -c "Commit date: $check_date" log.txt 2>/dev/null || echo 0)
  # Ensure log_count is a number
  if [[ -z "$log_count" || ! "$log_count" =~ ^[0-9]+$ ]]; then
    log_count=0
  fi

  # Compare and return the larger value
  if (( git_count > log_count )); then
    echo "$git_count"
  else
    echo "$log_count"
  fi
}

# Function to handle repository setup
setup_repository() {
  local repo_name="$1"

  if [[ -z "$repo_name" || "$repo_name" == "." ]]; then
    echo "$msg_using_current_dir"
    if is_git_repo "."; then
      echo "$msg_existing_repo_current"
    else
      git init || { echo "Failed to initialize repository due to permission issues."; exit 1; }
      echo "$msg_init_current"
    fi
    return 0
  fi

  if [[ -d "$repo_name" ]]; then
    if is_git_repo "$repo_name"; then
      printf "$msg_existing_repo\n" "$repo_name"
      cd "$repo_name" || { echo "Cannot access directory '$repo_name'."; exit 1; }
    else
      printf "$msg_dir_not_repo\n" "$repo_name"
      read -p "$msg_init_existing_dir" init_choice
      if [[ "$init_choice" == "y" ]]; then
        cd "$repo_name" || exit 1
        git init || { echo "Failed to initialize repository."; exit 1; }
        printf "$msg_initialized\n" "$repo_name"
      else
        echo "$msg_aborting"
        exit 1
      fi
    fi
  else
    mkdir -p "$repo_name" || { echo "Failed to create directory '$repo_name'."; exit 1; }
    cd "$repo_name" || exit 1
    git init || { echo "Failed to initialize repository."; exit 1; }
    printf "$msg_created_and_init\n" "$repo_name"
  fi
}

# Check prerequisites
check_git
if [[ "$(detect_os)" == "Windows" ]] && [[ -z "$BASH" ]]; then
  echo "On Windows, run this script in Git Bash (https://gitforwindows.org/) or WSL."
  exit 1
fi

# Welcome message
echo "Welcome to the Git Commit Generator!"
echo "This script creates a fun Git history with random commits."

# Language selection
echo "Select language / 选择语言 / 言語を選択してください:"
echo "1. English"
echo "2. 中文"
echo "3. 日本語"
read -p "Enter 1/2/3 (default: English): " lang_choice

case "$lang_choice" in
    2)
        msg_repo="请输入仓库名称 (留空使用当前目录): "
        msg_branch="选择 Git 主分支名称: 1) master 2) main 3) 自定义: "
        msg_custom_branch="请输入自定义分支名称: "
        msg_gpg="是否启用 GPG 签名提交？(y/n): "
        msg_start_date="请输入开始日期 (格式: YYYY-MM-DD): "
        msg_skip="跳过"
        msg_commit="已提交"
        msg_done="所有提交已生成完毕！"
        msg_git_check="检测 Git 配置..."
        msg_git_fail="未检测到 Git 用户名或邮箱，请先配置 Git:"
        git_tutorial="https://git-scm.com/book/zh/v2/%e8%b5%b7%e6%ad%a5-%e5%88%9d%e6%ac%a1%e8%bf%90%e8%a1%8c-Git-%e5%89%8d%e7%9a%84%e9%85%8d%e7%bd%ae"
        msg_invalid_date="无效的日期格式，请使用 YYYY-MM-DD 格式"
        msg_date_future="开始日期不能在未来"
        msg_using_current_dir="使用当前目录作为仓库。"
        msg_existing_repo_current="当前目录已经是一个 Git 仓库，将继续使用它。"
        msg_init_current="在当前目录初始化 Git 仓库。"
        msg_existing_repo="目录 '%s' 已经是一个 Git 仓库，将继续使用它。"
        msg_dir_not_repo="目录 '%s' 存在但不是一个 Git 仓库。"
        msg_init_existing_dir="是否要将其初始化为 Git 仓库？(y/n): "
        msg_aborting="操作已取消。"
        msg_initialized="已初始化目录 '%s' 为 Git 仓库。"
        msg_created_and_init="已创建并初始化目录 '%s' 为 Git 仓库。"
        msg_branch_exists="分支 '%s' 已存在，切换到该分支。"
        msg_branch_new="创建并切换到新分支 '%s'。"
        msg_existing_commit="日期 %s 已有 %d 条提交记录，目标值为 %d。"
        msg_checking_commits="检查现有提交记录..."
        msg_stats="统计信息: 处理 %d 天，总共生成 %d 个提交。"
        msg_max_commits="每日最大提交数量 (输入 1 或更大的数字): "
        msg_invalid_max_commits="无效的输入，请输入一个大于 0 的整数。"
        msg_daily_plan="日期 %s: 计划生成 %d 个提交，已有 %d 个，需要添加 %d 个。"
        msg_commit_nth="已为 %s 添加第 %d 条提交记录"
        msg_daily_done="日期 %s: 已完成所需提交。"
        ;;
    3)
        msg_repo="リポジトリ名を入力してください (空白の場合は現在のディレクトリを使用): "
        msg_branch="Git のデフォルトブランチを選択してください: 1) master 2) main 3) カスタム: "
        msg_custom_branch="カスタムブランチ名を入力してください: "
        msg_gpg="GPG 署名を使用しますか？(y/n): "
        msg_start_date="開始日を入力してください (YYYY-MM-DD形式): "
        msg_skip="スキップ"
        msg_commit="コミットしました"
        msg_done="すべてのコミットが完了しました！"
        msg_git_check="Git 設定をチェック中..."
        msg_git_fail="Git のユーザー名またはメールが設定されていません。設定してください:"
        git_tutorial="https://git-scm.com/book/ja/v2/%e4%bd%bf%e3%81%84%e5%a7%8b%e3%82%81%e3%82%8b-%e6%9c%80%e5%88%9d%e3%81%aeGit%e3%81%ae%e6%a7%8b%e6%88%90"
        msg_invalid_date="無効な日付形式です。YYYY-MM-DD形式を使用してください"
        msg_date_future="開始日は未来の日付にできません"
        msg_using_current_dir="現在のディレクトリをリポジトリとして使用します。"
        msg_existing_repo_current="現在のディレクトリはすでに Git リポジトリです。継続して使用します。"
        msg_init_current="現在のディレクトリに Git リポジトリを初期化します。"
        msg_existing_repo="ディレクトリ '%s' はすでに Git リポジトリです。継続して使用します。"
        msg_dir_not_repo="ディレクトリ '%s' は存在しますが、Git リポジトリではありません。"
        msg_init_existing_dir="Git リポジトリとして初期化しますか？(y/n): "
        msg_aborting="操作が中止されました。"
        msg_initialized="ディレクトリ '%s' を Git リポジトリとして初期化しました。"
        msg_created_and_init="ディレクトリ '%s' を作成し、Git リポジトリとして初期化しました。"
        msg_branch_exists="ブランチ '%s' はすでに存在します。そのブランチに切り替えます。"
        msg_branch_new="新しいブランチ '%s' を作成し、切り替えました。"
        msg_existing_commit="日付 %s には %d のコミットがあります。目標は %d です。"
        msg_checking_commits="既存のコミットをチェック中..."
        msg_stats="統計情報: %d 日を処理し、合計 %d コミットを生成しました。"
        msg_max_commits="1日あたりの最大コミット数 (1以上の数字を入力): "
        msg_invalid_max_commits="無効な入力です。0より大きい整数を入力してください。"
        msg_daily_plan="日付 %s: %d コミット予定、%d が既存、%d を追加。"
        msg_commit_nth="%s の %d 番目のコミットを追加しました"
        msg_daily_done="日付 %s: 必要なコミットが完了しました。"
        ;;
    *)
        msg_repo="Enter repository name (leave empty to use current directory): "
        msg_branch="Select Git default branch: 1) master 2) main 3) Custom: "
        msg_custom_branch="Enter custom branch name: "
        msg_gpg="Enable GPG signing for commits? (y/n): "
        msg_start_date="Enter start date (YYYY-MM-DD format): "
        msg_skip="Skipping"
        msg_commit="Committed"
        msg_done="All commits have been generated!"
        msg_git_check="Checking Git configuration..."
        msg_git_fail="Git username or email is not set. Please configure Git:"
        git_tutorial="https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup"
        msg_invalid_date="Invalid date format. Please use YYYY-MM-DD format"
        msg_date_future="Start date cannot be in the future"
        msg_using_current_dir="Using current directory as repository."
        msg_existing_repo_current="Current directory is already a Git repository. Continuing with it."
        msg_init_current="Initializing Git repository in current directory."
        msg_existing_repo="Directory '%s' is already a Git repository. Continuing with it."
        msg_dir_not_repo="Directory '%s' exists but is not a Git repository."
        msg_init_existing_dir="Do you want to initialize it as a Git repository? (y/n): "
        msg_aborting="Operation aborted."
        msg_initialized="Initialized directory '%s' as a Git repository."
        msg_created_and_init="Created and initialized directory '%s' as a Git repository."
        msg_branch_exists="Branch '%s' already exists, switching to it."
        msg_branch_new="Created and switched to new branch '%s'."
        msg_existing_commit="Date %s has %d commits, target is %d."
        msg_checking_commits="Checking existing commits..."
        msg_stats="Statistics: Processed %d days, generated %d total commits."
        msg_max_commits="Maximum commits per day (enter 1 or larger number): "
        msg_invalid_max_commits="Invalid input, please enter an integer greater than 0."
        msg_daily_plan="Date %s: Planning %d commits, %d already exist, adding %d."
        msg_commit_nth="Added commit #%d for %s"
        msg_daily_done="Date %s: Completed required commits."
        ;;
esac

# Check Git configuration
echo "$msg_git_check"
check_git_config

# Ask for repository name and set it up
read -p "$msg_repo" repo_name
setup_repository "$repo_name"

# Select Git main branch
read -p "$msg_branch" branch_choice
case "$branch_choice" in
    1) branch_name="master" ;;
    2) branch_name="main" ;;
    3) read -p "$msg_custom_branch" branch_name
       [[ -z "$branch_name" ]] && branch_name="main" && echo "Using default branch: main"
       ;;
    *) branch_name="main" ;;
esac

if git show-ref --verify --quiet refs/heads/"$branch_name"; then
    printf "$msg_branch_exists\n" "$branch_name"
    git checkout "$branch_name" 2>/dev/null || git switch "$branch_name" 2>/dev/null
else
    printf "$msg_branch_new\n" "$branch_name"
    git checkout -b "$branch_name" 2>/dev/null || git switch -c "$branch_name" 2>/dev/null
fi

# Ask about GPG signing
read -p "$msg_gpg" use_gpg
commit_option="--no-gpg-sign"
[[ "$use_gpg" == "y" ]] && commit_option="-S"

# Ask for max commits per day
while true; do
    read -p "$msg_max_commits" max_commits_per_day
    if ! [[ $max_commits_per_day =~ ^[0-9]+$ ]] || [[ $max_commits_per_day -lt 1 ]]; then
        echo "$msg_invalid_max_commits"
        continue
    fi
    break
done

# Ask for start date
while true; do
    read -p "$msg_start_date" start_date
    if ! [[ $start_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$msg_invalid_date"
        continue
    fi
    current_date=$(get_current_date)
    if [[ $(compare_dates "$start_date" "$current_date") -eq 0 ]]; then
        echo "$msg_date_future"
        continue
    fi
    # Validate date is real
    get_date "$start_date" "%Y-%m-%d" >/dev/null 2>&1 || { echo "$msg_invalid_date"; continue; }
    break
done

# Create log.txt if it doesn't exist
touch log.txt

# Initialize variables
commit_date="$start_date"
total_days=0
total_commits=0

# Generate commits
echo "$msg_checking_commits..."
while [[ $(compare_dates "$commit_date" "$current_date") -eq 1 ]]; do
    total_days=$((total_days + 1))
    existing_commits=$(count_commits_for_date "$commit_date")
    target_commits=$([[ $max_commits_per_day -eq 1 ]] && echo 1 || get_random $max_commits_per_day)
    commits_to_add=$((target_commits - existing_commits))
    [[ $commits_to_add -lt 0 ]] && commits_to_add=0

    printf "$msg_daily_plan\n" "$commit_date" "$target_commits" "$existing_commits" "$commits_to_add"

    if [[ $commits_to_add -gt 0 ]]; then
        for ((i=1; i<=commits_to_add; i++)); do
            commit_number=$((existing_commits + i))
            echo "Commit date: $commit_date - #$commit_number" >> log.txt

            # Randomize time between 9:00 and 17:00
            hour=$((9 + RANDOM % 8))
            minute=$((RANDOM % 60))
            second=$((RANDOM % 60))
            time_str=$(printf "%02d:%02d:%02d" $hour $minute $second)

            export GIT_AUTHOR_DATE="$commit_date $time_str"
            export GIT_COMMITTER_DATE="$commit_date $time_str"

            git add log.txt
            git commit $commit_option -m "Commit #$commit_number on $commit_date" || { echo "Commit failed."; exit 1; }

            printf "$msg_commit_nth\n" "$commit_date" "$commit_number"
            total_commits=$((total_commits + 1))
        done
        printf "$msg_daily_done\n" "$commit_date"
    else
        printf "$msg_existing_commit\n" "$commit_date" "$existing_commits" "$target_commits"
    fi

    commit_date=$(get_date "$commit_date" "%Y-%m-%d" "+1day")
done

echo "$msg_done"
printf "$msg_stats\n" "$total_days" "$total_commits"
