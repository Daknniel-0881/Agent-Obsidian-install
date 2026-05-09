@echo off
REM =============================================================================
REM install-windows.bat · Windows 双击入口
REM =============================================================================
REM 客户右键"以管理员身份运行"即触发安装流程，
REM 自动调用上一层 scripts/bootstrap.ps1 主脚本。
REM 装完后保持窗口不关闭，让客户看到完整日志和待办清单。
REM =============================================================================

REM 切到 UTF-8 代码页，避免中文乱码
chcp 65001 >nul 2>&1

REM 切到 .bat 所在目录（双击时 PWD 可能在别处）
cd /d "%~dp0"

REM 自检管理员权限（winget / npm install -g 需要）
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo ===============================================
    echo   警告: 当前不是管理员模式
    echo   建议右键此文件 -^> 以管理员身份运行
    echo ===============================================
    echo.
    pause
)

REM 调用 PowerShell 主脚本（用 -ExecutionPolicy Bypass 绕过策略）
REM 透传所有 .bat 参数给 ps1（如 --offline / --pkg-dir 等价的 -Offline / -PkgDir）
REM 主脚本位于上一层 scripts/ 目录
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\bootstrap.ps1" %*
set INSTALL_EXIT=%errorLevel%

echo.
echo ===============================================
if %INSTALL_EXIT% EQU 0 (
    echo   [OK] 安装流程结束（退出码 0）
) else (
    echo   [FAIL] 安装中断（退出码 %INSTALL_EXIT%）
    echo   请查看上方红色错误信息，对照【安装失败常见问题.txt】
)
echo ===============================================
echo.

REM 保留窗口，让客户看完日志
pause
exit /b %INSTALL_EXIT%
