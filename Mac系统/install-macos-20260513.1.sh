#!/usr/bin/env bash
set -uo pipefail

SCRIPT_VERSION="2026-05-13.1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps"
TEMPLATE_DIR="$ROOT_DIR/templates"
SKILL_DIR="$ROOT_DIR/payload/skills"
TOOL_DIR="$ROOT_DIR/payload/tools"
LOG_DIR="$HOME/Downloads/Agent-Obsidian-install-logs"
LOG_FILE="$LOG_DIR/install-macos-$(date '+%Y%m%d-%H%M%S').log"
REPORT_FILE="$LOG_DIR/delivery-checklist-$(date '+%Y%m%d-%H%M%S').txt"
WORK_ROOT="$HOME/Desktop/CodePilot"
BRIDGE_DIR="$WORK_ROOT/Bridge"
VAULT_DIR="$WORK_ROOT/Obsidian"
NODE_VERSION="24.15.0"
PYTHON_313_VERSION="3.13.13"
DOWNLOAD_FAILURES=0
MANUAL_PAGES_OPENED=0
MANUAL_ACTIONS=()
SELECTED_SOURCES=()

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

fatal() {
  local message="$1"
  local code="${2:-1}"

  echo ""
  echo "致命问题：$message"
  if declare -F write_delivery_report >/dev/null 2>&1; then
    write_delivery_report "安装中断时检测" || true
  fi
  echo "失败日志: $LOG_FILE"
  echo "交付清单: $REPORT_FILE"
  echo "请把日志和交付清单回传给交付人员。"
  exit "$code"
}

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

run() {
  echo "+ $*"
  "$@"
}

add_manual_action() {
  local name="$1"
  local url="$2"
  local reason="$3"

  MANUAL_ACTIONS+=("$name | $reason | $url")
  echo "需要人工处理: $name"
  echo "原因: $reason"
  echo "官网: $url"
}

record_selected_source() {
  local name="$1"
  local source="$2"
  local detail="${3:-}"

  SELECTED_SOURCES+=("$name | $source | $detail")
  echo "$name 下载来源: $source"
  if [ -n "$detail" ]; then
    echo "$detail"
  fi
}

open_manual_install_pages() {
  [ "$MANUAL_PAGES_OPENED" -eq 0 ] || return 0
  MANUAL_PAGES_OPENED=1

  echo ""
  echo "下载连续失败较多，自动打开官方安装页面供人工下载安装。"
  echo "脚本会继续执行后续可执行步骤，并在最后生成交付清单。"
  open "https://brew.sh/" 2>/dev/null || true
  open "https://git-scm.com/download/mac" 2>/dev/null || true
  open "https://nodejs.org/en/download" 2>/dev/null || true
  open "https://www.python.org/downloads/macos/" 2>/dev/null || true
  open "https://developer.apple.com/download/all/" 2>/dev/null || true
}

record_download_failure() {
  local label="$1"

  DOWNLOAD_FAILURES=$((DOWNLOAD_FAILURES + 1))
  echo "下载/安装失败: $label ($DOWNLOAD_FAILURES/5)"
  if [ "$DOWNLOAD_FAILURES" -ge 5 ]; then
    open_manual_install_pages
  fi
}

run_with_retries() {
  local label="$1"
  local max_attempts="${2:-5}"
  shift 2
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    echo "尝试安装 $label ($attempt/$max_attempts)"
    if "$@"; then
      return 0
    fi
    record_download_failure "$label 第 $attempt 次"
    attempt=$((attempt + 1))
    sleep 3
  done

  return 1
}

prepend_path_once() {
  local entry="$1"

  [ -d "$entry" ] || return 0
  case ":$PATH:" in
    *":$entry:"*) ;;
    *) export PATH="$entry:$PATH" ;;
  esac
}

refresh_shell_paths() {
  prepend_path_once "$HOME/.local/bin"
  prepend_path_once "$HOME/Library/Python/3.13/bin"
  prepend_path_once "$HOME/Library/Python/3.12/bin"
  prepend_path_once "$HOME/Library/Python/3.11/bin"
  prepend_path_once "/usr/local/bin"
  prepend_path_once "/opt/homebrew/bin"
  prepend_path_once "/Library/Frameworks/Python.framework/Versions/3.13/bin"
  hash -r 2>/dev/null || true
}

remove_agent_path_block() {
  local profile="$1"
  local tmp

  [ -f "$profile" ] || return 0
  tmp="$(mktemp)"
  awk '
    /# BEGIN AGENT OBSIDIAN PATHS/ { skip=1; next }
    /# END AGENT OBSIDIAN PATHS/ { skip=0; next }
    !skip { print }
  ' "$profile" > "$tmp"
  mv "$tmp" "$profile"
}

persist_agent_paths() {
  local profile

  for profile in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    touch "$profile" 2>/dev/null || continue
    remove_agent_path_block "$profile"
    {
      echo ""
      echo "# BEGIN AGENT OBSIDIAN PATHS"
      echo 'export PATH="$HOME/.local/bin:$HOME/Library/Python/3.13/bin:$HOME/Library/Python/3.12/bin:$HOME/Library/Python/3.11/bin:/usr/local/bin:/opt/homebrew/bin:/Library/Frameworks/Python.framework/Versions/3.13/bin:$PATH"'
      echo "# END AGENT OBSIDIAN PATHS"
    } >> "$profile"
  done
}

ensure_user_npm_prefix() {
  refresh_shell_paths
  mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
  persist_agent_paths

  if command -v npm >/dev/null 2>&1; then
    npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true
    npm config set fund false >/dev/null 2>&1 || true
    npm config set audit false >/dev/null 2>&1 || true
    refresh_shell_paths
    echo "npm 全局安装目录: $(npm config get prefix 2>/dev/null || echo "$HOME/.local")"
    echo "npm 全局命令目录: $HOME/.local/bin"
  fi
}

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then
    echo /opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    echo /usr/local/bin/brew
  fi
}

component_line() {
  local name="$1"
  local check_cmd="$2"
  local version_cmd="$3"
  local status version
  local check_status
  local had_errexit=0

  case "$-" in
    *e*) had_errexit=1 ;;
  esac
  set +e

  eval "$check_cmd" >/dev/null 2>&1
  check_status=$?

  if [ "$check_status" -eq 0 ]; then
    status="已安装"
    version="$(eval "$version_cmd" 2>/dev/null | head -n 1)"
    [ -n "$version" ] || version="可用"
  else
    status="未安装/未配置"
    version="-"
  fi

  printf '%-18s %-14s %s\n' "$name" "$status" "$version"
  if [ "$had_errexit" -eq 1 ]; then
    set -e
  fi
  return 0
}

