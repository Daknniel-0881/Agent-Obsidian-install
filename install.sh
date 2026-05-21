#!/usr/bin/env bash
set -Eeuo pipefail

REPO="Daknniel-0881/qulv-agent-obsidian-install"
BRANCH="${QULV_BRANCH:-main}"
RELEASE_TAG="${QULV_RELEASE_TAG:-v2026.05.21.20}"
MAC_ASSET="Agent-Obsidian-install-Mac-final-20260521.20.zip"
MAC_SHA256="52ae8f2ba5191b705e94f4a0fa65f68a61627a2d350db08ccb52665558969299"
MAC_DIR="$HOME/Downloads/Mac系统"

DEFAULT_MIRRORS=(
  "https://gh.llkk.cc/"
  "https://gh-proxy.com/"
  "https://mirror.ghproxy.com/"
)

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

candidate_urls() {
  local url="$1"
  local mirror

  printf '%s\n' "$url"

  if [ -n "${QULV_GITHUB_MIRROR_PREFIX:-}" ]; then
    mirror="${QULV_GITHUB_MIRROR_PREFIX%/}/"
    printf '%s%s\n' "$mirror" "$url"
  fi

  if [ -n "${QULV_GITHUB_MIRRORS:-}" ]; then
    local old_ifs="$IFS"
    IFS=', '
    for mirror in $QULV_GITHUB_MIRRORS; do
      [ -n "$mirror" ] || continue
      mirror="${mirror%/}/"
      printf '%s%s\n' "$mirror" "$url"
    done
    IFS="$old_ifs"
  fi

  for mirror in "${DEFAULT_MIRRORS[@]}"; do
    printf '%s%s\n' "$mirror" "$url"
  done
}

download_with_fallback() {
  local label="$1"
  local url="$2"
  local output="$3"
  local max_time="${4:-1800}"
  local tmp="${output}.download"
  local candidate

  rm -f "$tmp"
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    echo "下载 $label: $candidate"
    if curl -fL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time "$max_time" "$candidate" -o "$tmp"; then
      mv "$tmp" "$output"
      return 0
    fi
    rm -f "$tmp"
    echo "$label 下载失败，切换下一个来源。"
  done < <(candidate_urls "$url")

  echo "$label 所有下载来源都失败。"
  return 1
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual

  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "SHA256 校验失败：$file"
    echo "期望: $expected"
    echo "实际: $actual"
    return 1
  fi

  echo "SHA256 校验通过：$(basename "$file")"
}

install_macos() {
  local tmp_dir package_url

  tmp_dir="$(mktemp -d "/tmp/qulv-agent-obsidian-install.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  echo ""
  echo "============================================================"
  echo "  曲率 AI · Mac 一键安装下载器"
  echo "============================================================"
  echo ""
  echo "当前版本: $RELEASE_TAG"
  echo "下载目录: $MAC_DIR"
  echo "官方源优先；如果 GitHub 访问失败，会自动尝试备用镜像。"
  echo "安装包下载后会做 SHA256 校验，校验失败不会继续安装。"

  log "下载完整 Mac 安装包"
  package_url="https://github.com/$REPO/releases/download/$RELEASE_TAG/$MAC_ASSET"
  download_with_fallback "$MAC_ASSET" "$package_url" "$tmp_dir/$MAC_ASSET" 2400
  verify_sha256 "$tmp_dir/$MAC_ASSET" "$MAC_SHA256"

  log "解压到本机下载目录"
  rm -rf "$MAC_DIR"
  ditto -x -k "$tmp_dir/$MAC_ASSET" "$HOME/Downloads"
  xattr -dr com.apple.quarantine "$MAC_DIR" 2>/dev/null || true

  if [ ! -f "$MAC_DIR/复制到终端运行.txt" ]; then
    echo "缺少：$MAC_DIR/复制到终端运行.txt"
    exit 1
  fi

  if [ ! -f "$MAC_DIR/Agent-Obsidian-install-Mac.zip" ]; then
    echo "缺少：$MAC_DIR/Agent-Obsidian-install-Mac.zip"
    exit 1
  fi

  log "打开安装终端窗口"
  bash "$MAC_DIR/复制到终端运行.txt"
}

main() {
  case "$(uname -s)" in
    Darwin)
      install_macos
      ;;
    Linux)
      echo "当前 release 暂未发布 Linux 安装包。请等待 Linux 版本发布后再运行。"
      exit 1
      ;;
    *)
      echo "当前脚本用于 macOS/Linux 终端。Windows 请在 PowerShell 里运行 install.ps1 一行命令。"
      exit 1
      ;;
  esac
}

main "$@"
