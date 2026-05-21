# qulv-agent-obsidian-install

「曲率 AI · Agent + Obsidian + 自动化环境」客户一键安装包。

当前 release 已发布：

- macOS：把安装包放到 `~/Downloads/Mac系统`，自动打开终端执行安装。
- Windows：把安装包放到 `Downloads\Windows系统`，自动解压并运行 `启动.bat`。

Linux 版本暂未发布到本仓库，后续测试稳定后再加入。

## 一条命令安装

macOS 用户打开系统自带「终端」，复制下面一整行并回车：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

Windows 用户打开 PowerShell，复制下面一整行并回车：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.ps1 | iex"
```

这两个入口都会识别当前系统并下载对应 release 资产。macOS 入口会下载完整的 `Agent-Obsidian-install-Mac-final-20260521.19.zip`，Windows 入口会下载 `Agent-Obsidian-install-Windows-final-20260521.18.zip`。

## 国内网络备用命令

如果 `raw.githubusercontent.com` 在国内网络下访问很慢，可以先用下面的镜像备用入口。镜像只用于拉取入口脚本和安装包，安装包下载后会做 SHA256 校验，校验失败会停止安装。

macOS：

```bash
/bin/bash -c "$(curl -fsSL https://gh.llkk.cc/https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://gh.llkk.cc/https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.ps1 | iex"
```

脚本内部下载大文件时会按这个顺序尝试：

1. GitHub 官方 release 地址
2. `QULV_GITHUB_MIRROR_PREFIX` 指定的自定义镜像
3. `QULV_GITHUB_MIRRORS` 指定的多个自定义镜像
4. 内置备用镜像：`gh.llkk.cc`、`gh-proxy.com`、`mirror.ghproxy.com`

如果你有自己的稳定镜像，可以这样临时指定：

```bash
QULV_GITHUB_MIRROR_PREFIX="https://你的镜像域名/" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Daknniel-0881/qulv-agent-obsidian-install/main/install.sh)"
```

## 手动下载

如果一条命令不可用，可以打开本仓库右侧 Releases，下载最新版本里的资源包：

- `Agent-Obsidian-install-Mac-final-20260521.19.zip`
- `Agent-Obsidian-install-Windows-final-20260521.18.zip`
- `CHECKSUMS.txt`

macOS 手动方式：

1. 解压 `Agent-Obsidian-install-Mac-final-20260521.19.zip`
2. 把解压出来的 `Mac系统` 文件夹放到 `~/Downloads/Mac系统`
3. 打开 `Mac系统/复制到终端运行.txt`
4. Command + A 全选，Command + C 复制
5. 打开「终端」，Command + V 粘贴，回车运行

Windows 手动方式：

1. 解压 `Agent-Obsidian-install-Windows-final-20260521.18.zip`
2. 双击 `启动.bat`
3. 保持窗口打开，按提示完成安装

## 包里会安装什么

安装包会尽量先检测，已安装则跳过，未安装才继续安装。不同系统实现略有差异，但当前主要覆盖：

- Apple Command Line Tools / Windows 基础运行环境
- Git
- Node.js / npm
- Python 3.13
- Claude Code CLI
- Lark CLI
- HyperFrames CLI
- 企业微信 CLI
- MarkItDown
- yt-dlp
- FFmpeg
- CodePilot
- Obsidian
- Obsidian CLI 注册提示和路径配置
- 随包 Skills 与工具目录

`wechat-cli` 不在默认安装清单里。

## 隐私和账号边界

安装包不会预置或上传客户的 API Key、token、cookie、OAuth 登录态，也不会自动读取微信聊天记录。飞书、企业微信、CodePilot、Obsidian 等账号授权，需要客户在本机自行完成。

## 日志位置

macOS 日志：

```text
~/Downloads/Agent-Obsidian-install-logs/
```

Windows 日志：

```text
%USERPROFILE%\Downloads\Agent-Obsidian-install-logs
```

如果安装失败，把最新日志文件和交付清单回传给交付人员即可定位。
