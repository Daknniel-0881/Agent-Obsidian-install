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
#   2. 四级查找完整安装包：
#      ① ~\Downloads\自动部署脚本\               （已解压目录，优先）
#      ② ~\Downloads\自动部署脚本-Win.zip         （分平台压缩包，自动解压）
#      ③ GitHub Release 自动下载分平台 zip       （含离线包，~680MB）
#      ④ git clone GitHub 仓库                   （最后兜底，不含离线包）
#   3. 调用 scripts/bootstrap.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

# 强制 UTF-8 输出，避免中文乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoOwner     = "Daknniel-0881"
$RepoName      = "Agent-Obsidian-install"
$RepoUrl       = "https://github.com/$RepoOwner/$RepoName.git"
$RepoBranch    = "main"
$ReleaseBase   = "https://github.com/$RepoOwner/$RepoName/releases/latest/download"
$DistName      = "自动部署脚本"
$ZipPlatform   = "Win"
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
  Write-Log "目标分平台 zip: $DistName-$ZipPlatform.zip"
}

# 解压 zip 到 $DownloadsDir，并归一化目录名为 $TargetDir
function Expand-DistZip {
  param([string]$Zip)
  Write-Log "解压到: $DownloadsDir\"
  try {
    Expand-Archive -Path $Zip -DestinationPath $DownloadsDir -Force
  } catch {
    Fail "解压失败: $_"
  }
  # 归一化目录名（GitHub source zip 通常解压成 <repo>-main/）
  $maybeRoot = Join-Path $DownloadsDir "Agent-Obsidian-install-main"
  if ((Test-Path $maybeRoot) -and (-not (Test-Path $TargetDir))) {
    Move-Item $maybeRoot $TargetDir
  }
  if (-not (Test-Path (Join-Path $TargetDir "scripts"))) {
    Fail "解压后未找到 scripts/ 目录，zip 可能损坏"
  }
}

# 从 GitHub Release 下载分平台 zip
# Release asset 用 ASCII 名（GitHub 不支持非 ASCII 文件名）
# 本地输出仍用中文名（便于客户辨识）
function Get-FromRelease {
  $releaseAsset = "Agent-Obsidian-install-$ZipPlatform.zip"
  $localName    = "$DistName-$ZipPlatform.zip"
  $url          = "$ReleaseBase/$releaseAsset"
  $out          = Join-Path $DownloadsDir $localName
  Write-Log "[路径③] 从 GitHub Release 下载: $releaseAsset"
  Write-Log "URL: $url"
  Write-Log "（首次下载约 680MB，含完整离线安装包，请耐心等待）"
  try {
    # 强制 TLS 1.2，老 Win10 默认 TLS 1.0/1.1 会失败
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
  } catch {
    if (Test-Path $out) { Remove-Item $out -Force }
    Write-Log "下载失败: $_"
    return $false
  }
  Expand-DistZip -Zip $out
  Write-Log "Release 下载 + 解压完成"
  return $true
}

# 四级回退查找/获取分发包
function Find-Or-FetchDist {
  # ① 已解压目录
  if (Test-Path (Join-Path $TargetDir "scripts")) {
    Write-Log "[路径①] 找到已解压目录: $TargetDir"
    return
  }

  # ② 找本地 zip（分平台优先 → 通用 fallback）
  $zipCandidates = @(
    Join-Path $DownloadsDir "$DistName-$ZipPlatform.zip"
    Join-Path $DownloadsDir "$DistName-$($ZipPlatform.ToLower()).zip"
    Join-Path $DownloadsDir "$DistName.zip"
    Join-Path $DownloadsDir "Agent-Obsidian-install.zip"
    Join-Path $DownloadsDir "agent-obsidian-install.zip"
  )
  foreach ($zip in $zipCandidates) {
    if (Test-Path $zip) {
      Write-Log "[路径②] 找到本地压缩包: $zip"
      Expand-DistZip -Zip $zip
      return
    }
  }

  # ③ 从 GitHub Release 下载分平台 zip
  if (Get-FromRelease) {
    return
  }
  Write-Log "Release 下载失败，回退到 git clone..."

  # ④ git clone 最后兜底
  Write-Log "[路径④] 从 GitHub 克隆仓库..."
  $hasGit = Get-Command git -ErrorAction SilentlyContinue
  if (-not $hasGit) {
    Fail "未安装 git 也下载不到 Release zip。请检查网络或手动下载 zip 到 $DownloadsDir\"
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