print_component_status() {
  local title="$1"

  refresh_shell_paths

  echo ""
  echo "============================================================"
  echo "  $title"
  echo "============================================================"
  component_line "Apple CLT" "xcode-select -p" "xcode-select -p" || true
  component_line "Homebrew" "find_brew" 'brew --version' || true
  component_line "Git" "command -v git" "git --version" || true
  component_line "Node.js" "command -v node" "node --version" || true
  component_line "npm" "command -v npm" "npm --version" || true
  component_line "Python 3.13" "command -v python3.13" "python3.13 --version" || true
  component_line "Python 3" "command -v python3" "python3 --version" || true
  component_line "MarkItDown" "command -v markitdown" "markitdown --version" || true
  component_line "yt-dlp" "command -v yt-dlp" "yt-dlp --version" || true
  component_line "FFmpeg" "command -v ffmpeg" "ffmpeg -version" || true
  component_line "Claude Code CLI" "command -v claude" "claude --version" || true
  component_line "Lark CLI" "command -v lark-cli" "lark-cli --version" || true
  component_line "HyperFrames CLI" "command -v hyperframes" "hyperframes --version" || true
  component_line "企业微信 CLI" "command -v wecom-cli" "wecom-cli --version" || true
  component_line "CodePilot.app" "test -d /Applications/CodePilot.app" "echo /Applications/CodePilot.app" || true
  component_line "Obsidian.app" "test -d /Applications/Obsidian.app" "echo /Applications/Obsidian.app" || true
  component_line "Obsidian CLI" "command -v obsidian" "obsidian version" || true
  return 0
}

write_delivery_report() {
  local title="${1:-安装完成后检测}"

  {
    echo "Agent-Obsidian-install 交付清单"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "日志文件: $LOG_FILE"
    echo ""
    print_component_status "$title" || true
    echo ""
    echo "工作目录:"
    echo "  Bridge: $BRIDGE_DIR"
    echo "  Obsidian 知识库: $VAULT_DIR"
    echo ""
    echo "人工处理项:"
    if [ "${#MANUAL_ACTIONS[@]}" -eq 0 ]; then
      echo "  无"
    else
      local item
      for item in "${MANUAL_ACTIONS[@]}"; do
        echo "  - $item"
      done
    fi
    echo ""
    echo "下载来源选择:"
    if [ "${#SELECTED_SOURCES[@]}" -eq 0 ]; then
      echo "  无"
    else
      local source_item
      for source_item in "${SELECTED_SOURCES[@]}"; do
        echo "  - $source_item"
      done
    fi
  } > "$REPORT_FILE"

  echo ""
  echo "交付清单已生成: $REPORT_FILE"
}

ensure_admin_and_tty() {
  if ! id -Gn "$USER" | tr ' ' '\n' | grep -qx admin; then
    echo "当前账号不是管理员账号：$USER"
    echo "请切换到 Mac 管理员账号后重新运行安装命令。"
    fatal "当前账号不是管理员账号，无法安装系统级组件" 1
  fi

  if [ ! -r /dev/tty ]; then
    echo "当前终端没有可交互输入，无法输入管理员密码。"
    echo "请打开 macOS 自带“终端”，再粘贴使用说明里的完整命令。"
    fatal "当前终端没有可交互输入，无法输入管理员密码" 1
  fi

  log "确认管理员权限"
  echo "如果系统要求输入密码，请输入这台 Mac 的开机登录密码。输入时屏幕不会显示字符，这是正常现象。"
  if ! sudo -v </dev/tty; then
    fatal "无法获取管理员权限，安装无法继续" 1
  fi
}

ensure_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi

  log "安装 Apple 命令行工具"
  echo "系统会弹出 Apple 命令行工具安装窗口，请点击安装。"
  echo "安装过程中请不要关闭终端。本脚本会等待安装完成，然后自动继续。"
  echo "如果你取消了系统安装窗口，请按 Ctrl+C 停止本脚本，之后重新运行使用说明里的安装命令。"
  xcode-select --install 2>/dev/null || true

  local waited=0
  local interval=10
  local timeout=3600

  while [ "$waited" -lt "$timeout" ]; do
    if xcode-select -p >/dev/null 2>&1; then
      echo "Apple 命令行工具已安装，继续后续安装流程。"
      return
    fi

    if [ $((waited % 60)) -eq 0 ]; then
      echo "正在等待 Apple 命令行工具安装完成... 已等待 $((waited / 60)) 分钟"
    fi

    sleep "$interval"
    waited=$((waited + interval))
  done

  echo "等待 Apple 命令行工具安装超过 60 分钟。"
  echo "如果系统安装窗口已经完成，请重新运行使用说明里的安装命令。"
  echo "本次日志: $LOG_FILE"
  add_manual_action "Apple 命令行工具" "https://developer.apple.com/download/all/" "等待系统安装超过 60 分钟，请人工安装 Command Line Tools 后重跑脚本"
  return 0
}

measure_url_ms() {
  local url="$1"
  local result http time

  result="$(curl -L -I --connect-timeout 4 --max-time 8 -o /dev/null -s -w '%{http_code} %{time_total}' "$url" || true)"
  http="${result%% *}"
  time="${result##* }"

  case "$http" in
    2*|3*|401) ;;
    *)
      result="$(curl -L --range 0-0 --connect-timeout 4 --max-time 8 -o /dev/null -s -w '%{http_code} %{time_total}' "$url" || true)"
      http="${result%% *}"
      time="${result##* }"
      ;;
  esac

  case "$http" in
    2*|3*|401)
      awk "BEGIN { printf \"%d\", $time * 1000 }"
      ;;
    *)
      echo 999999
      ;;
  esac
}

max_ms() {
  local a="$1"
  local b="$2"
  if [ "$a" -ge "$b" ]; then
    echo "$a"
  else
    echo "$b"
  fi
}

brew_formula_api_url() {
  local source="$1"
  local formula="$2"

  case "$source" in
    official) echo "https://formulae.brew.sh/api/formula/${formula}.json" ;;
    aliyun) echo "https://mirrors.aliyun.com/homebrew/homebrew-bottles/api/formula/${formula}.json" ;;
    ustc) echo "https://mirrors.ustc.edu.cn/homebrew-bottles/api/formula/${formula}.json" ;;
    tuna) echo "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api/formula/${formula}.json" ;;
    *) echo "" ;;
  esac
}

brew_bottle_probe_url() {
  local source="$1"

  case "$source" in
    official) echo "https://ghcr.io/v2/" ;;
    aliyun) echo "https://mirrors.aliyun.com/homebrew/homebrew-bottles/" ;;
    ustc) echo "https://mirrors.ustc.edu.cn/homebrew-bottles/" ;;
    tuna) echo "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/" ;;
    *) echo "" ;;
  esac
}

measure_brew_formula_source_ms() {
  local source="$1"
  local formula="$2"
  local api_url bottle_url api_ms bottle_ms

  api_url="$(brew_formula_api_url "$source" "$formula")"
  bottle_url="$(brew_bottle_probe_url "$source")"
  api_ms="$(measure_url_ms "$api_url")"
  bottle_ms="$(measure_url_ms "$bottle_url")"
  max_ms "$api_ms" "$bottle_ms"
}

