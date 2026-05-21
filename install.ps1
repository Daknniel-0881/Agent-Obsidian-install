param(
  [string]$ReleaseTag = "v2026.05.21.20",
  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

$Repo = "Daknniel-0881/qulv-agent-obsidian-install"
$WindowsAsset = "Agent-Obsidian-install-Windows-final-20260521.18.zip"
$WindowsSha256 = "6b6003d3d2c28871cbe77b7b0d83696a9ac906af682587c4007b6f679c94971d"
$DefaultMirrors = @(
  "https://gh.llkk.cc/",
  "https://gh-proxy.com/",
  "https://mirror.ghproxy.com/"
)

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Get-CandidateUrls {
  param([string]$Url)

  $urls = New-Object System.Collections.Generic.List[string]
  $urls.Add($Url) | Out-Null

  if ($env:QULV_GITHUB_MIRROR_PREFIX) {
    $prefix = $env:QULV_GITHUB_MIRROR_PREFIX.TrimEnd("/") + "/"
    $urls.Add($prefix + $Url) | Out-Null
  }

  if ($env:QULV_GITHUB_MIRRORS) {
    foreach ($prefixRaw in ($env:QULV_GITHUB_MIRRORS -split "[, ]+")) {
      if ([string]::IsNullOrWhiteSpace($prefixRaw)) { continue }
      $prefix = $prefixRaw.TrimEnd("/") + "/"
      $urls.Add($prefix + $Url) | Out-Null
    }
  }

  foreach ($prefixRaw in $DefaultMirrors) {
    $prefix = $prefixRaw.TrimEnd("/") + "/"
    $urls.Add($prefix + $Url) | Out-Null
  }

  return $urls
}

function Download-WithFallback {
  param(
    [string]$Label,
    [string]$Url,
    [string]$OutputPath
  )

  $tmp = "$OutputPath.download"
  if (Test-Path -LiteralPath $tmp) {
    Remove-Item -LiteralPath $tmp -Force
  }

  foreach ($candidate in (Get-CandidateUrls -Url $Url)) {
    try {
      Write-Host "下载 $Label: $candidate"
      Invoke-WebRequest -UseBasicParsing -Uri $candidate -OutFile $tmp -TimeoutSec 1800
      Move-Item -LiteralPath $tmp -Destination $OutputPath -Force
      return
    } catch {
      if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Force
      }
      Write-Host "$Label 下载失败，切换下一个来源。"
    }
  }

  throw "$Label 所有下载来源都失败。"
}

function Assert-Sha256 {
  param(
    [string]$Path,
    [string]$Expected
  )

  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "SHA256 校验失败：$Path`n期望: $Expected`n实际: $actual"
  }
  Write-Host "SHA256 校验通过：$(Split-Path -Leaf $Path)"
}

function Install-Windows {
  $userProfile = [Environment]::GetFolderPath("UserProfile")
  $downloadRoot = Join-Path $userProfile "Downloads"
  $windowsDir = Join-Path $downloadRoot "Windows系统"
  $assetPath = Join-Path $windowsDir $WindowsAsset
  $assetUrl = "https://github.com/$Repo/releases/download/$ReleaseTag/$WindowsAsset"

  Write-Host ""
  Write-Host "============================================================"
  Write-Host "  曲率 AI · Windows 一键安装下载器"
  Write-Host "============================================================"
  Write-Host ""
  Write-Host "当前版本: $ReleaseTag"
  Write-Host "下载目录: $windowsDir"
  Write-Host "官方源优先；如果 GitHub 访问失败，会自动尝试备用镜像。"
  Write-Host "安装包下载后会做 SHA256 校验，校验失败不会继续安装。"

  New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null

  Write-Step "下载 Windows 安装包"
  Download-WithFallback -Label $WindowsAsset -Url $assetUrl -OutputPath $assetPath
  Assert-Sha256 -Path $assetPath -Expected $WindowsSha256

  Write-Step "解压 Windows 安装包"
  Expand-Archive -LiteralPath $assetPath -DestinationPath $windowsDir -Force

  $bat = Join-Path $windowsDir "启动.bat"
  if (-not (Test-Path -LiteralPath $bat)) {
    throw "没有找到启动文件：$bat"
  }

  Write-Step "启动安装窗口"
  Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$bat`"") -WorkingDirectory $windowsDir -Wait
}

if ($env:OS -ne "Windows_NT") {
  Write-Host "当前 install.ps1 主要用于 Windows PowerShell。"
  Write-Host "macOS 请在终端运行：/bin/bash -c `"`$(curl -fsSL https://raw.githubusercontent.com/$Repo/main/install.sh)`""
  exit 1
}

Install-Windows
