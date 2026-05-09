#!/usr/bin/env bash
# =============================================================================
# install.sh · Mac / Linux 远程一行命令入口
# =============================================================================
# 业界标准的"一行命令"安装入口（参考 Homebrew / Rust / Bun）
# 客户在终端粘贴下面这条命令即可触发完整安装：
#
#   curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/Agent-Obsidian-install/main/install.sh | bash
#
# 自动行为：
#   1. 探测 OS（Darwin / Linux）和架构（arm64 / x86_64）
#   2. 三级查找完整安装包：
#      ① ~/Downloads/自动部署脚本/   （已解压目录，优先）
#      ② ~/Downloads/自动部署脚本.zip （压缩包，自动解压）
#      ③ git clone GitHub 仓库       （兜底，无离线包）
#   3. 调用对应平台脚本（scripts/bootstrap.sh）
# =============================================================================
set -Eeuo pipefail

REPO_URL="https://github.com/Daknniel-0881/Agent-Obsidian-install.git"
REPO_BRANCH="main"
DIST_NAME="自动部署脚本"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
TARGET_DIR="$DOWNLOADS_DIR/$DIST_NAME"

# 中文水印 banner
print_banner() {
  echo ""
  echo "============================================================"
  echo "  曲率 AI · Agent-Obsidian-install"
  echo "  跨平台一键部署 · Agent + 知识库 + 自动化"
  echo "============================================================"
  echo ""
}

log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

# 探测 OS + 架构
detect_system() {
  OS_NAME="$(uname -s)"
  ARCH_NAME="$(uname -m)"
  case "$OS_NAME" in
    Darwin) OS_LABEL="macOS" ;;
    Linux)  OS_LABEL="Linux" ;;
    *)      fail "不支持的系统: $OS_NAME（仅支持 macOS / Linux，Windows 用户请用 install.ps1）" ;;
  esac
  case "$ARCH_NAME" in
    arm64|aarch64) ARCH_LABEL="ARM64" ;;
    x86_64|amd64)  ARCH_LABEL="x86_64" ;;
    *)             ARCH_LABEL="$ARCH_NAME（未识别，按 x86_64 处理）" ;;
  esac
  log "检测系统: $OS_LABEL / $ARCH_LABEL"
}

# 检查必要的命令
check_prereq() {
  for cmd in unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "未找到 $cmd（解压 zip 需要），尝试自动安装..."
      case "$OS_NAME" in
        Darwin) log "macOS 默认带 unzip，如缺失请运行: xcode-select --install" ;;
        Linux)  sudo apt-get update -y && sudo apt-get install -y unzip || sudo yum install -y unzip || fail "请手动安装 unzip" ;;
      esac
    fi
  done
}

# 三级回退查找/获取分发包
locate_or_fetch_dist() {
  # ① 已解压目录
  if [[ -d "$TARGET_DIR/scripts" ]]; then
    log "[路径①] 找到已解压目录: $TARGET_DIR"
    return 0
  fi

  # ② 找 zip 解压
  local zip_candidates=(
    "$DOWNLOADS_DIR/$DIST_NAME.zip"
    "$DOWNLOADS_DIR/Agent-Obsidian-install.zip"
    "$DOWNLOADS_DIR/agent-obsidian-install.zip"
  )
  for ZIP in "${zip_candidates[@]}"; do
    if [[ -f "$ZIP" ]]; then
      log "[路径②] 找到压缩包: $ZIP"
      log "解压到: $DOWNLOADS_DIR/"
      check_prereq
      unzip -q -o "$ZIP" -d "$DOWNLOADS_DIR/"
      # 解压后可能是 自动部署脚本/ 或 Agent-Obsidian-install-main/，做一次归一化
      if [[ -d "$DOWNLOADS_DIR/Agent-Obsidian-install-main" && ! -d "$TARGET_DIR" ]]; then
        mv "$DOWNLOADS_DIR/Agent-Obsidian-install-main" "$TARGET_DIR"
      fi
      [[ -d "$TARGET_DIR/scripts" ]] && return 0
      fail "解压后未找到 scripts/ 目录，zip 可能损坏"
    fi
  done

  # ③ git clone 兜底
  log "[路径③] 本地未找到分发包，从 GitHub 克隆..."
  if ! command -v git >/dev/null 2>&1; then
    fail "未安装 git，无法 clone。请先下载 zip 到 $DOWNLOADS_DIR/ 再重试"
  fi
  git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$TARGET_DIR" \
    || fail "git clone 失败，请检查网络（或手动下载 zip 放到 $DOWNLOADS_DIR/）"
  log "克隆完成: $TARGET_DIR"
  log "注意: git clone 不含 离线安装包/ 目录（仓库忽略了 *.dmg/*.exe/*.deb），脚本会回退在线下载"
}

# 主流程
main() {
  print_banner
  detect_system
  locate_or_fetch_dist

  # 透传所有参数给 bootstrap.sh
  log "调用安装主脚本: $TARGET_DIR/scripts/bootstrap.sh"
  echo ""
  exec bash "$TARGET_DIR/scripts/bootstrap.sh" "$@"
}

main "$@"
