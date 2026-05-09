#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-}"
USE_CHINA_MIRROR=0
DRY_RUN=0
KEEP_AWAKE=1
FORCE_SKILLS=0
LOG_FILE=""
WATERMARK="${WATERMARK:-曲率 AI · Agent-Obsidian-install}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn|--china-mirror)
      USE_CHINA_MIRROR=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --packages-dir)
      PACKAGES_DIR="$2"
      shift 2
      ;;
    --no-keep-awake)
      KEEP_AWAKE=0
      shift
      ;;
    --force-skills)
      FORCE_SKILLS=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

print_watermark() {
  cat <<EOF

============================================================
  $WATERMARK
  Agent + Obsidian + Automation deployment
============================================================

EOF
}

setup_logging() {
  local log_dir="$ROOT_DIR/logs"
  mkdir -p "$log_dir"
  LOG_FILE="$log_dir/install-macos-$(date '+%Y%m%d-%H%M%S').log"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

send_telemetry() {
  # 失败回传:从 manifest.json 读 telemetry.webhook,启用时 POST 脱敏摘要(飞书自定义机器人格式)
  # 不阻塞主流程,任何异常都被吞掉
  local code="$1"
  local line="$2"
  local manifest="$ROOT_DIR/manifest.json"
  [[ -f "$manifest" ]] || return 0
  command -v /usr/bin/python3 >/dev/null 2>&1 || return 0

  local enabled webhook
  enabled="$(/usr/bin/python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(str(d.get('telemetry',{}).get('enabled',False)).lower())" "$manifest" 2>/dev/null || echo false)"
  webhook="$(/usr/bin/python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('telemetry',{}).get('webhook') or '')" "$manifest" 2>/dev/null || echo "")"
  [[ "$enabled" == "true" ]] || return 0
  [[ -n "$webhook" ]] || return 0

  local arch os_ver text payload
  arch="$(uname -m 2>/dev/null || echo unknown)"
  os_ver="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  text="OS: macOS ${os_ver} ${arch} / 退出码: ${code} / 位置: line ${line} / 时间: $(date '+%Y-%m-%d %H:%M:%S')"
  payload="$(/usr/bin/python3 -c "import json,sys;print(json.dumps({'msg_type':'post','content':{'post':{'zh_cn':{'title':'Agent-Obsidian-install 安装失败','content':[[{'tag':'text','text':sys.argv[1]}]]}}}},ensure_ascii=False))" "$text" 2>/dev/null)" || return 0
  curl -sS --max-time 5 -X POST -H 'Content-Type: application/json' -d "$payload" "$webhook" >/dev/null 2>&1 || true
  echo "  (failure telemetry sent)"
}

on_error() {
  local line="$1"
  local code="$2"
  echo
  echo "安装失败，退出码: $code，位置: line $line"
  echo "失败日志: $LOG_FILE"
  echo "请把这个日志文件回传给交付人员，用于定位客户电脑上的失败原因。"
  send_telemetry "$code" "$line" || true
  exit "$code"
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ $*"
  else
    "$@"
  fi
}

is_package_dir() {
  local path="$1"
  [[ -d "$path/Mac系统" || -d "$path/Win系统" || -d "$path/Linux系统" ]]
}

resolve_packages_dir() {
  local candidates=()
  local path

  [[ -n "${PACKAGES_DIR:-}" ]] && candidates+=("$PACKAGES_DIR")
  candidates+=(
    "$ROOT_DIR/自动部署脚本"
    "$ROOT_DIR/packages/自动部署脚本"
    "$HOME/Downloads/自动部署脚本"
    "$HOME/Download/自动部署脚本"
    "/Downloads/自动部署脚本"
    "/download/自动部署脚本"
  )

  for path in /Users/*/Downloads/自动部署脚本 /home/*/Downloads/自动部署脚本 /mnt/c/自动部署脚本 /mnt/c/Downloads/自动部署脚本; do
    [[ -d "$path" ]] && candidates+=("$path")
  done

  for path in "${candidates[@]}"; do
    if [[ -n "$path" && -d "$path" ]] && is_package_dir "$path"; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path"
    exit 1
  fi
}

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return
  fi
}