choose_fastest_source_from_ms() {
  local official_ms="$1"
  local aliyun_ms="$2"
  local ustc_ms="$3"
  local tuna_ms="$4"
  local fastest="official"
  local fastest_ms="$official_ms"

  if [ "$aliyun_ms" -lt "$fastest_ms" ]; then
    fastest="aliyun"
    fastest_ms="$aliyun_ms"
  fi
  if [ "$ustc_ms" -lt "$fastest_ms" ]; then
    fastest="ustc"
    fastest_ms="$ustc_ms"
  fi
  if [ "$tuna_ms" -lt "$fastest_ms" ]; then
    fastest="tuna"
    fastest_ms="$tuna_ms"
  fi

  echo "$fastest"
}

choose_fastest_url() {
  local label="$1"
  shift
  local best_name=""
  local best_url=""
  local best_ms=999999
  local pair name url ms

  log "测速 $label 下载路径"
  echo "正在测速 $label 可用下载地址..."

  for pair in "$@"; do
    name="${pair%%|*}"
    url="${pair#*|}"
    ms="$(measure_url_ms "$url")"
    echo "$label $name 测速: ${ms}ms"
    if [ "$ms" -lt "$best_ms" ]; then
      best_name="$name"
      best_url="$url"
      best_ms="$ms"
    fi
  done

  AGENT_SELECTED_DOWNLOAD_NAME="$best_name"
  AGENT_SELECTED_DOWNLOAD_URL="$best_url"
  AGENT_SELECTED_DOWNLOAD_MS="$best_ms"
  record_selected_source "$label" "$best_name" "测速最快: ${best_ms}ms；URL: $best_url"
}

remove_agent_homebrew_profile_block() {
  local profile="$HOME/.zprofile"
  local tmp

  [ -f "$profile" ] || return 0
  tmp="$(mktemp)"
  awk '
    /# BEGIN AGENT OBSIDIAN HOMEBREW MIRRORS/ { skip=1; next }
    /# END AGENT OBSIDIAN HOMEBREW MIRRORS/ { skip=0; next }
    !skip { print }
  ' "$profile" > "$tmp"
  mv "$tmp" "$profile"
}

set_homebrew_source() {
  local source="$1"

  unset HOMEBREW_BREW_GIT_REMOTE
  unset HOMEBREW_CORE_GIT_REMOTE
  unset HOMEBREW_CASK_GIT_REMOTE
  unset HOMEBREW_API_DOMAIN
  unset HOMEBREW_BOTTLE_DOMAIN
  export HOMEBREW_NO_ANALYTICS=1

  case "$source" in
    aliyun)
      export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.aliyun.com/homebrew/brew.git"
      export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.aliyun.com/homebrew/homebrew-core.git"
      export HOMEBREW_CASK_GIT_REMOTE="https://mirrors.aliyun.com/homebrew/homebrew-cask.git"
      export HOMEBREW_API_DOMAIN="https://mirrors.aliyun.com/homebrew/homebrew-bottles/api"
      export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.aliyun.com/homebrew/homebrew-bottles"
      AGENT_HOMEBREW_CN_CHOICE=2
      ;;
    tuna)
      export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
      export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
      export HOMEBREW_CASK_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git"
      export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
      export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
      AGENT_HOMEBREW_CN_CHOICE=3
      ;;
    ustc)
      export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
      export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
      export HOMEBREW_CASK_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-cask.git"
      export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
      export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
      AGENT_HOMEBREW_CN_CHOICE=1
      ;;
    official)
      AGENT_HOMEBREW_CN_CHOICE=2
      ;;
    *)
      echo "未知 Homebrew 下载路径: $source"
      return 1
      ;;
  esac

  remove_agent_homebrew_profile_block
  if [ "$source" != "official" ]; then
    {
      echo ""
      echo "# BEGIN AGENT OBSIDIAN HOMEBREW MIRRORS"
      echo "export HOMEBREW_BREW_GIT_REMOTE=\"$HOMEBREW_BREW_GIT_REMOTE\""
      echo "export HOMEBREW_CORE_GIT_REMOTE=\"$HOMEBREW_CORE_GIT_REMOTE\""
      echo "export HOMEBREW_CASK_GIT_REMOTE=\"$HOMEBREW_CASK_GIT_REMOTE\""
      echo "export HOMEBREW_API_DOMAIN=\"$HOMEBREW_API_DOMAIN\""
      echo "export HOMEBREW_BOTTLE_DOMAIN=\"$HOMEBREW_BOTTLE_DOMAIN\""
      echo 'export HOMEBREW_NO_ANALYTICS=1'
      echo "# END AGENT OBSIDIAN HOMEBREW MIRRORS"
    } >> "$HOME/.zprofile"
  fi

  AGENT_HOMEBREW_SELECTED_SOURCE="$source"
  return 0
}

choose_homebrew_source() {
  local official_raw official_git official_ghcr official_ms
  local aliyun_ms ustc_ms tuna_ms fastest_source fastest_mirror fastest_mirror_ms selected_source
  local forced="${AGENT_HOMEBREW_SOURCE:-auto}"
  local official_fast_ms="${AGENT_HOMEBREW_OFFICIAL_FAST_MS:-2500}"
  local prefer_official="${AGENT_HOMEBREW_PREFER_OFFICIAL:-0}"

  if [ "$forced" != "auto" ]; then
    AGENT_HOMEBREW_FALLBACK_SOURCE="aliyun"
    set_homebrew_source "$forced" || set_homebrew_source "official"
    record_selected_source "Homebrew" "$AGENT_HOMEBREW_SELECTED_SOURCE" "手动指定"
    return
  fi

  log "测速 Homebrew 下载路径"
  echo "正在测速 Homebrew 官方源和国内镜像源，只下载很小的探测数据..."

  official_raw="$(measure_url_ms "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")"
  official_git="$(measure_url_ms "https://github.com/Homebrew/brew")"
  official_ghcr="$(measure_url_ms "https://ghcr.io/v2/")"
  official_ms="$(max_ms "$(max_ms "$official_raw" "$official_git")" "$official_ghcr")"

  aliyun_ms="$(measure_url_ms "https://mirrors.aliyun.com/homebrew/brew.git/info/refs?service=git-upload-pack")"
  ustc_ms="$(measure_url_ms "https://mirrors.ustc.edu.cn/brew.git/info/refs?service=git-upload-pack")"
  tuna_ms="$(measure_url_ms "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git/info/refs?service=git-upload-pack")"

  fastest_mirror="aliyun"
  fastest_mirror_ms="$aliyun_ms"
  if [ "$ustc_ms" -lt "$fastest_mirror_ms" ]; then
    fastest_mirror="ustc"
    fastest_mirror_ms="$ustc_ms"
  fi
  if [ "$tuna_ms" -lt "$fastest_mirror_ms" ]; then
    fastest_mirror="tuna"
    fastest_mirror_ms="$tuna_ms"
  fi

  fastest_source="$(choose_fastest_source_from_ms "$official_ms" "$aliyun_ms" "$ustc_ms" "$tuna_ms")"

  echo "官方源测速: ${official_ms}ms"
  echo "阿里云测速: ${aliyun_ms}ms"
  echo "中科大测速: ${ustc_ms}ms"
  echo "清华源测速: ${tuna_ms}ms"

  if [ "$prefer_official" = "1" ] && [ "$official_ms" -le "$official_fast_ms" ]; then
    selected_source="official"
  else
    selected_source="$fastest_source"
  fi

  if [ "$selected_source" = "official" ]; then
    AGENT_HOMEBREW_FALLBACK_SOURCE="$fastest_mirror"
  else
    AGENT_HOMEBREW_FALLBACK_SOURCE="official"
  fi

  set_homebrew_source "$selected_source" || set_homebrew_source "official"
  record_selected_source "Homebrew" "$AGENT_HOMEBREW_SELECTED_SOURCE" "测速: 官方 ${official_ms}ms / 阿里云 ${aliyun_ms}ms / 中科大 ${ustc_ms}ms / 清华 ${tuna_ms}ms；备用: ${AGENT_HOMEBREW_FALLBACK_SOURCE}"

  if [ "$AGENT_HOMEBREW_SELECTED_SOURCE" != "official" ]; then
    echo "Homebrew Git 镜像: $HOMEBREW_BREW_GIT_REMOTE"
    echo "Homebrew Bottle 镜像: $HOMEBREW_BOTTLE_DOMAIN"
  fi
}

