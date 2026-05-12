#!/usr/bin/env bash
set -uo pipefail

REPO="Daknniel-0881/qulv-agent-obsidian-install"
ZIP_NAME="Agent-Obsidian-install-Mac.zip"
EXPECTED_SHA256="2f7f6e7b831d46a75a01776c565a44482fb98225f3b94651c302e29091680724"
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ZIP_NAME}"
MAC_DIR="$HOME/Downloads/Mac系统"
LOG_DIR="$HOME/Downloads/Agent-Obsidian-install-logs"

fail() {
  echo ""
  echo "安装启动失败：$1"
  echo "请把上面的终端内容发给曲率 AI 排查。"
  exit 1
}

echo ""
echo "============================================================"
echo "  曲率 AI · Agent-Obsidian-install"
echo "============================================================"
echo ""
echo "安装包将下载到：$MAC_DIR"
echo "安装日志会保存在：$LOG_DIR"
echo ""

command -v curl >/dev/null 2>&1 || fail "这台 Mac 找不到 curl"
command -v shasum >/dev/null 2>&1 || fail "这台 Mac 找不到 shasum"
command -v ditto >/dev/null 2>&1 || fail "这台 Mac 找不到 ditto"

mkdir -p "$MAC_DIR" "$LOG_DIR" || fail "无法创建下载目录"
cd "$MAC_DIR" || fail "无法进入下载目录：$MAC_DIR"

echo "正在下载最新版安装包..."
rm -f "$ZIP_NAME.part"
if ! curl -L --fail --progress-bar -o "$ZIP_NAME.part" "$DOWNLOAD_URL"; then
  open "https://github.com/${REPO}/releases/latest" 2>/dev/null || true
  fail "下载安装包失败，已尝试打开 GitHub Release 页面"
fi
mv "$ZIP_NAME.part" "$ZIP_NAME" || fail "无法保存安装包"

echo "正在校验安装包..."
ACTUAL_SHA256="$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "期望：$EXPECTED_SHA256"
  echo "实际：$ACTUAL_SHA256"
  fail "安装包校验失败，请重新运行安装命令"
fi

echo "正在解压安装包..."
rm -rf "$MAC_DIR/apps" "$MAC_DIR/install" "$MAC_DIR/templates" "$MAC_DIR/payload"
ditto -x -k "$ZIP_NAME" "$MAC_DIR" || fail "安装包解压失败"
xattr -dr com.apple.quarantine "$MAC_DIR" 2>/dev/null || true

SCRIPT="$MAC_DIR/install/install-macos.sh"
[ -f "$SCRIPT" ] || fail "解压后没有找到安装脚本：$SCRIPT"
chmod +x "$SCRIPT" 2>/dev/null || true

echo ""
echo "开始运行 Mac 安装脚本。请保持这个终端窗口打开。"
echo ""

if [ -r /dev/tty ]; then
  bash "$SCRIPT" </dev/tty
else
  bash "$SCRIPT"
fi
INSTALL_EXIT=$?

echo ""
echo "安装脚本退出码：$INSTALL_EXIT"
echo "日志目录：$LOG_DIR"
exit "$INSTALL_EXIT"