install_homebrew_and_deps() {
  local brew_bin
  local arch
  arch="$(uname -m)"

  if ! command -v git >/dev/null 2>&1; then
    install_offline_pkg "git-*.pkg" "Git" || install_offline_pkg "Git-*.pkg" "Git" || true
  fi

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    install_offline_pkg "node-*-darwin-${arch}.pkg" "Node.js" || install_offline_pkg "node-*.pkg" "Node.js" || true
  fi

  if command -v git >/dev/null 2>&1 && command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log "Git and Node.js are already available"
    return
  fi

  brew_bin="$(find_brew || true)"

  if [[ -z "${brew_bin:-}" ]]; then
    log "Installing Homebrew"
    if [[ "$USE_CHINA_MIRROR" == "1" ]]; then
      echo "China mirror mode is enabled for npm. Homebrew mirror setup is intentionally not forced."
      echo "If Homebrew install is slow, use a trusted local mirror guide before rerunning."
    fi
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_bin="$(find_brew || true)"
  fi

  if [[ -z "${brew_bin:-}" ]]; then
    echo "Homebrew was not found after install. Please open a new terminal and rerun this script."
    exit 1
  fi

  eval "$("$brew_bin" shellenv)"
  log "Installing Git and Node.js"
  run brew install git node
}

find_offline_file() {
  local pattern="$1"
  local root="$PACKAGES_DIR/离线安装包"
  [[ -d "$root" ]] || return 1
  find "$root" -type f -iname "$pattern" | sort | head -n 1
}

install_offline_pkg() {
  local pattern="$1"
  local label="$2"
  local pkg_path
  pkg_path="$(find_offline_file "$pattern" || true)"
  [[ -n "$pkg_path" ]] || return 1

  log "Installing offline $label from $pkg_path"
  run sudo installer -pkg "$pkg_path" -target /
}

npm_global_install() {
  local package_name="$1"
  local label="$2"
  local registry_args=()
  local tgz_path=""

  case "$package_name" in
    @anthropic-ai/claude-code)
      tgz_path="$(find_offline_file "anthropic-ai-claude-code-*.tgz" || true)"
      [[ -n "$tgz_path" ]] || tgz_path="$(find_offline_file "claude-code-*.tgz" || true)"
      ;;
    @larksuite/cli)
      tgz_path="$(find_offline_file "larksuite-cli-*.tgz" || true)"
      [[ -n "$tgz_path" ]] || tgz_path="$(find_offline_file "lark-cli-*.tgz" || true)"
      ;;
  esac

  if [[ -n "$tgz_path" ]]; then
    log "Installing offline $label from $tgz_path"
    run npm install -g "$tgz_path"
    return
  fi

  if [[ "$USE_CHINA_MIRROR" == "1" ]]; then
    registry_args=(--registry=https://registry.npmmirror.com)
  fi

  log "Installing $label"
  run npm install -g "$package_name" "${registry_args[@]}"
}

install_npm_packages() {
  npm_global_install @anthropic-ai/claude-code "Claude Code"
  npm_global_install @larksuite/cli "Lark CLI"

  log "Versions"
  run node --version
  run npm --version
  run claude --version || true
  run lark-cli --version || true
}

select_codepilot_dmg() {
  local arch="$1"
  case "$arch" in
    arm64)
      echo "$PACKAGES_DIR/Mac系统/CodePilot-0.54.0-arm64.dmg"
      ;;
    x86_64)
      echo "$PACKAGES_DIR/Mac系统/CodePilot-0.54.0-x64.dmg"
      ;;
    *)
      echo "Unsupported macOS architecture: $arch" >&2
      exit 1
      ;;
  esac
}

install_dmg_app() {
  local dmg_path="$1"
  local label="$2"
  local mount_dir
  local app_path

  require_file "$dmg_path"
  mount_dir="$(mktemp -d "/tmp/${label}.XXXXXX")"

  log "Installing $label from $dmg_path"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ hdiutil attach \"$dmg_path\" -nobrowse -mountpoint \"$mount_dir\""
    echo "+ copy *.app to /Applications"
    return
  fi

  hdiutil attach "$dmg_path" -nobrowse -mountpoint "$mount_dir" >/dev/null
  app_path="$(find "$mount_dir" -maxdepth 2 -name '*.app' -type d | head -n 1)"
  if [[ -z "$app_path" ]]; then
    hdiutil detach "$mount_dir" >/dev/null || true
    echo "No .app found in $dmg_path"
    exit 1
  fi
  sudo ditto "$app_path" "/Applications/$(basename "$app_path")"
  hdiutil detach "$mount_dir" >/dev/null || true
}

