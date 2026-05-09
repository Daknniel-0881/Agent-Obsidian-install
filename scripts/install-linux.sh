#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-}"
USE_CHINA_MIRROR=0
DRY_RUN=0
KEEP_AWAKE=0
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
    --keep-awake)
      KEEP_AWAKE=1
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
  LOG_FILE="$log_dir/install-linux-$(date '+%Y%m%d-%H%M%S').log"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

send_telemetry() {
  # 失败回传:从 manifest.json 读 telemetry.webhook,启用时 POST 脱敏摘要(飞书自定义机器人格式)
  local code="$1"
  local line="$2"
  local manifest="$ROOT_DIR/manifest.json"
  [[ -f "$manifest" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  local enabled webhook
  enabled="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(str(d.get('telemetry',{}).get('enabled',False)).lower())" "$manifest" 2>/dev/null || echo false)"
  webhook="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('telemetry',{}).get('webhook') or '')" "$manifest" 2>/dev/null || echo "")"
  [[ "$enabled" == "true" ]] || return 0
  [[ -n "$webhook" ]] || return 0

  local arch distro text payload
  arch="$(uname -m 2>/dev/null || echo unknown)"
  if command -v lsb_release >/dev/null 2>&1; then
    distro="$(lsb_release -ds 2>/dev/null || echo Linux)"
  elif [[ -f /etc/os-release ]]; then
    distro="$(. /etc/os-release && echo "${PRETTY_NAME:-Linux}")"
  else
    distro="Linux"
  fi
  text="OS: ${distro} ${arch} / 退出码: ${code} / 位置: line ${line} / 时间: $(date '+%Y-%m-%d %H:%M:%S')"
  payload="$(python3 -c "import json,sys;print(json.dumps({'msg_type':'post','content':{'post':{'zh_cn':{'title':'Agent-Obsidian-install 安装失败','content':[[{'tag':'text','text':sys.argv[1]}]]}}}},ensure_ascii=False))" "$text" 2>/dev/null)" || return 0
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

find_offline_file() {
  local pattern="$1"
  local root="$PACKAGES_DIR/离线安装包"
  [[ -d "$root" ]] || return 1
  find "$root" -type f -iname "$pattern" | sort | head -n 1
}

install_offline_debs_from_dir() {
  local dir="$1"
  local label="$2"
  [[ -d "$dir" ]] || return 1
  find "$dir" -maxdepth 1 -type f -name "*.deb" | grep -q . || return 1

  log "Installing offline $label deb packages from $dir"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ sudo dpkg -i \"$dir\"/*.deb"
    return
  fi

  sudo dpkg -i "$dir"/*.deb || sudo apt-get install -f -y
}

install_system_deps() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

  if ! command -v git >/dev/null 2>&1; then
    install_offline_debs_from_dir "$PACKAGES_DIR/离线安装包/linux-${arch}/git" "Git" || true
  fi

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    install_offline_debs_from_dir "$PACKAGES_DIR/离线安装包/linux-${arch}/node" "Node.js" || true
  fi

  if command -v git >/dev/null 2>&1 && command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log "Git, Node.js and npm are already available"
    return
  fi

  log "Installing Git, Node.js and npm"
  if command -v apt-get >/dev/null 2>&1; then
    run sudo apt-get update
    run sudo apt-get install -y git nodejs npm
  elif command -v dnf >/dev/null 2>&1; then
    run sudo dnf install -y git nodejs npm
  elif command -v pacman >/dev/null 2>&1; then
    run sudo pacman -Sy --needed git nodejs npm
  else
    echo "Unsupported Linux package manager. Install git, nodejs and npm manually, then rerun."
    exit 1
  fi
}

npm_global_install() {
  local pkg="$1"
  local tgz_path=""
  local registry_args=()

  case "$pkg" in
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
    log "Installing offline npm package $pkg from $tgz_path"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "+ npm install -g \"$tgz_path\""
      return
    fi
    npm install -g "$tgz_path" || sudo npm install -g "$tgz_path"
    return
  fi

  if [[ "$USE_CHINA_MIRROR" == "1" ]]; then
    registry_args=(--registry=https://registry.npmmirror.com)
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ npm install -g $pkg ${registry_args[*]}"
    return
  fi

  npm install -g "$pkg" "${registry_args[@]}" || sudo npm install -g "$pkg" "${registry_args[@]}"
}

install_npm_packages() {
  log "Installing Claude Code"
  npm_global_install @anthropic-ai/claude-code

  log "Installing Lark CLI"
  npm_global_install @larksuite/cli

  run node --version
  run npm --version
  run claude --version || true
  run lark-cli --version || true
}

install_deb_if_present() {
  local deb_path="$1"
  local label="$2"

  if [[ ! -f "$deb_path" ]]; then
    echo "Missing $label package for this architecture: $deb_path"
    exit 1
  fi

  log "Installing $label"
  run sudo dpkg -i "$deb_path" || run sudo apt-get install -f -y
}

install_apps() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

  case "$arch" in
    amd64|x86_64)
      install_deb_if_present "$PACKAGES_DIR/Linux系统/CodePilot-0.54.0-amd64.deb" "CodePilot"
      install_deb_if_present "$PACKAGES_DIR/Linux系统/obsidian_1.12.7_amd64.deb" "Obsidian"
      ;;
    arm64|aarch64)
      install_deb_if_present "$PACKAGES_DIR/Linux系统/CodePilot-0.54.0-arm64.deb" "CodePilot"
      install_deb_if_present "$PACKAGES_DIR/Linux系统/obsidian_1.12.7_arm64.deb" "Obsidian"
      ;;
    *)
      echo "Unsupported Linux architecture: $arch"
      ;;
  esac
}

create_workspace() {
  WORK_ROOT="${WORK_ROOT:-$HOME/CodePilot}"
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
  fi
}

install_bundled_skills() {
  local src_dir="$ROOT_DIR/payload/skills"
  local dst_dir="$HOME/.claude/skills"

  log "Installing bundled skills"
  run mkdir -p "$dst_dir"

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

  log "Disabling Linux sleep targets through systemd"
  run sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
}

print_manual_steps() {
  cat <<EOF

================ 待手工操作清单 ================

1. 打开 CodePilot 客户端，并手动配置服务商（脚本不预填）：
   左下角【设置】 -> 【服务商】 -> 选择类型 -> 粘贴客户的 API Key -> 保存并测试连通性。

2. 打开 Obsidian 客户端，并选择本机 Vault 目录：
   $VAULT_DIR

3. 启用 Obsidian CLI：
   Obsidian -> 设置 -> 关于/通用 -> 高级 -> 命令行接口 -> 点击【注册】。
   完成后在终端验证：
     obsidian help

4. 飞书 CLI 仅完成安装，未预填任何 app_id / app_secret / token。
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
  log "Starting Linux deployment"
  PACKAGES_DIR="$(resolve_packages_dir || true)"
  if [[ -z "$PACKAGES_DIR" ]]; then
    echo "Package directory not found."
    echo "Put the full installer folder named 自动部署脚本 under Downloads, or pass --packages-dir."
    exit 1
  fi
  echo "Using package directory: $PACKAGES_DIR"

  install_system_deps
  install_npm_packages
  install_apps
  create_workspace
  install_bundled_skills
  configure_power
  print_manual_steps
  echo "安装日志: $LOG_FILE"
}

main "$@"
