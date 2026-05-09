param(
  [switch]$ChinaMirror,
  [switch]$DryRun,
  [string]$PackagesDir = "",
  [bool]$KeepAwake = $true,
  [switch]$ForceSkills
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Watermark = if ($env:WATERMARK) { $env:WATERMARK } else { "曲率 AI · Agent-Obsidian-install" }
$LogDir = Join-Path $RootDir "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir ("install-windows-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Start-Transcript -Path $LogFile -Append | Out-Null

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "[$(Get-Date -Format HH:mm:ss)] $Message" -ForegroundColor Cyan
}

function Write-Watermark {
  Write-Host ""
  Write-Host "============================================================"
  Write-Host "  $Watermark"
  Write-Host "  Agent + Obsidian + Automation deployment"
  Write-Host "============================================================"
  Write-Host ""
}

function Invoke-CommandStep {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList = @()
  )

  if ($DryRun) {
    Write-Host "+ $FilePath $($ArgumentList -join ' ')"
    return
  }

  & $FilePath @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FilePath $($ArgumentList -join ' ')"
  }
}

function Test-PackageDir {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  return (
    (Test-Path -LiteralPath (Join-Path $Path "Mac系统")) -or
    (Test-Path -LiteralPath (Join-Path $Path "Win系统")) -or
    (Test-Path -LiteralPath (Join-Path $Path "Linux系统"))
  )
}

function Resolve-PackagesDir {
  $candidates = New-Object System.Collections.Generic.List[string]

  if (-not [string]::IsNullOrWhiteSpace($PackagesDir)) {
    $candidates.Add($PackagesDir)
  }

  $candidates.Add((Join-Path $RootDir "自动部署脚本"))
  $candidates.Add((Join-Path $RootDir "packages\自动部署脚本"))
  $candidates.Add((Join-Path $env:USERPROFILE "Downloads\自动部署脚本"))
  $candidates.Add((Join-Path $env:USERPROFILE "Download\自动部署脚本"))
  $candidates.Add("C:\自动部署脚本")
  $candidates.Add("C:\Downloads\自动部署脚本")
  $candidates.Add("D:\自动部署脚本")
  $candidates.Add("D:\Downloads\自动部署脚本")

  $usersRoot = "C:\Users"
  if (Test-Path -LiteralPath $usersRoot) {
    Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $candidates.Add((Join-Path $_.FullName "Downloads\自动部署脚本"))
      $candidates.Add((Join-Path $_.FullName "Download\自动部署脚本"))
    }
  }

  foreach ($candidate in $candidates) {
    if (Test-PackageDir -Path $candidate) {
      return $candidate
    }
  }

  return $null
}

function Find-OfflineFile {
  param([string[]]$Patterns)

  $offlineRoot = Join-Path $script:ResolvedPackagesDir "离线安装包"
  if (-not (Test-Path -LiteralPath $offlineRoot)) {
    return $null
  }

  foreach ($pattern in $Patterns) {
    $match = Get-ChildItem -LiteralPath $offlineRoot -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
      Sort-Object FullName |
      Select-Object -First 1
    if ($match) {
      return $match.FullName
    }
  }

  return $null
}

function Require-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Install-WingetPackage {
  param(
    [string]$Id,
    [string]$Name
  )

  Write-Step "Installing $Name"
  if ($DryRun) {
    Write-Host "+ winget install --id $Id -e --accept-package-agreements --accept-source-agreements"
    return
  }

  winget install --id $Id -e --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    throw "winget failed while installing $Name"
  }
}

function Install-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Step "Git is already available"
    return
  }

  $offlineGit = Find-OfflineFile -Patterns @("Git-*.exe")
  if ($offlineGit) {
    Write-Step "Installing offline Git from $offlineGit"
    if ($DryRun) {
      Write-Host "+ Start-Process $offlineGit /VERYSILENT /NORESTART -Wait"
      return
    }
    Start-Process -FilePath $offlineGit -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    return
  }

  Install-WingetPackage -Id "Git.Git" -Name "Git"
}