create_workspace() {
  WORK_ROOT="${WORK_ROOT:-$HOME/Desktop/CodePilot}"
  BRIDGE_DIR="${BRIDGE_DIR:-$WORK_ROOT/Bridge}"
  VAULT_DIR="${VAULT_DIR:-$WORK_ROOT/Obsidian/ClaudeCode}"

  log "Creating workspace and vault directories"
  run mkdir -p "$BRIDGE_DIR" "$VAULT_DIR" "$HOME/.claude/skills"

  log "Writing CLAUDE.md"
  if [[ "$DRY_RUN" == "0" ]]; then
    sed \
      -e "s|__VAULT_PATH__|$VAULT_DIR|g" \
      -e "s|__BRIDGE_PATH__|$BRIDGE_DIR|g" \
      "$ROOT_DIR/templates/CLAUDE.md" > "$BRIDGE_DIR/CLAUDE.md"

    mkdir -p "$HOME/.claude"
    if [[ ! -f "$HOME/.claude/CLAUDE.md" ]] || ! grep -q "BEGIN CODEPILOT KB DEFAULTS" "$HOME/.claude/CLAUDE.md"; then
      {
        echo
        echo "<!-- BEGIN CODEPILOT KB DEFAULTS -->"
        cat "$BRIDGE_DIR/CLAUDE.md"
        echo "<!-- END CODEPILOT KB DEFAULTS -->"
      } >> "$HOME/.claude/CLAUDE.md"
    fi
  else
    echo "+ render templates/CLAUDE.md to $BRIDGE_DIR/CLAUDE.md"
    echo "+ append marked block to $HOME/.claude/CLAUDE.md"
  fi
}

install_bundled_skills() {
  local src_dir="$ROOT_DIR/payload/skills"
  local dst_dir="$HOME/.claude/skills"

  log "Installing bundled skills"
  run mkdir -p "$dst_dir"

  if [[ ! -d "$src_dir" ]]; then
    echo "No bundled skills found at $src_dir"
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ copy skills from $src_dir to $dst_dir"
    return
  fi

  for skill in "$src_dir"/*; do
    [[ -d "$skill" ]] || continue
    local name
    name="$(basename "$skill")"
    if [[ -e "$dst_dir/$name" && "$FORCE_SKILLS" != "1" ]]; then
      echo "Skill exists, skipping: $name"
    else
      rm -rf "$dst_dir/$name"
      cp -R "$skill" "$dst_dir/$name"
      echo "Installed skill: $name"
    fi
  done
}

configure_power() {
  if [[ "$KEEP_AWAKE" != "1" ]]; then
    return
  fi

  log "Configuring macOS AC power to stay awake"
  run sudo pmset -c sleep 0 disksleep 0 displaysleep 0 powernap 1 womp 1
}

print_manual_steps() {
  cat <<EOF

================ 待手工操作清单 ================

1. 打开 CodePilot 客户端。
   若 macOS 弹出「无法验证开发者」拦截：
   系统设置 -> 隐私与安全性 -> 滚动到底部找到 CodePilot 提示 -> 点【仍要打开】。

2. 打开 Obsidian 客户端，并选择本机 Vault 目录：
   $VAULT_DIR

3. 启用 Obsidian CLI：
   Obsidian -> 设置 -> 关于/通用 -> 高级 -> 命令行接口 -> 点击【注册】。
   完成后在终端验证：
     obsidian help

4. 在 CodePilot 里打开工作区目录：
   $BRIDGE_DIR

5. 在 CodePilot 里手动配置服务商（脚本不预填）：
   左下角【设置】 -> 【服务商】 -> 选择类型 -> 粘贴客户的 API Key -> 保存并测试连通性。

6. 飞书 CLI 仅完成安装，未预填任何 app_id / app_secret / token。
   客户准备好后再自己授权：
     lark-cli config init --new

完整清单见：
   $ROOT_DIR/templates/MANUAL_STEPS.md

================================================

EOF
}

main() {
  setup_logging
  trap 'on_error "$LINENO" "$?"' ERR
  print_watermark
  log "Starting macOS deployment"
  PACKAGES_DIR="$(resolve_packages_dir || true)"
  if [[ -z "$PACKAGES_DIR" ]]; then
    echo "Package directory not found."
    echo "Put the full installer folder named 自动部署脚本 under Downloads, or pass --packages-dir."
    exit 1
  fi
  echo "Using package directory: $PACKAGES_DIR"

  install_homebrew_and_deps
  install_npm_packages

  local arch
  arch="$(uname -m)"
  install_dmg_app "$(select_codepilot_dmg "$arch")" "CodePilot"
  install_dmg_app "$PACKAGES_DIR/Mac系统/Obsidian-1.12.7.dmg" "Obsidian"

  create_workspace
  install_bundled_skills
  configure_power

  run open -a CodePilot || true
  print_manual_steps
  echo "安装日志: $LOG_FILE"
}

main "$@"