configure_china_mirrors() {
  if [ -z "${AGENT_HOMEBREW_SELECTED_SOURCE:-}" ]; then
    choose_homebrew_source
  else
    set_homebrew_source "$AGENT_HOMEBREW_SELECTED_SOURCE" || true
  fi
}

choose_brew_formula_source() {
  local label="$1"
  local formula="$2"
  local official_ms aliyun_ms ustc_ms tuna_ms selected_source fallback_source fastest_mirror fastest_mirror_ms

  log "测速 $label 下载路径"
  echo "正在测速 $label 的 Homebrew API 和 Bottle 下载源..."

  official_ms="$(measure_brew_formula_source_ms "official" "$formula")"
  aliyun_ms="$(measure_brew_formula_source_ms "aliyun" "$formula")"
  ustc_ms="$(measure_brew_formula_source_ms "ustc" "$formula")"
  tuna_ms="$(measure_brew_formula_source_ms "tuna" "$formula")"

  fastest_mirror="aliyun"
  fastest_mirror_ms="$aliyun_ms"
  if [ "$ustc_ms" -lt "$fastest_mirror_ms" ]; then
    fastest_mirror="ustc"
    fastest_mirror_ms="$ustc_ms"
  fi
  if [ "$tuna_ms" -lt "$fastest_mirror_ms" ]; then
    fastest_mirror="tuna"
    fastest_mirror_ms="$tuna_ms"
  fi

  selected_source="$(choose_fastest_source_from_ms "$official_ms" "$aliyun_ms" "$ustc_ms" "$tuna_ms")"
  if [ "$selected_source" = "official" ]; then
    fallback_source="$fastest_mirror"
  else
    fallback_source="official"
  fi

  echo "$label 官方源测速: ${official_ms}ms"
  echo "$label 阿里云测速: ${aliyun_ms}ms"
  echo "$label 中科大测速: ${ustc_ms}ms"
  echo "$label 清华源测速: ${tuna_ms}ms"

  set_homebrew_source "$selected_source" || set_homebrew_source "official"
  AGENT_BREW_FORMULA_SELECTED_SOURCE="$AGENT_HOMEBREW_SELECTED_SOURCE"
  AGENT_BREW_FORMULA_FALLBACK_SOURCE="$fallback_source"
  record_selected_source "$label" "Homebrew/$AGENT_BREW_FORMULA_SELECTED_SOURCE" "测速: 官方 ${official_ms}ms / 阿里云 ${aliyun_ms}ms / 中科大 ${ustc_ms}ms / 清华 ${tuna_ms}ms；备用: $fallback_source"
}

brew_install_formula() {
  local label="$1"
  local formula="$2"
  local check_cmd="$3"
  local manual_url="$4"
  local fallback_source

  if eval "$check_cmd" >/dev/null 2>&1; then
    echo "$label 已安装，跳过。"
    return 0
  fi

  choose_brew_formula_source "$label" "$formula"
  fallback_source="${AGENT_BREW_FORMULA_FALLBACK_SOURCE:-official}"

  if run_with_retries "$label" 3 brew install "$formula"; then
    return 0
  fi

  echo "$label 主下载路径失败，切换备用下载路径: $fallback_source"
  set_homebrew_source "$fallback_source" || true
  record_selected_source "$label 备用" "Homebrew/${AGENT_HOMEBREW_SELECTED_SOURCE:-$fallback_source}" "主路径失败后切换备用路径"

  if run_with_retries "$label 备用路径" 2 brew install "$formula"; then
    return 0
  fi

  add_manual_action "$label" "$manual_url" "$label 自动安装失败，请人工下载安装"
  return 1
}

node_download_arch() {
  case "$(uname -m)" in
    arm64) echo "arm64" ;;
    x86_64) echo "x64" ;;
    *) echo "unknown" ;;
  esac
}

install_node_direct() {
  local arch archive_name url_official url_npmmirror download_url source_name tmp_dir archive_path extracted_dir install_dir

  refresh_shell_paths
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node.js/npm 已安装，跳过。"
    node --version || true
    npm --version || true
    return 0
  fi

  arch="$(node_download_arch)"
  if [ "$arch" = "unknown" ]; then
    add_manual_action "Node.js" "https://nodejs.org/en/download" "无法识别当前 Mac 架构，请人工安装 Node.js"
    return 1
  fi

  archive_name="node-v${NODE_VERSION}-darwin-${arch}.tar.gz"
  url_official="https://nodejs.org/dist/v${NODE_VERSION}/${archive_name}"
  url_npmmirror="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/${archive_name}"

  choose_fastest_url "Node.js" \
    "npmmirror|$url_npmmirror" \
    "Node官方源|$url_official"

  download_url="$AGENT_SELECTED_DOWNLOAD_URL"
  source_name="$AGENT_SELECTED_DOWNLOAD_NAME"
  tmp_dir="$(mktemp -d "/tmp/agent-node.XXXXXX")"
  archive_path="$tmp_dir/$archive_name"

  echo "下载 Node.js $NODE_VERSION: $source_name"
  if ! curl -fL --connect-timeout 15 --max-time 900 --progress-bar "$download_url" -o "$archive_path"; then
    record_download_failure "Node.js $source_name"
    if [ "$download_url" = "$url_npmmirror" ]; then
      download_url="$url_official"
      source_name="Node官方源"
    else
      download_url="$url_npmmirror"
      source_name="npmmirror"
    fi
    record_selected_source "Node.js 备用" "$source_name" "主下载地址失败后切换备用地址: $download_url"
    if ! curl -fL --connect-timeout 15 --max-time 900 --progress-bar "$download_url" -o "$archive_path"; then
      rm -rf "$tmp_dir"
      add_manual_action "Node.js" "https://nodejs.org/en/download" "Node.js 自动下载失败，请人工下载安装"
      return 1
    fi
  fi

  tar -xzf "$archive_path" -C "$tmp_dir"
  extracted_dir="$tmp_dir/node-v${NODE_VERSION}-darwin-${arch}"
  install_dir="/usr/local/lib/nodejs/node-v${NODE_VERSION}-darwin-${arch}"

  if [ ! -d "$extracted_dir" ]; then
    rm -rf "$tmp_dir"
    add_manual_action "Node.js" "https://nodejs.org/en/download" "Node.js 压缩包解压失败，请人工下载安装"
    return 1
  fi

  sudo mkdir -p /usr/local/lib/nodejs /usr/local/bin
  sudo rm -rf "$install_dir"
  sudo ditto "$extracted_dir" "$install_dir"
  sudo ln -sf "$install_dir/bin/node" /usr/local/bin/node
  sudo ln -sf "$install_dir/bin/npm" /usr/local/bin/npm
  sudo ln -sf "$install_dir/bin/npx" /usr/local/bin/npx
  rm -rf "$tmp_dir"

  refresh_shell_paths
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    node --version || true
    npm --version || true
    return 0
  fi

  add_manual_action "Node.js" "https://nodejs.org/en/download" "Node.js 已解压但命令不可用，请人工检查 PATH"
  return 1
}

