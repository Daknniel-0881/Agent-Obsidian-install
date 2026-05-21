# Release Notes

## v2026.05.21.18

- 发布当前测试稳定的 macOS 安装包：`Agent-Obsidian-install-Mac.zip`。
- 发布当前测试稳定的 Windows 安装包：`Agent-Obsidian-install-Windows-final-20260521.18.zip`。
- 新增仓库级一键入口：
  - `install.sh`：macOS/Linux shell 入口，当前 release 支持 macOS。
  - `install.ps1`：Windows PowerShell 入口。
  - `install-mac-from-github.sh`：保留旧 Mac 文档入口的兼容文件。
- 一键入口默认先走 GitHub 官方 release，失败后自动尝试备用镜像。
- 大文件下载后会做 SHA256 校验，校验失败会停止安装。
- 仓库保留 `Mac系统`、`Windows系统` 的轻量说明和入口文件，大体积安装包统一放在 GitHub Release 资产里。

## v2026.05.13.1-mac

- Mac 安装脚本更新到 2026-05-13.1。
- 新增 HyperFrames、企业微信 CLI、MarkItDown、yt-dlp、FFmpeg、any2pdf 依赖的检测和安装。
- 扩展随包 Skills，移除 wechat-cli。
- CLAUDE.md 只刷新全局托管区块，不再重复创建 Bridge/CLAUDE.md。
- 大体积安装包 zip 放在 GitHub Release 资产中，仓库保留一键拉取脚本和说明。