function Install-Node {
  if ((Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Step "Node.js and npm are already available"
    return
  }

  $offlineNode = Find-OfflineFile -Patterns @("node-v*-x64.msi", "node-*-x64.msi")
  if ($offlineNode) {
    Write-Step "Installing offline Node.js from $offlineNode"
    if ($DryRun) {
      Write-Host "+ msiexec /i $offlineNode /qn /norestart"
      return
    }
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$offlineNode`"", "/qn", "/norestart" -Wait
    return
  }

  Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
}

function Refresh-Path {
  $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machinePath;$userPath"
}

function Install-NpmGlobal {
  param([string]$PackageName)

  $offlinePackage = $null
  if ($PackageName -eq "@anthropic-ai/claude-code") {
    $offlinePackage = Find-OfflineFile -Patterns @("anthropic-ai-claude-code-*.tgz", "claude-code-*.tgz")
  } elseif ($PackageName -eq "@larksuite/cli") {
    $offlinePackage = Find-OfflineFile -Patterns @("larksuite-cli-*.tgz", "lark-cli-*.tgz")
  }

  if ($offlinePackage) {
    Write-Step "Installing offline npm package $PackageName from $offlinePackage"
    Invoke-CommandStep -FilePath "npm" -ArgumentList @("install", "-g", $offlinePackage)
    return
  }

  $args = @("install", "-g", $PackageName)
  if ($ChinaMirror) {
    $args += "--registry=https://registry.npmmirror.com"
  }

  Write-Step "Installing npm package $PackageName"
  Invoke-CommandStep -FilePath "npm" -ArgumentList $args
}

function Install-LocalExe {
  param(
    [string]$Path,
    [string]$Name
  )

  Require-File -Path $Path
  Write-Step "Installing $Name from $Path"

  if ($DryRun) {
    Write-Host "+ Start-Process $Path /S -Wait"
    return
  }

  $process = Start-Process -FilePath $Path -ArgumentList "/S" -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    Write-Warning "$Name silent install returned exit code $($process.ExitCode). Retrying interactively."
    Start-Process -FilePath $Path -Wait
  }
}

function Get-DefaultWorkRoot {
  if (Test-Path "D:\") {
    return "D:\CodePilot"
  }
  return (Join-Path $env:USERPROFILE "Desktop\CodePilot")
}

function Render-ClaudeMemory {
  param(
    [string]$BridgeDir,
    [string]$VaultDir
  )

  Write-Step "Writing CLAUDE.md"
  $templatePath = Join-Path $RootDir "templates\CLAUDE.md"
  $content = Get-Content -LiteralPath $templatePath -Raw
  $content = $content.Replace("__VAULT_PATH__", $VaultDir)
  $content = $content.Replace("__BRIDGE_PATH__", $BridgeDir)

  if ($DryRun) {
    Write-Host "+ Write $BridgeDir\CLAUDE.md"
    Write-Host "+ Append marked block to $env:USERPROFILE\.claude\CLAUDE.md"
    return
  }

  New-Item -ItemType Directory -Force -Path $BridgeDir | Out-Null
  New-Item -ItemType Directory -Force -Path $VaultDir | Out-Null
  Set-Content -LiteralPath (Join-Path $BridgeDir "CLAUDE.md") -Value $content -Encoding UTF8

  $claudeDir = Join-Path $env:USERPROFILE ".claude"
  New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
  $globalClaude = Join-Path $claudeDir "CLAUDE.md"
  $existing = ""
  if (Test-Path -LiteralPath $globalClaude) {
    $existing = Get-Content -LiteralPath $globalClaude -Raw
  }

  if ($existing -notmatch "BEGIN CODEPILOT KB DEFAULTS") {
    Add-Content -LiteralPath $globalClaude -Value "`n<!-- BEGIN CODEPILOT KB DEFAULTS -->`n$content`n<!-- END CODEPILOT KB DEFAULTS -->" -Encoding UTF8
  }
}

function Install-BundledSkills {
  $srcDir = Join-Path $RootDir "payload\skills"
  $dstDir = Join-Path $env:USERPROFILE ".claude\skills"

  Write-Step "Installing bundled skills"

  if ($DryRun) {
    Write-Host "+ Copy bundled skills from $srcDir to $dstDir"
    return
  }

  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  if (-not (Test-Path -LiteralPath $srcDir)) {
    Write-Warning "No bundled skills found at $srcDir"
    return
  }

  foreach ($skill in Get-ChildItem -LiteralPath $srcDir -Directory) {
    $target = Join-Path $dstDir $skill.Name
    if ((Test-Path -LiteralPath $target) -and (-not $ForceSkills)) {
      Write-Host "Skill exists, skipping: $($skill.Name)"
      continue
    }
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath $target -Recurse -Force
    }
    Copy-Item -LiteralPath $skill.FullName -Destination $target -Recurse
    Write-Host "Installed skill: $($skill.Name)"
  }
}

function Configure-Power {
  if (-not $KeepAwake) {
    return
  }

  Write-Step "Configuring Windows power settings to stay awake"
  if ($DryRun) {
    Write-Host "+ powercfg /change standby-timeout-ac 0"
    Write-Host "+ powercfg /change hibernate-timeout-ac 0"
    Write-Host "+ powercfg /change monitor-timeout-ac 0"
    Write-Host "+ powercfg /change standby-timeout-dc 0"
    Write-Host "+ powercfg /change hibernate-timeout-dc 0"
    return
  }

  powercfg /change standby-timeout-ac 0
  powercfg /change hibernate-timeout-ac 0
  powercfg /change monitor-timeout-ac 0
  powercfg /change standby-timeout-dc 0
  powercfg /change hibernate-timeout-dc 0
}