install_python313_direct() {
  local pkg_name url_official url_huawei url_tuna download_url source_name tmp_dir pkg_path

  refresh_shell_paths
  if command -v python3.13 >/dev/null 2>&1; then
    echo "Python 3.13 已安装，跳过。"
    python3.13 --version || true
    return 0
  fi

  pkg_name="python-${PYTHON_313_VERSION}-macos11.pkg"
  url_official="https://www.python.org/ftp/python/${PYTHON_313_VERSION}/${pkg_name}"
  url_huawei="https://repo.huaweicloud.com/python/${PYTHON_313_VERSION}/${pkg_name}"
  url_tuna="https://mirrors.tuna.tsinghua.edu.cn/python/${PYTHON_313_VERSION}/${pkg_name}"

  choose_fastest_url "Python 3.13" \
    "华为云镜像|$url_huawei" \
    "清华镜像|$url_tuna" \
    "Python官方源|$url_official"

  download_url="$AGENT_SELECTED_DOWNLOAD_URL"
  source_name="$AGENT_SELECTED_DOWNLOAD_NAME"
  tmp_dir="$(mktemp -d "/tmp/agent-python.XXXXXX")"
  pkg_path="$tmp_dir/$pkg_name"

  echo "下载 Python $PYTHON_313_VERSION: $source_name"
  if ! curl -fL --connect-timeout 15 --max-time 900 --progress-bar "$download_url" -o "$pkg_path"; then
    record_download_failure "Python 3.13 $source_name"
    download_url="$url_official"
    source_name="Python官方源"
    record_selected_source "Python 3.13 备用" "$source_name" "主下载地址失败后切换备用地址: $download_url"
    if ! curl -fL --connect-timeout 15 --max-time 900 --progress-bar "$download_url" -o "$pkg_path"; then
      rm -rf "$tmp_dir"
      add_manual_action "Python 3.13" "https://www.python.org/downloads/macos/" "Python 3.13 自动下载失败，请人工下载安装"
      return 1
    fi
  fi

  if ! sudo installer -pkg "$pkg_path" -target /; then
    rm -rf "$tmp_dir"
    add_manual_action "Python 3.13" "https://www.python.org/downloads/macos/" "Python 3.13 pkg 安装失败，请人工下载安装"
    return 1
  fi

  rm -rf "$tmp_dir"
  sudo mkdir -p /usr/local/bin
  if [ -x "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13" ]; then
    sudo ln -sf "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13" /usr/local/bin/python3.13
  fi
  if [ -x "/Library/Frameworks/Python.framework/Versions/3.13/bin/pip3.13" ]; then
    sudo ln -sf "/Library/Frameworks/Python.framework/Versions/3.13/bin/pip3.13" /usr/local/bin/pip3.13
  fi

  refresh_shell_paths
  if command -v python3.13 >/dev/null 2>&1; then
    python3.13 --version || true
    return 0
  fi

  add_manual_action "Python 3.13" "https://www.python.org/downloads/macos/" "Python 3.13 已安装但命令不可用，请人工检查 PATH"
  return 1
}

python_for_pip() {
  refresh_shell_paths
  if command -v python3.13 >/dev/null 2>&1; then
    command -v python3.13
  elif command -v python3 >/dev/null 2>&1; then
    command -v python3
  else
    return 1
  fi
}

choose_pip_index() {
  local label="$1"
  local probe_package="$2"
  local official_url="https://pypi.org/simple/${probe_package}/"
  local tuna_url="https://pypi.tuna.tsinghua.edu.cn/simple/${probe_package}/"
  local aliyun_url="https://mirrors.aliyun.com/pypi/simple/${probe_package}/"
  local huawei_url="https://repo.huaweicloud.com/repository/pypi/simple/${probe_package}/"
  local official_ms tuna_ms aliyun_ms huawei_ms fastest fastest_ms fallback

  log "测速 $label Python 包下载路径"
  official_ms="$(measure_url_ms "$official_url")"
  tuna_ms="$(measure_url_ms "$tuna_url")"
  aliyun_ms="$(measure_url_ms "$aliyun_url")"
  huawei_ms="$(measure_url_ms "$huawei_url")"

  fastest="pypi官方源"
  fastest_ms="$official_ms"
  AGENT_PIP_INDEX_URL="https://pypi.org/simple"
  fallback="清华 PyPI 镜像"
  AGENT_PIP_FALLBACK_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"

  if [ "$tuna_ms" -lt "$fastest_ms" ]; then
    fastest="清华 PyPI 镜像"
    fastest_ms="$tuna_ms"
    AGENT_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
    fallback="pypi官方源"
    AGENT_PIP_FALLBACK_INDEX_URL="https://pypi.org/simple"
  fi
  if [ "$aliyun_ms" -lt "$fastest_ms" ]; then
    fastest="阿里云 PyPI 镜像"
    fastest_ms="$aliyun_ms"
    AGENT_PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple"
    fallback="pypi官方源"
    AGENT_PIP_FALLBACK_INDEX_URL="https://pypi.org/simple"
  fi
  if [ "$huawei_ms" -lt "$fastest_ms" ]; then
    fastest="华为云 PyPI 镜像"
    fastest_ms="$huawei_ms"
    AGENT_PIP_INDEX_URL="https://repo.huaweicloud.com/repository/pypi/simple"
    fallback="pypi官方源"
    AGENT_PIP_FALLBACK_INDEX_URL="https://pypi.org/simple"
  fi

  echo "$label PyPI 官方源测速: ${official_ms}ms"
  echo "$label 清华 PyPI 镜像测速: ${tuna_ms}ms"
  echo "$label 阿里云 PyPI 镜像测速: ${aliyun_ms}ms"
  echo "$label 华为云 PyPI 镜像测速: ${huawei_ms}ms"
  record_selected_source "$label" "$fastest" "测速最快: ${fastest_ms}ms；备用: $fallback"
}

ensure_python_pip() {
  local py="$1"

  if "$py" -m pip --version >/dev/null 2>&1; then
    return 0
  fi

  "$py" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "$py" -m pip --version >/dev/null 2>&1
}

