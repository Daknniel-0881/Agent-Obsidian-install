#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ZIP_URL="https://github.com/Daknniel-0881/qulv-agent-obsidian-install/archive/refs/heads/main.zip"
PACKAGE_URL="https://github.com/Daknniel-0881/qulv-agent-obsidian-install/releases/latest/download/Agent-Obsidian-install-Mac.zip"
MAC_DIR="$HOME/Downloads/Mac系统"
TMP_DIR="$(mktemp -d "/tmp/qulv-agent-obsidian-install.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo ""
echo "============================================================"
echo "  曲率 AI · Mac 安装包下载"
echo "============================================================"
echo ""

echo "正在从 GitHub 下载最新 Mac 安装包..."
curl -fL --connect-timeout 15 --max-time 900 "$REPO_ZIP_URL" -o "$TMP_DIR/repo.zip"

echo "正在解压仓库..."
ditto -x -k "$TMP_DIR/repo.zip" "$TMP_DIR/repo"

SRC_MAC_DIR="$(find "$TMP_DIR/repo" -type d -name "Mac系统" -print | head -n 1)"
if [ -z "${SRC_MAC_DIR:-}" ] || [ ! -d "$SRC_MAC_DIR" ]; then
  echo "没有在仓库里找到 Mac系统 文件夹。"
  exit 1
fi

echo "正在更新本机下载目录：$MAC_DIR"
rm -rf "$MAC_DIR"
mkdir -p "$(dirname "$MAC_DIR")"
ditto "$SRC_MAC_DIR" "$MAC_DIR"
xattr -dr com.apple.quarantine "$MAC_DIR" 2>/dev/null || true

echo "正在下载 Mac 安装包..."
curl -fL --connect-timeout 15 --max-time 1800 "$PACKAGE_URL" -o "$MAC_DIR/Agent-Obsidian-install-Mac.zip"

if [ ! -f "$MAC_DIR/复制到终端运行.txt" ]; then
  echo "缺少 $MAC_DIR/复制到终端运行.txt"
  exit 1
fi

echo "准备打开安装终端窗口..."
bash "$MAC_DIR/复制到终端运行.txt"
