#!/usr/bin/env bash
# =============================================================================
# install.sh · Mac / Linux 远程一行命令入口
# =============================================================================
# 业界标准的"一行命令"安装入口（参考 Homebrew / Rust / Bun）
# 客户在终端粘贴下面这条命令即可触发完整安装：
#
#   curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh | bash
#
# 自动行为：
#   1. 探测 OS（Darwin / Linux）和架构（arm64 / x86_64）
#   2. 四级查找完整安装包：
#      ① ~/Downloads/自动部署脚本/                    （已解压目录，优先）
#      ② ~/Downloads/自动部署脚本-{Mac|Linux}.zip      （分平台压缩包，自动解压）
#      ③ GitHub Release 自动下载分平台 zip            （含离线包，~350-680MB）
#      ④ git clone GitHub 仓库                        （最后兜底，不含离线包）
#   3. 调用对应平台脚本（scripts/bootstrap.sh）
# =============================================================================
set -Eeuo pipefail

REPO_OWNER="Daknniel-0881"
REPO_NAME="qulv-agent-obsidian-install"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
REPO_BRANCH="main"
RELEASE_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download"
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
    Darwin) OS_LABEL="macOS"; ZIP_PLATFORM="Mac" ;;
    Linux)  OS_LABEL="Linux"; ZIP_PLATFORM="Linux" ;;
    *)      fail "不支持的系统: $OS_NAME（仅支持 macOS / Linux，Windows 用户请用 install.ps1）" ;;
  esac
  case "$ARCH_NAME" in
    arm64|aarch64) ARCH_LABEL="ARM64" ;;
    x86_64|amd64)  ARCH_LABEL="x86_64" ;;
    *)             ARCH_LABEL="$ARCH_NAME（未识别，按 x86_64 处理）" ;;
  esac
  log "检测系统: $OS_LABEL / $ARCH_LABEL"
  log "目标分平台 zip: ${DIST_NAME}-${ZIP_PLATFORM}.zip"
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

# 解压 zip 到 $DOWNLOADS_DIR/，并归一化目录名为 $TARGET_DIR
extract_zip() {
  local ZIP="$1"
  log "解压到: $DOWNLOADS_DIR/"
  check_prereq
  unzip -q -o "$ZIP" -d "$DOWNLOADS_DIR/"
  # 归一化：GitHub source zip 解压成 <repo>-main/
  for SOURCE_ROOT in "$DOWNLOADS_DIR/qulv-agent-obsidian-install-main" "$DOWNLOADS_DIR/Agent-Obsidian-install-main"; do
    if [[ -d "$SOURCE_ROOT" && ! -d "$TARGET_DIR" ]]; then
      mv "$SOURCE_ROOT" "$TARGET_DIR"
      break
    fi
  done
  [[ -d "$TARGET_DIR/scripts" ]] || fail "解压后未找到 scripts/ 目录，zip 可能损坏"
}

# 从 GitHub Release 下载分平台 zip
# Release asset 用 ASCII 名（GitHub 不支持非 ASCII 文件名）
# 本地输出仍用中文名（便于客户辨识）
download_from_release() {
  local RELEASE_ASSET="Agent-Obsidian-install-${ZIP_PLATFORM}.zip"
  local LOCAL_NAME="${DIST_NAME}-${ZIP_PLATFORM}.zip"
  local URL="${RELEASE_BASE}/${RELEASE_ASSET}"
  local OUT="$DOWNLOADS_DIR/${LOCAL_NAME}"
  log "[路径③] 从 GitHub Release 下载: $RELEASE_ASSET"
  log "URL: $URL"
  log "（首次下载约 350-680MB，含完整离线安装包，请耐心等待）"
  if ! command -v curl >/dev/null 2>&1; then
    fail "未安装 curl，无法下载。请先安装 curl 或手动下载 zip 到 $DOWNLOADS_DIR/"
  fi
  if ! curl -fL --progress-bar -o "$OUT" "$URL"; then
    rm -f "$OUT"
    return 1
  fi
  extract_zip "$OUT"
  log "Release 下载 + 解压完成"
}

# 四级回退查找/获取分发包
locate_or_fetch_dist() {
  # ① 已解压目录
  if [[ -d "$TARGET_DIR/scripts" ]]; then
    log "[路径①] 找到已解压目录: $TARGET_DIR"
    return 0
  fi

  # ② 找本地 zip（分平台优先 → 通用 fallback）
  local zip_candidates=(
    "$DOWNLOADS_DIR/${DIST_NAME}-${ZIP_PLATFORM}.zip"
    "$DOWNLOADS_DIR/${DIST_NAME}-$(echo "$ZIP_PLATFORM" | tr '[:upper:]' '[:lower:]').zip"
    "$DOWNLOADS_DIR/$DIST_NAME.zip"
    "$DOWNLOADS_DIR/qulv-agent-obsidian-install.zip"
    "$DOWNLOADS_DIR/Agent-Obsidian-install.zip"
    "$DOWNLOADS_DIR/agent-obsidian-install.zip"
  )
  for ZIP in "${zip_candidates[@]}"; do
    if [[ -f "$ZIP" ]]; then
      log "[路径②] 找到本地压缩包: $ZIP"
      extract_zip "$ZIP"
      return 0
    fi
  done

  # ③ 从 GitHub Release 下载分平台 zip
  if download_from_release; then
    return 0
  fi
  log "Release 下载失败，回退到 git clone..."

  # ④ git clone 最后兜底
  log "[路径④] 从 GitHub 克隆仓库..."
  if ! command -v git >/dev/null 2>&1; then
    fail "未安装 git 也下载不到 Release zip。请检查网络或手动下载 zip 到 $DOWNLOADS_DIR/"
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