pip_install_user() {
  local package_spec="$1"
  local probe_package="$2"
  local label="$3"
  local check_cmd="$4"
  local manual_url="$5"
  local py

  refresh_shell_paths
  if eval "$check_cmd" >/dev/null 2>&1; then
    echo "$label 已安装，跳过。"
    return 0
  fi

  py="$(python_for_pip || true)"
  if [ -z "${py:-}" ]; then
    add_manual_action "$label" "$manual_url" "未检测到可用 Python，无法自动安装 $label"
    return 0
  fi

  if ! ensure_python_pip "$py"; then
    add_manual_action "$label" "$manual_url" "Python pip 不可用，无法自动安装 $label"
    return 0
  fi

  choose_pip_index "$label" "$probe_package"
  if run_with_retries "$label" 3 "$py" -m pip install --user --upgrade "$package_spec" -i "$AGENT_PIP_INDEX_URL"; then
    refresh_shell_paths
    if eval "$check_cmd" >/dev/null 2>&1; then
      echo "$label 安装完成。"
      return 0
    fi
  fi

  record_selected_source "$label 备用" "$AGENT_PIP_FALLBACK_INDEX_URL" "主路径失败或命令不可用后切换备用 PyPI 源"
  if run_with_retries "$label 备用路径" 2 "$py" -m pip install --user --upgrade "$package_spec" -i "$AGENT_PIP_FALLBACK_INDEX_URL"; then
    refresh_shell_paths
    if eval "$check_cmd" >/dev/null 2>&1; then
      echo "$label 安装完成。"
      return 0
    fi
  fi

  add_manual_action "$label" "$manual_url" "$label 自动安装失败，请人工安装"
  return 0
}

install_python_cli_tools() {
  log "检查并安装 Python CLI 工具"
  pip_install_user "markitdown[all]" "markitdown" "MarkItDown" "command -v markitdown" "https://github.com/microsoft/markitdown" || true
  pip_install_user "yt-dlp" "yt-dlp" "yt-dlp" "command -v yt-dlp" "https://github.com/yt-dlp/yt-dlp" || true
  pip_install_user "reportlab" "reportlab" "any2pdf 依赖 reportlab" "python_for_pip >/dev/null 2>&1 && \"$(python_for_pip)\" -c 'import reportlab'" "https://pypi.org/project/reportlab/" || true
}

