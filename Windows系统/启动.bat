@echo off
setlocal

cd /d "%~dp0"
set "ZIP_NAME=Agent-Obsidian-install-Windows.zip"
set "DISK_HELPER=%TEMP%\Agent-Obsidian-select-disk-%RANDOM%%RANDOM%.ps1"
set "CLEANUP_HELPER=%TEMP%\Agent-Obsidian-cleanup-%RANDOM%%RANDOM%.ps1"
set "WORK_BASE="

echo.
echo ============================================================
echo   Agent-Obsidian-install for Windows
echo ============================================================
echo.
echo Keep this window open. Installation progress will appear here.
echo Logs: %USERPROFILE%\Downloads\Agent-Obsidian-install-logs
echo.

if not exist "%ZIP_NAME%" (
  echo Missing package: %ZIP_NAME%
  echo Please keep this batch file and %ZIP_NAME% in the same folder.
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)

> "%DISK_HELPER%" echo $ErrorActionPreference = 'SilentlyContinue'
>> "%DISK_HELPER%" echo $letters = New-Object System.Collections.Generic.List[string]
>> "%DISK_HELPER%" echo function Add-Letter { param([string]$letter) if ([string]::IsNullOrWhiteSpace($letter)) { return }; $n = $letter.Trim().TrimEnd('\').ToUpperInvariant(); foreach ($existing in $letters) { if ($existing.Equals($n, [StringComparison]::OrdinalIgnoreCase)) { return } }; [void]$letters.Add($n) }
>> "%DISK_HELPER%" echo foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2')) { Add-Letter $d.DeviceID }
>> "%DISK_HELPER%" echo try { foreach ($disk in @(Get-CimInstance Win32_DiskDrive)) { if (($disk.InterfaceType -eq 'USB') -or ($disk.PNPDeviceID -match '^USB') -or ($disk.MediaType -match 'Removable')) { foreach ($partition in @(Get-CimAssociatedInstance -InputObject $disk -Association Win32_DiskDriveToDiskPartition)) { foreach ($logicalDisk in @(Get-CimAssociatedInstance -InputObject $partition -Association Win32_LogicalDiskToPartition)) { Add-Letter $logicalDisk.DeviceID } } } } } catch {}
>> "%DISK_HELPER%" echo $best = $null
>> "%DISK_HELPER%" echo foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) { if ($null -eq $d.FreeSpace) { continue }; $id = $d.DeviceID.Trim().ToUpperInvariant(); if ($letters -contains $id) { continue }; if (($null -eq $best) -or ([int64]$d.FreeSpace -gt [int64]$best.FreeSpace)) { $best = $d } }
>> "%DISK_HELPER%" echo if ($best) { $base = $best.DeviceID + '\Agent-Obsidian-Temp' } else { $base = Join-Path $env:TEMP 'Agent-Obsidian-Temp' }
>> "%DISK_HELPER%" echo try { [void](New-Item -ItemType Directory -Force -Path $base) } catch { $base = Join-Path $env:TEMP 'Agent-Obsidian-Temp'; [void](New-Item -ItemType Directory -Force -Path $base) }
>> "%DISK_HELPER%" echo $base

for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%DISK_HELPER%"`) do set "WORK_BASE=%%I"
if exist "%DISK_HELPER%" del /f /q "%DISK_HELPER%" >nul 2>nul
if "%WORK_BASE%"=="" set "WORK_BASE=%TEMP%\Agent-Obsidian-Temp"
set "WORK_DIR=%WORK_BASE%\Agent-Obsidian-install-Windows-%RANDOM%%RANDOM%"

mkdir "%WORK_DIR%" >nul 2>nul
echo Temporary extraction: %WORK_DIR%
echo Extracting installer package...
where tar.exe >nul 2>nul
if "%ERRORLEVEL%"=="0" (
  tar.exe -xf "%CD%\%ZIP_NAME%" -C "%WORK_DIR%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%CD%\%ZIP_NAME%' -DestinationPath '%WORK_DIR%' -Force"
)
if errorlevel 1 (
  echo Package extraction failed.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)

if not exist "%WORK_DIR%\install\install-windows.ps1" (
  echo install\install-windows.ps1 was not found after extraction.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)
if not exist "%WORK_DIR%\templates\CLAUDE.md" (
  echo templates\CLAUDE.md was not found after extraction.
  echo Package extraction was incomplete. Please move the package to a shorter path and run again.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)
if not exist "%WORK_DIR%\payload\skills" (
  echo payload\skills was not found after extraction.
  echo Package extraction was incomplete. Please move the package to a shorter path and run again.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)
if not exist "%WORK_DIR%\payload\tools" (
  echo payload\tools was not found after extraction.
  echo Package extraction was incomplete. Please move the package to a shorter path and run again.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)
if not exist "%WORK_DIR%\apps" (
  echo apps was not found after extraction.
  echo Package extraction was incomplete. Please move the package to a shorter path and run again.
  if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>nul
  if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%WORK_DIR%\install\install-windows.ps1"
set "INSTALL_EXIT=%ERRORLEVEL%"
cd /d "%USERPROFILE%" >nul 2>nul

> "%CLEANUP_HELPER%" echo param([string]$WorkDir, [string]$WorkBase)
>> "%CLEANUP_HELPER%" echo $ErrorActionPreference = 'SilentlyContinue'
>> "%CLEANUP_HELPER%" echo function Remove-WithRetry { param([string]$Path) if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $true }; for ($i = 1; $i -le 8; $i++) { try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop; return $true } catch { Start-Sleep -Seconds 1 } }; return $false }
>> "%CLEANUP_HELPER%" echo $ok = Remove-WithRetry -Path $WorkDir
>> "%CLEANUP_HELPER%" echo if ($ok) { Write-Host "Temporary extraction cleaned: $WorkDir" } else { Write-Host "Temporary extraction still locked, please delete later: $WorkDir" }
>> "%CLEANUP_HELPER%" echo if (-not [string]::IsNullOrWhiteSpace($WorkBase) -and (Test-Path -LiteralPath $WorkBase)) { Get-ChildItem -LiteralPath $WorkBase -Directory -Filter 'Agent-Obsidian-install-Windows-*' ^| Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } ^| ForEach-Object { Remove-WithRetry -Path $_.FullName ^| Out-Null } }
>> "%CLEANUP_HELPER%" echo try { if ((Test-Path -LiteralPath $WorkBase) -and -not (Get-ChildItem -LiteralPath $WorkBase -Force)) { Remove-Item -LiteralPath $WorkBase -Force } } catch {}
powershell -NoProfile -ExecutionPolicy Bypass -File "%CLEANUP_HELPER%" -WorkDir "%WORK_DIR%" -WorkBase "%WORK_BASE%"
if exist "%CLEANUP_HELPER%" del /f /q "%CLEANUP_HELPER%" >nul 2>nul

echo.
echo ============================================================
if "%INSTALL_EXIT%"=="0" (
  echo   Installer finished
) else (
  echo   Installer stopped. Exit code: %INSTALL_EXIT%
)
echo ============================================================
echo.
echo Logs: %USERPROFILE%\Downloads\Agent-Obsidian-install-logs
if not "%AGENT_OBSIDIAN_NO_PAUSE%"=="1" pause
exit /b %INSTALL_EXIT%
