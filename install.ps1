# =============================================================================
# install.ps1 · Windows 远程一行命令入口
# =============================================================================
# 业界标准的"一行命令"安装入口
# 客户在 PowerShell 粘贴下面这条命令即可触发完整安装：
#
#   irm https://raw.githubusercontent.com/Daknniel-0881/Agent-Obsidian-install/main/install.ps1 | iex
#
# 自动行为：
#   1. 探测架构（ARM64 / x64）
#   2. 三级查找完整安装包：
#      ① ~\Downloads\自动部署脚本\   （已解压目录，优先）
#      ② ~\Downloads\自动部署脚本.zip （压缩包，自动解压）
#      ③ git clone GitHub 仓库       （兜底，无离线包）
#   3. 调用 scripts/bootstrap.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

# 强制 UTF-8 输出，避免中文乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoUrl       = "https://github.com/Daknniel-0881/Agent-Obsidian-install.git"
$RepoBranch    = "main"
$DistName      = "自动部署脚本"
$DownloadsDir  = if ($env:DOWNLOADS_DIR) { $env:DOWNLOADS_DIR } else { Join-Path $HOME "Downloads" }
$TargetDir     = Join-Path $DownloadsDir $DistName

function Write-Banner {
  Write-Host ""
  Write-Host "============================================================"
  Write-Host "  曲率 AI · Agent-Obsidian-install"
  Write-Host "  跨平台一键部署 · Agent + 知识库 + 自动化"
  Write-Host "============================================================"
  Write-Host ""
}

function Write-Log {
  param([string]$Msg)
  Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Msg"
}

function Fail {
  param([string]$Msg)
  Write-Host "[ERROR] $Msg" -ForegroundColor Red
  exit 1
}

# 探测架构
function Get-SystemInfo {
  $arch = $env:PROCESSOR_ARCHITECTURE
  switch ($arch) {
    "AMD64" { $script:ArchLabel = "x64" }
    "ARM64" { $script:ArchLabel = "ARM64" }
    "x86"   { $script:ArchLabel = "x86 (不推荐，建议 64 位系统)" }
    default { $script:ArchLabel = "$arch（未识别）" }
  }
  Write-Log "检测系统: Windows / $ArchLabel"
}

# 三级回退查找/获取分发包
function Find-Or-FetchDist {
  # ① 已解压目录
  if (Test-Path (Join-Path $TargetDir "scripts")) {
    Write-Log "[路径①] 找到已解压目录: $TargetDir"
    return
  }

  # ② 找 zip 解压
  $zipCandidates = @(
    Join-Path $DownloadsDir "$DistName.zip"
    Join-Path $DownloadsDir "Agent-Obsidian-install.zip"
    Join-Path $DownloadsDir "agent-obsidian-install.zip"
  )
  foreach ($zip in $zipCandidates) {
    if (Test-Path $zip) {
      Write-Log "[路径②] 找到压缩包: $zip"
      Write-Log "解压到: $DownloadsDir\"
      try {
        Expand-Archive -Path $zip -DestinationPath $DownloadsDir -Force
      } catch {
        Fail "解压失败: $_"
      }
      # 归一化目录名（GitHub zip 通常解压成 <repo>-main/）
      $maybeRoot = Join-Path $DownloadsDir "Agent-Obsidian-install-main"
      if ((Test-Path $maybeRoot) -and (-not (Test-Path $TargetDir))) {
        Move-Item $maybeRoot $TargetDir
      }
      if (Test-Path (Join-Path $TargetDir "scripts")) { return }
      Fail "解压后未找到 scripts/ 目录，zip 可能损坏"
    }
  }

  # ③ git clone 兜底
  Write-Log "[路径③] 本地未找到分发包，从 GitHub 克隆..."
  $hasGit = Get-Command git -ErrorAction SilentlyContinue
  if (-not $hasGit) {
    Fail "未安装 git，无法 clone。请先下载 zip 到 $DownloadsDir\ 再重试，或先用 winget install Git.Git 安装 git"
  }
  & git clone --depth 1 -b $RepoBranch $RepoUrl $TargetDir
  if ($LASTEXITCODE -ne 0) {
    Fail "git clone 失败，请检查网络（或手动下载 zip 放到 $DownloadsDir\）"
  }
  Write-Log "克隆完成: $TargetDir"
  Write-Log "注意: git clone 不含 离线安装包/ 目录（仓库忽略了 *.dmg/*.exe/*.deb），脚本会回退在线下载"
}

# 主流程
function Main {
  Write-Banner
  Get-SystemInfo
  Find-Or-FetchDist

  $bootstrap = Join-Path $TargetDir "scripts\bootstrap.ps1"
  if (-not (Test-Path $bootstrap)) {
    Fail "未找到主脚本: $bootstrap"
  }

  Write-Log "调用安装主脚本: $bootstrap"
  Write-Host ""
  # 透传所有参数（远程 iex 调用时无参数；如需带参，需先下载到本地再跑）
  & powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrap @args
  exit $LASTEXITCODE
}

Main @args