find_cli_candidate() {
  local binary_name="$1"
  local npm_prefix npm_root
  local candidate

  refresh_shell_paths
  if command -v "$binary_name" >/dev/null 2>&1; then
    command -v "$binary_name"
    return 0
  fi

  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  npm_root="$(npm root -g 2>/dev/null || true)"

  for candidate in \
    "$HOME/.local/bin/$binary_name" \
    "${npm_prefix:+$npm_prefix/bin/$binary_name}" \
    "/usr/local/bin/$binary_name" \
    "/opt/homebrew/bin/$binary_name" \
    "${npm_root:+$npm_root/.bin/$binary_name}"; do
    [ -n "$candidate" ] || continue
    if [ -e "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

verify_or_link_cli_binary() {
  local label="$1"
  local binary_name="$2"
  local candidate

  refresh_shell_paths
  if command -v "$binary_name" >/dev/null 2>&1; then
    echo "$label 命令可用: $(command -v "$binary_name")"
    "$binary_name" --version || "$binary_name" version || true
    return 0
  fi

  candidate="$(find_cli_candidate "$binary_name" || true)"
  if [ -n "$candidate" ]; then
    chmod +x "$candidate" 2>/dev/null || true
    mkdir -p "$HOME/.local/bin"
    ln -sf "$candidate" "$HOME/.local/bin/$binary_name" 2>/dev/null || true
    refresh_shell_paths
    if command -v "$binary_name" >/dev/null 2>&1; then
      echo "$label 命令已修复: $(command -v "$binary_name")"
      "$binary_name" --version || "$binary_name" version || true
      return 0
    fi
  fi

  echo "$label 安装后仍未找到命令: $binary_name"
  echo "当前 PATH: $PATH"
  if command -v npm >/dev/null 2>&1; then
    echo "npm prefix: $(npm config get prefix 2>/dev/null || true)"
    echo "npm root: $(npm root -g 2>/dev/null || true)"
  fi
  return 1
}

run_homebrew_cn_installer() {
  local installer="$1"
  local source="$2"
  local choice="${AGENT_HOMEBREW_CN_CHOICE:-2}"

  set_homebrew_source "$source" || return 1
  echo "切换到国内镜像安装器，选择源: $source"
  if ! curl -fsSL https://brew-cn.mintimate.cn/install -o "$installer"; then
    return 1
  fi
  printf '%s\n\n' "$choice" | /bin/bash "$installer"
}

install_homebrew() {
  local installer
  local selected="${AGENT_HOMEBREW_SELECTED_SOURCE:-official}"
  local fallback="${AGENT_HOMEBREW_FALLBACK_SOURCE:-aliyun}"
  local attempt=1

  installer="$(mktemp /tmp/homebrew-install.XXXXXX.sh)"

  while [ "$attempt" -le 5 ]; do
    if [ "$selected" = "official" ]; then
      echo "优先使用 Homebrew 官方安装器 ($attempt/5)。若失败，将自动切换到国内镜像。"
      if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer" && /bin/bash "$installer" </dev/tty; then
        rm -f "$installer"
        return 0
      fi
      record_download_failure "Homebrew 官方安装器"

      echo "官方 Homebrew 安装失败或下载超时，自动切换到国内最快镜像。"
      if run_homebrew_cn_installer "$installer" "$fallback"; then
        rm -f "$installer"
        return 0
      fi
      record_download_failure "Homebrew 国内镜像安装器"
    else
      if run_homebrew_cn_installer "$installer" "$selected"; then
        rm -f "$installer"
        return 0
      fi
      record_download_failure "Homebrew 国内镜像安装器"

      echo "国内镜像安装失败，尝试 Homebrew 官方安装器。"
      set_homebrew_source "official"
      if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer" && /bin/bash "$installer" </dev/tty; then
        rm -f "$installer"
        return 0
      fi
      record_download_failure "Homebrew 官方安装器"
    fi
    attempt=$((attempt + 1))
    sleep 3
  done

  rm -f "$installer"
  open_manual_install_pages
  add_manual_action "Homebrew" "https://brew.sh/" "自动安装连续失败，请人工下载安装后重新运行本脚本"
  return 1
}

ensure_homebrew_and_node() {
  local brew_bin

  refresh_shell_paths
  brew_bin="$(find_brew || true)"
  if [ -z "${brew_bin:-}" ]; then
    log "安装 Homebrew"
    install_homebrew || true
    brew_bin="$(find_brew || true)"
  fi

  if [ -n "${brew_bin:-}" ]; then
    eval "$("$brew_bin" shellenv)"
    configure_china_mirrors
  else
    echo "未找到 Homebrew。Node.js 和 Python 将改走独立下载安装，不因此中断。"
    add_manual_action "Homebrew" "https://brew.sh/" "未检测到 Homebrew，已跳过 Homebrew 相关安装"
  fi

  refresh_shell_paths

  log "检查并安装 Git、Node.js 和 Python 3.13"
  if command -v git >/dev/null 2>&1; then
    echo "Git 已安装，跳过。"
    git --version || true
  elif [ -n "${brew_bin:-}" ]; then
    brew_install_formula "Git" "git" "command -v git" "https://git-scm.com/download/mac" || true
  else
    add_manual_action "Git" "https://git-scm.com/download/mac" "未检测到 Git，也没有可用 Homebrew，请人工下载安装"
  fi

  install_node_direct || true
  install_python313_direct || true

  refresh_shell_paths
  python3.13 --version || python3 --version || true
}

ensure_ffmpeg() {
  local brew_bin

  refresh_shell_paths
  if command -v ffmpeg >/dev/null 2>&1; then
    echo "FFmpeg 已安装，跳过。"
    ffmpeg -version | head -n 1 || true
    return 0
  fi

  log "检查并安装 FFmpeg"
  brew_bin="$(find_brew || true)"
  if [ -n "${brew_bin:-}" ]; then
    eval "$("$brew_bin" shellenv)"
    brew_install_formula "FFmpeg" "ffmpeg" "command -v ffmpeg" "https://ffmpeg.org/download.html" || true
  else
    add_manual_action "FFmpeg" "https://ffmpeg.org/download.html" "未检测到 Homebrew，请人工安装 FFmpeg"
  fi
}

npm_package_probe_path() {
  local package_name="$1"

  printf '%s' "$package_name" | sed 's|/|%2f|g'
}

choose_npm_registry() {
  local package_name="$1"
  local label="$2"
  local package_path official_ms mirror_ms

  package_path="$(npm_package_probe_path "$package_name")"

  log "测速 $label npm 下载路径"
  echo "正在测速 $label 的 npm 官方源和 npmmirror..."

  official_ms="$(measure_url_ms "https://registry.npmjs.org/${package_path}")"
  mirror_ms="$(measure_url_ms "https://registry.npmmirror.com/${package_path}")"

  echo "$label npm 官方源测速: ${official_ms}ms"
  echo "$label npmmirror 测速: ${mirror_ms}ms"

  if [ "$mirror_ms" -lt "$official_ms" ]; then
    AGENT_NPM_SELECTED_REGISTRY_URL="https://registry.npmmirror.com"
    AGENT_NPM_SELECTED_REGISTRY_NAME="npmmirror"
    AGENT_NPM_FALLBACK_REGISTRY_URL="https://registry.npmjs.org"
    AGENT_NPM_FALLBACK_REGISTRY_NAME="npm官方源"
  else
    AGENT_NPM_SELECTED_REGISTRY_URL="https://registry.npmjs.org"
    AGENT_NPM_SELECTED_REGISTRY_NAME="npm官方源"
    AGENT_NPM_FALLBACK_REGISTRY_URL="https://registry.npmmirror.com"
    AGENT_NPM_FALLBACK_REGISTRY_NAME="npmmirror"
  fi

  record_selected_source "$label" "npm/$AGENT_NPM_SELECTED_REGISTRY_NAME" "测速: npm官方源 ${official_ms}ms / npmmirror ${mirror_ms}ms；备用: $AGENT_NPM_FALLBACK_REGISTRY_NAME"
}

npm_install_global() {
  local package_name="$1"
  local label="$2"
  local binary_name="$3"

  ensure_user_npm_prefix
  refresh_shell_paths
  log "安装 $label"
  if command -v "$binary_name" >/dev/null 2>&1; then
    echo "$label 已安装，跳过。"
    "$binary_name" --version || true
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "未找到 npm，跳过 $label 自动安装。"
    add_manual_action "$label" "https://nodejs.org/en/download" "需要先人工安装 Node.js/npm 后再安装 $label"
    return 0
  fi

  choose_npm_registry "$package_name" "$label"
  npm config set registry "$AGENT_NPM_SELECTED_REGISTRY_URL" >/dev/null 2>&1 || true
  if run_with_retries "$label" 3 npm install -g "$package_name" --registry="$AGENT_NPM_SELECTED_REGISTRY_URL"; then
    if verify_or_link_cli_binary "$label" "$binary_name"; then
      return 0
    fi
  fi

  echo "$label 主 npm 下载路径失败，切换备用路径: $AGENT_NPM_FALLBACK_REGISTRY_NAME"
  npm config set registry "$AGENT_NPM_FALLBACK_REGISTRY_URL" >/dev/null 2>&1 || true
  record_selected_source "$label 备用" "npm/$AGENT_NPM_FALLBACK_REGISTRY_NAME" "主路径失败后切换备用路径"
  if run_with_retries "$label 备用路径" 2 npm install -g "$package_name" --registry="$AGENT_NPM_FALLBACK_REGISTRY_URL"; then
    verify_or_link_cli_binary "$label" "$binary_name" || add_manual_action "$label" "https://www.npmjs.com/package/$package_name" "$label 已安装但命令不可用，请检查 PATH"
  else
    add_manual_action "$label" "https://www.npmjs.com/package/$package_name" "$label npm 全局安装失败，请人工处理"
  fi
}

select_codepilot_dmg() {
  case "$(uname -m)" in
    arm64) echo "$APP_DIR/CodePilot-0.54.0-arm64.dmg" ;;
    x86_64) echo "$APP_DIR/CodePilot-0.54.0-x64.dmg" ;;
    *) echo "不支持的 Mac 架构: $(uname -m)" >&2; return 1 ;;
  esac
}

install_dmg_app() {
  local dmg_path="$1"
  local label="$2"
  local mount_dir
  local app_path
  local installed_app="/Applications/${label}.app"

  if [ -d "$installed_app" ]; then
    echo "$label 已安装，跳过。"
    return 0
  fi

  if [ ! -f "$dmg_path" ]; then
    echo "缺少安装包: $dmg_path"
    add_manual_action "$label" "https://www.google.com/search?q=${label}+macOS+download" "缺少本地 DMG 安装包"
    return 0
  fi

  log "安装 $label"
  xattr -dr com.apple.quarantine "$dmg_path" 2>/dev/null || true
  mount_dir="$(mktemp -d "/tmp/${label}.XXXXXX")"
  if ! hdiutil attach "$dmg_path" -nobrowse -mountpoint "$mount_dir" >/dev/null; then
    add_manual_action "$label" "$dmg_path" "DMG 挂载失败，请人工打开安装包"
    rm -rf "$mount_dir" 2>/dev/null || true
    return 0
  fi
  app_path="$(find "$mount_dir" -maxdepth 2 -name '*.app' -type d | head -n 1)"

  if [ -z "$app_path" ]; then
    hdiutil detach "$mount_dir" >/dev/null || true
    echo "在 $dmg_path 中没有找到 .app"
    add_manual_action "$label" "$dmg_path" "DMG 中没有找到 .app，请人工检查安装包"
    return 0
  fi

  if ! sudo ditto "$app_path" "/Applications/$(basename "$app_path")"; then
    add_manual_action "$label" "$dmg_path" "复制到 /Applications 失败，请人工拖拽安装"
  fi
  hdiutil detach "$mount_dir" >/dev/null || true
}