function Print-ManualSteps {
  param(
    [string]$BridgeDir,
    [string]$VaultDir
  )

  Write-Host ""
  Write-Host "================ 待手工操作清单 ================"
  Write-Host ""
  Write-Host "1. 打开 CodePilot 客户端，并手动配置服务商（脚本不预填）："
  Write-Host "   左下角【设置】 -> 【服务商】 -> 选择类型 -> 粘贴客户的 API Key -> 保存并测试连通性。"
  Write-Host ""
  Write-Host "2. 如果 Windows SmartScreen 拦截：点击【更多信息】 -> 【仍要运行】。"
  Write-Host ""
  Write-Host "3. 打开 Obsidian 客户端，并选择本机 Vault 目录："
  Write-Host "   $VaultDir"
  Write-Host ""
  Write-Host "4. 启用 Obsidian CLI："
  Write-Host "   Obsidian -> 设置 -> 关于/通用 -> 高级 -> 命令行接口 -> 点击【注册】。"
  Write-Host "   完成后在 PowerShell 里验证："
  Write-Host "     obsidian help"
  Write-Host ""
  Write-Host "5. 在 CodePilot 里打开工作区目录："
  Write-Host "   $BridgeDir"
  Write-Host ""
  Write-Host "6. 飞书 CLI 仅完成安装，未预填任何 app_id / app_secret / token。"
  Write-Host "   客户准备好后再自己授权："
  Write-Host "     lark-cli config init --new"
  Write-Host ""
  Write-Host "完整清单见："
  Write-Host "   $(Join-Path $RootDir 'templates\MANUAL_STEPS.md')"
  Write-Host ""
  Write-Host "================================================"
  Write-Host ""
}

function Main {
  Write-Watermark
  Write-Step "Starting Windows deployment"

  $script:ResolvedPackagesDir = Resolve-PackagesDir
  if (-not $script:ResolvedPackagesDir) {
    throw "Package directory not found. Put the full installer folder named 自动部署脚本 under Downloads or C:\, or pass -PackagesDir."
  }
  Write-Host "Using package directory: $script:ResolvedPackagesDir"

  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

  Install-Git
  Install-Node
  Refresh-Path

  Install-NpmGlobal -PackageName "@anthropic-ai/claude-code"
  Install-NpmGlobal -PackageName "@larksuite/cli"

  Install-LocalExe -Path (Join-Path $script:ResolvedPackagesDir "Win系统\CodePilot.Setup.0.54.0.exe") -Name "CodePilot"
  Install-LocalExe -Path (Join-Path $script:ResolvedPackagesDir "Win系统\Obsidian-1.12.7.exe") -Name "Obsidian"

  $workRoot = Get-DefaultWorkRoot
  $bridgeDir = Join-Path $workRoot "Bridge"
  $vaultDir = Join-Path $workRoot "Obsidian\ClaudeCode"

  Render-ClaudeMemory -BridgeDir $bridgeDir -VaultDir $vaultDir
  Install-BundledSkills
  Configure-Power

  Print-ManualSteps -BridgeDir $bridgeDir -VaultDir $vaultDir
  Write-Host "安装日志: $LogFile"
}

function Send-Telemetry {
  # 失败回传:从 manifest.json 读 telemetry.webhook,启用时 POST 脱敏摘要(飞书自定义机器人格式)
  # 不阻塞主流程,任何异常都被吞掉
  param(
    [string]$Message
  )
  try {
    $manifestPath = Join-Path $RootDir "manifest.json"
    if (-not (Test-Path $manifestPath)) { return }
    $m = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
    if (-not $m.telemetry) { return }
    if (-not $m.telemetry.enabled) { return }
    if ([string]::IsNullOrWhiteSpace($m.telemetry.webhook)) { return }

    $arch = $env:PROCESSOR_ARCHITECTURE
    $osVer = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    if (-not $osVer) { $osVer = "Windows" }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $text = "OS: $osVer $arch / 错误: $Message / 时间: $ts"

    $payload = @{
      msg_type = "post"
      content  = @{
        post = @{
          zh_cn = @{
            title   = "Agent-Obsidian-install 安装失败"
            content = @(, @(@{ tag = "text"; text = $text }))
          }
        }
      }
    } | ConvertTo-Json -Depth 8 -Compress

    Invoke-RestMethod -Method Post -Uri $m.telemetry.webhook -ContentType 'application/json; charset=utf-8' -Body $payload -TimeoutSec 5 | Out-Null
    Write-Host "  (failure telemetry sent)"
  } catch {
    # 静默吞错,不阻塞主流程
  }
}

try {
  Main
} catch {
  $errMsg = $_.Exception.Message
  Write-Host ""
  Write-Host "安装失败: $errMsg" -ForegroundColor Red
  Write-Host "失败日志: $LogFile"
  Write-Host "请把这个日志文件回传给交付人员，用于定位客户电脑上的失败原因。"
  Send-Telemetry -Message $errMsg
  exit 1
} finally {
  try {
    Stop-Transcript | Out-Null
  } catch {
  }
}