install_obsidian_cli() {
  local cli_path="/Applications/Obsidian.app/Contents/MacOS/obsidian-cli"
  local target="/usr/local/bin/obsidian"

  refresh_shell_paths
  if command -v obsidian >/dev/null 2>&1; then
    echo "Obsidian CLI 已安装，跳过。"
    obsidian version || true
    return 0
  fi

  if [ ! -x "$cli_path" ]; then
    echo "未找到 Obsidian CLI 二进制：$cli_path"
    echo "请先正常打开 Obsidian，然后在设置里注册命令行界面。"
    return 0
  fi

  log "安装 Obsidian CLI 命令"
  sudo mkdir -p /usr/local/bin
  sudo ln -sf "$cli_path" "$target"
  "$target" version || true
}

write_claude_memory() {
  log "创建工作目录、Obsidian 知识库目录和全局 CLAUDE.md"
  mkdir -p "$BRIDGE_DIR" "$VAULT_DIR" "$HOME/.claude/skills"
  local rendered_tmp
  rendered_tmp="$(mktemp)"

  if [ -f "$TEMPLATE_DIR/CLAUDE.md" ]; then
    sed \
      -e "s|__VAULT_PATH__|$VAULT_DIR|g" \
      -e "s|__BRIDGE_PATH__|$BRIDGE_DIR|g" \
      "$TEMPLATE_DIR/CLAUDE.md" > "$rendered_tmp"
  else
    echo "缺少模板: $TEMPLATE_DIR/CLAUDE.md"
    add_manual_action "CLAUDE.md" "$TEMPLATE_DIR/CLAUDE.md" "缺少模板文件，已跳过自动写入"
    rm -f "$rendered_tmp"
    return 0
  fi

  mkdir -p "$HOME/.claude"
  local global_claude="$HOME/.claude/CLAUDE.md"
  local global_tmp
  global_tmp="$(mktemp)"
  if [ -f "$global_claude" ]; then
    if ! awk '
      /<!-- BEGIN CODEPILOT KB DEFAULTS -->/ { skip = 1; next }
      /<!-- END CODEPILOT KB DEFAULTS -->/ { skip = 0; next }
      !skip { print }
    ' "$global_claude" > "$global_tmp"; then
      cp "$global_claude" "$global_tmp"
    fi
  else
    : > "$global_tmp"
  fi

  {
	    cat "$global_tmp"
	    echo ""
	    echo "<!-- BEGIN CODEPILOT KB DEFAULTS -->"
	    cat "$rendered_tmp"
	    echo "<!-- END CODEPILOT KB DEFAULTS -->"
	  } > "$global_claude"
	  rm -f "$global_tmp" "$rendered_tmp"
	  echo "全局 CLAUDE.md 默认知识库路径已刷新。"
}

install_skills() {
  log "安装基础 Skills"
  mkdir -p "$HOME/.claude/skills"
  if [ -d "$SKILL_DIR" ]; then
    for skill in "$SKILL_DIR"/*; do
      [ -d "$skill" ] || continue
      if [ -d "$HOME/.claude/skills/$(basename "$skill")" ]; then
        echo "Skill 已安装，跳过: $(basename "$skill")"
        continue
      fi
      if cp -R "$skill" "$HOME/.claude/skills/$(basename "$skill")"; then
        echo "已安装 Skill: $(basename "$skill")"
      else
        add_manual_action "Skill: $(basename "$skill")" "$skill" "Skill 复制失败，请人工复制"
      fi
    done
  else
    add_manual_action "基础 Skills" "$SKILL_DIR" "安装包中缺少 Skills 目录"
  fi
}

install_tool_sources() {
  local tool target_root target

  log "安装工具源码和工具说明"
  if [ ! -d "$TOOL_DIR" ]; then
    echo "安装包中没有额外工具源码目录，跳过。"
    return 0
  fi

  target_root="$BRIDGE_DIR/tools"
  mkdir -p "$target_root"
  for tool in "$TOOL_DIR"/*; do
    [ -e "$tool" ] || continue
    target="$target_root/$(basename "$tool")"
    if [ -e "$target" ]; then
      echo "工具已存在，跳过: $(basename "$tool")"
      continue
    fi
    if cp -R "$tool" "$target"; then
      echo "已安装工具: $(basename "$tool")"
    else
      add_manual_action "工具: $(basename "$tool")" "$tool" "工具复制失败，请人工复制"
    fi
  done
}

configure_power() {
  log "设置 Mac 接入电源时不自动睡眠"
  sudo pmset -c sleep 0 disksleep 0 displaysleep 0 powernap 1 womp 1 || true
}

print_next_steps() {
  cat <<EOF

============================================================
安装完成后的人工步骤
============================================================

1. 打开 CodePilot。
   如果提示无法验证开发者：
   系统设置 -> 隐私与安全性 -> 仍要打开。

2. 在 CodePilot 里配置服务商：
   左下角 [设置] -> [服务商] -> 选择类型 -> 客户自己填写 API Key。

3. 打开 Obsidian，选择这个知识库目录：
   $VAULT_DIR

4. 开启 Obsidian CLI：
   Obsidian 左下角齿轮 -> 关于/通用 -> 高级 -> 命令行界面 -> 注册。
   然后在终端验证：
   obsidian help

5. 如需飞书能力，客户自己授权：
   lark-cli config init --new

工作目录：
   $BRIDGE_DIR

失败日志：
   $LOG_FILE

交付清单：
   $REPORT_FILE

============================================================

EOF
}

main() {
  local codepilot_dmg

  echo ""
  echo "============================================================"
  echo "  曲率 AI · Agent-Obsidian-install"
  echo "  正在安装 Agent + Obsidian + 自动化环境"
  echo "============================================================"
  echo "脚本版本: $SCRIPT_VERSION"
  echo "安装日志: $LOG_FILE"

  print_component_status "安装前检测" || true
  ensure_admin_and_tty
  ensure_command_line_tools
  configure_china_mirrors
  ensure_homebrew_and_node
  npm_install_global "@anthropic-ai/claude-code" "Claude Code" "claude"
  npm_install_global "@larksuite/cli" "Lark CLI" "lark-cli"
  npm_install_global "hyperframes" "HyperFrames CLI" "hyperframes"
  npm_install_global "@wecom/cli" "企业微信 CLI" "wecom-cli"
  install_python_cli_tools
  ensure_ffmpeg
  codepilot_dmg="$(select_codepilot_dmg || true)"
  install_dmg_app "$codepilot_dmg" "CodePilot"
  install_dmg_app "$APP_DIR/Obsidian-1.12.7.dmg" "Obsidian"
  install_obsidian_cli
  write_claude_memory
  install_skills
  install_tool_sources
  configure_power
  open -a CodePilot || true
  open -a Obsidian || true
  write_delivery_report "安装完成后检测"
  print_next_steps
}

main "$@"
